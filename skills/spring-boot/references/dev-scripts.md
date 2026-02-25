# Dev Scripts

Every Spring Boot project must include a `start.sh` at the project root that builds, starts, and opens the app with a single command. No manual setup steps.

---

## start.sh

**This file is mandatory in every project.** Place it at the project root with `755` permissions.

### Usage

```bash
./start.sh                        # Build (skip tests) + start in Docker (default)
./start.sh --noskiptests           # Build (run tests) + start in Docker
./start.sh --locally               # Build (skip tests) + start locally (mvn spring-boot:run)
./start.sh --locally --noskiptests # Build (run tests) + start locally
```

### The Script

```bash
#!/usr/bin/env bash
set -euo pipefail

# ===== Configuration =====
# CUSTOMIZE: Change these to match your project
APP_NAME="myapp"
APP_PORT="${APP_PORT:-8080}"
APP_BASE_URL="http://localhost:${APP_PORT}"
HEALTH_URL="${APP_BASE_URL}/actuator/health"
SWAGGER_URL="${APP_BASE_URL}/swagger-ui.html"
API_DOCS_URL="${APP_BASE_URL}/api-docs"
STARTUP_TIMEOUT=120  # seconds to wait for app to become healthy

# ===== Parse Arguments =====
SKIP_TESTS=true
RUN_MODE="docker"  # "docker" or "locally"

for arg in "$@"; do
    case "$arg" in
        --noskiptests) SKIP_TESTS=false ;;
        --locally)     RUN_MODE="locally" ;;
        --help|-h)
            echo "Usage: ./start.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --locally       Run with 'mvn spring-boot:run' instead of Docker (default: Docker)"
            echo "  --noskiptests   Run tests during build (default: skip tests)"
            echo "  -h, --help      Show this help"
            echo ""
            echo "Examples:"
            echo "  ./start.sh                          # Build + Docker"
            echo "  ./start.sh --locally                # Build + run locally"
            echo "  ./start.sh --noskiptests             # Build with tests + Docker"
            echo "  ./start.sh --locally --noskiptests   # Build with tests + run locally"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (use --help for usage)"
            exit 1
            ;;
    esac
done

# ===== Colors =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ===== Pre-flight Checks =====
info "Checking prerequisites..."

if ! command -v java &> /dev/null; then
    error "Java not found. Install Java 21+ and add to PATH."
    exit 1
fi

if ! command -v mvn &> /dev/null && [ ! -f "./mvnw" ]; then
    error "Neither 'mvn' nor './mvnw' found. Install Maven or ensure Maven Wrapper is present."
    exit 1
fi

MVN_CMD="mvn"
if [ -f "./mvnw" ]; then
    MVN_CMD="./mvnw"
    chmod +x ./mvnw 2>/dev/null || true
fi

if [ "$RUN_MODE" = "docker" ]; then
    if ! command -v docker &> /dev/null; then
        error "Docker not found. Install Docker or use --locally to run without it."
        exit 1
    fi
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Start Docker or use --locally."
        exit 1
    fi
fi

success "Prerequisites OK"

# ===== Build =====
echo ""
info "Building ${APP_NAME}..."

BUILD_ARGS="clean install"
if [ "$SKIP_TESTS" = true ]; then
    BUILD_ARGS="$BUILD_ARGS -DskipTests"
    info "Tests: SKIPPED (use --noskiptests to run)"
else
    info "Tests: ENABLED"
fi

if ! $MVN_CMD $BUILD_ARGS -B; then
    error "Build failed. Fix the errors above and try again."
    exit 1
fi

success "Build successful"

# ===== Start =====
echo ""

cleanup() {
    if [ "$RUN_MODE" = "locally" ] && [ -n "${APP_PID:-}" ]; then
        info "Stopping application (PID: $APP_PID)..."
        kill "$APP_PID" 2>/dev/null || true
        wait "$APP_PID" 2>/dev/null || true
    fi
    if [ "$RUN_MODE" = "docker" ]; then
        # Don't auto-stop Docker on exit — user may want it running
        true
    fi
}
trap cleanup EXIT

if [ "$RUN_MODE" = "docker" ]; then
    info "Starting with Docker Compose..."

    if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.yaml" ] && [ ! -f "compose.yml" ] && [ ! -f "compose.yaml" ]; then
        error "No docker-compose.yml found. Create one or use --locally."
        exit 1
    fi

    # Stop any existing containers
    docker compose down --remove-orphans 2>/dev/null || docker-compose down --remove-orphans 2>/dev/null || true

    # Build and start
    if ! (docker compose up --build -d 2>/dev/null || docker-compose up --build -d); then
        error "Docker Compose failed to start."
        exit 1
    fi

    success "Docker containers started"
else
    info "Starting locally with Maven..."

    # Start in background
    $MVN_CMD spring-boot:run -B &
    APP_PID=$!

    success "Application starting (PID: $APP_PID)"
fi

# ===== Wait for Health =====
echo ""
info "Waiting for application to become healthy..."
info "Health endpoint: ${HEALTH_URL}"

elapsed=0
interval=3

while [ $elapsed -lt $STARTUP_TIMEOUT ]; do
    if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
        echo ""
        success "Application is UP and healthy!"
        echo ""
        echo -e "${BOLD}  ┌─────────────────────────────────────────────────────────┐${NC}"
        echo -e "${BOLD}  │                                                         │${NC}"
        echo -e "${BOLD}  │${NC}   ${GREEN}✔ ${APP_NAME} is running${NC}                                ${BOLD}│${NC}"
        echo -e "${BOLD}  │                                                         │${NC}"
        echo -e "${BOLD}  │${NC}   ${CYAN}App:${NC}     ${APP_BASE_URL}                        ${BOLD}│${NC}"
        echo -e "${BOLD}  │${NC}   ${CYAN}Swagger:${NC} ${SWAGGER_URL}        ${BOLD}│${NC}"
        echo -e "${BOLD}  │${NC}   ${CYAN}API Docs:${NC}${API_DOCS_URL}                  ${BOLD}│${NC}"
        echo -e "${BOLD}  │${NC}   ${CYAN}Health:${NC}  ${HEALTH_URL}       ${BOLD}│${NC}"
        echo -e "${BOLD}  │                                                         │${NC}"
        echo -e "${BOLD}  │${NC}   Mode: ${YELLOW}${RUN_MODE}${NC}                                        ${BOLD}│${NC}"
        echo -e "${BOLD}  │                                                         │${NC}"
        echo -e "${BOLD}  └─────────────────────────────────────────────────────────┘${NC}"
        echo ""

        if [ "$RUN_MODE" = "locally" ]; then
            info "Press Ctrl+C to stop the application."
            wait "$APP_PID" 2>/dev/null || true
        else
            info "Containers running in background. Use 'docker compose down' to stop."
        fi
        exit 0
    fi

    sleep $interval
    elapsed=$((elapsed + interval))
    printf "  Waiting... (%ds / %ds)\r" "$elapsed" "$STARTUP_TIMEOUT"
done

echo ""
error "Application did not become healthy within ${STARTUP_TIMEOUT}s."
error "Check logs:"
if [ "$RUN_MODE" = "docker" ]; then
    error "  docker compose logs -f"
else
    error "  Check terminal output above"
fi
exit 1
```

### Setup

After creating the file, set the execute permission:

```bash
chmod 755 start.sh
```

On Windows, use Git Bash or WSL to run `./start.sh`.

---

## Project Root Layout

The script lives at the project root alongside `pom.xml`:

```
my-app/
├── start.sh                    # chmod 755 — build + start + show URLs
├── pom.xml
├── docker-compose.yml
├── Dockerfile
├── .dockerignore
├── .gitignore
├── src/
│   ├── main/
│   └── test/
└── ...
```

---

## Windows Support

`start.sh` is a Bash script. On Windows, run it using one of these methods:

### Option 1: Git Bash (Recommended)

Git for Windows includes Git Bash. Open Git Bash in the project root and run:
```bash
./start.sh
./start.sh --locally
```

### Option 2: WSL (Windows Subsystem for Linux)

If WSL is installed:
```bash
wsl ./start.sh
```

### Option 3: PowerShell Quick Start

For developers who cannot use Bash, use this minimal PowerShell equivalent. This is **not** a full replacement for `start.sh` — it covers the most common workflow (build + run locally):

```powershell
# Quick start — build and run locally
$MVN = if (Test-Path "./mvnw.cmd") { "./mvnw.cmd" } else { "mvn" }
& $MVN clean install -DskipTests -B
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed" -ForegroundColor Red; exit 1 }

& $MVN spring-boot:run -B
```

For Docker-based startup on Windows, use `docker compose up --build -d` directly after building.

**The canonical script is `start.sh`** — it is the single source of truth for project startup. PowerShell is a convenience fallback only.

---

## Rules

1. **Every project must have `start.sh`** at the root — this is not optional. It's the single entry point for running the app.
2. **`chmod 755 start.sh`** — the file must be executable. Add it to Git with execute permission: `git update-index --chmod=+x start.sh`.
3. **Docker is the default mode** — `./start.sh` with no args uses Docker Compose. Use `--locally` only for quick iteration without containers.
4. **Tests are skipped by default** — `./start.sh` builds fast. Use `--noskiptests` for CI or pre-commit validation.
5. **Health check gates the "ready" message** — the script waits for `/actuator/health` to return 200 before printing URLs. If it times out, it tells you where to look for logs.
6. **Customize the `Configuration` section** at the top of the script — change `APP_NAME`, `APP_PORT`, and URLs to match your project.
7. **`start.sh` must be in version control** — it is part of the project, not a developer-local tool. On Windows, use Git Bash or WSL (see Windows Support above).
8. **The script must be self-contained** — no external dependencies beyond Java, Maven (or wrapper), Docker, and curl. No npm, no Makefile, no Gradle plugins.
9. **Swagger UI must be accessible after start** — if OpenAPI is configured (see [api-design.md](api-design.md)), the script prints the Swagger URL. This is the user's primary verification step.
