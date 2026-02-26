# springboot-skill

A reusable **Spring Boot 3.x** skill for AI coding agents. Install it once and every agent follows the same conventions — project structure, REST APIs, JPA, security, testing, Docker, and more.

**Supported agents:** Claude Code · Codex · Gemini CLI · Cursor · GitHub Copilot

---

## Quick Install

**TLDR — run this in your project directory:**
```bash
curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- . --with-instructions
```

### All agents — project level (recommended)

**macOS / Linux / Git Bash:**
```bash
curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- ~/projects/my-api
```

**Windows PowerShell:**
```powershell
irm https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.ps1 | iex
```

### With Copilot instruction reinforcement (optional)

```bash
curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- --with-instructions ~/projects/my-api
```

This appends always-on rules to `copilot-instructions.md` and adds path-specific instruction files. See [Copilot Reinforcement Layer](#copilot-reinforcement-layer-optional) below.

### Specific agent only

```bash
curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- --agent claude ~/projects/my-api
```

### User level (applies to all projects)

```bash
curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- --user
```

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- --uninstall
```

---

## Local Install (after cloning)

```bash
git clone https://github.com/rajeshanji8/springboot-skill.git
cd springboot-skill

# Install for all agents in a project
./install.sh ~/projects/my-api

# With Copilot instruction reinforcement
./install.sh --with-instructions ~/projects/my-api

# Install for Claude only
./install.sh --agent claude ~/projects/my-api

# Install at user level for Gemini
./install.sh --user --agent gemini

# Windows
.\install.ps1 C:\projects\my-api
.\install.ps1 -WithInstructions C:\projects\my-api
.\install.ps1 -Agent claude C:\projects\my-api
```

---

## What's Inside

The skill is a set of markdown files that AI agents read on demand. The entry point is `SKILL.md`, which links to focused reference docs:

| Module | Reference | Covers |
|--------|-----------|--------|
| Project Structure | `project-structure.md` | Package layout, module organization |
| Coding Conventions | `coding-conventions.md` | Naming, Lombok, records, formatting |
| Java Standards | `java-standards.md` | Null handling, streams, imports, Javadoc |
| REST API Design | `api-design.md` | URLs, DTOs, validation, pagination, OpenAPI |
| Database & JPA | `database-jpa.md` | Entities, repositories, Liquibase migrations |
| Error Handling | `error-handling.md` | Global handler, Problem Details (RFC 9457) |
| Testing | `testing.md` | Unit, slice, integration, Testcontainers |
| Mapper Conventions | `mapper-conventions.md` | MapStruct setup, service-layer mapping |
| Configuration | `configuration-properties.md` | `@ConfigurationProperties`, env vars |
| Caching | `caching.md` | Caffeine, Redis, per-cache TTL |
| Async & Scheduling | `async-scheduling.md` | `@Async`, `@Scheduled`, thread pools |
| Security | `security.md` | Auth, CORS, secrets management |
| HTTP Client | `http-client.md` | RestClient, timeouts, connection pooling |
| Logging | `logging.md` | Logback, structured JSON, MDC |
| Actuator & Health | `actuator-health.md` | Health checks, metrics, Micrometer |
| Docker | `docker.md` | Multi-stage Dockerfile, Compose |
| Dev Scripts | `dev-scripts.md` | `start.sh` build-and-run script |
| Dependencies | `dependencies.md` | Canonical `pom.xml` dependency list |

Agents load only the reference they need for the current task — they don't read everything at once.

---

## Copilot Reinforcement Layer (Optional)

The skill is designed to be **self-sufficient** — `SKILL.md` contains all critical rules inline and instructs the agent to read reference files before coding. No additional files are required.

For **maximum compliance** with GitHub Copilot, the installer supports `--with-instructions` which adds two optional reinforcement layers:

### What `--with-instructions` Does

| Action | Effect |
|--------|--------|
| **Appends** to `.github/copilot-instructions.md` | Adds a snippet with the top 15 rules, wrapped in `<!-- springboot-skill:start/end -->` markers for clean uninstall. Safe if the file already exists — your existing instructions are preserved. |
| **Copies** `.instructions.md` files to `.github/instructions/` | Path-specific rules that auto-trigger when Copilot touches matching files. Skips files that already exist. |

### Path-Specific Instruction Files

| File | Triggers On | Enforces |
|------|-------------|----------|
| `java-spring.instructions.md` | `**/*.java` | Injection, Lombok, DTO/entity rules, code style |
| `pom.instructions.md` | `**/pom.xml` | BOM versions, scopes, processor order |
| `docker.instructions.md` | `**/Dockerfile` | Multi-stage builds, non-root, health checks |
| `test.instructions.md` | `**/*Test.java` | Test patterns, AssertJ, naming conventions |

### How the Layers Work Together

```
Request arrives
  │
  ├─ copilot-instructions.md          ← Always loaded (top 15 rules)      [--with-instructions]
  ├─ instructions/java-spring.md      ← Auto-loaded when *.java in context [--with-instructions]
  ├─ skills/spring-boot/SKILL.md      ← Loaded when skill matches prompt   [default]
  │    ├─ Hard rules (inline)         ← Agent sees these immediately
  │    ├─ Pre-flight checklist        ← Forces reading of reference files
  │    └─ Verification checklist      ← Self-check before completing
  └─ references/*.md                  ← Deep-dive docs (TLDR at top)       [default]
```

### Template Files

All reinforcement files live in `templates/` in this repo. You can also copy them manually — see [templates/README.md](templates/README.md) for details.

---

## How It Works

The installer copies `skills/spring-boot/` into the agent's skill directory:

| Agent | Project-level path | User-level path |
|-------|-------------------|-----------------|
| Claude Code | `.claude/skills/spring-boot/` | `~/.claude/skills/spring-boot/` |
| Codex | `.codex/skills/spring-boot/` | `~/.codex/skills/spring-boot/` |
| Gemini CLI | `.gemini/skills/spring-boot/` | `~/.gemini/skills/spring-boot/` |
| Cursor | `.cursor/skills/spring-boot/` | `~/.cursor/skills/spring-boot/` |
| GitHub Copilot | `.github/skills/spring-boot/` | `~/.copilot/skills/spring-boot/` |

Once installed, the agent automatically picks up the skill when working on Spring Boot code.

---

## Requirements

- **Git** (for cloning during remote install)
- **Bash** (macOS/Linux) or **PowerShell 5.1+** (Windows)
- No Java or Maven needed — this installs skill files only, not a Spring Boot app

---

## Contributing

1. Edit files under `skills/spring-boot/`
2. Test by installing locally: `./install.sh .`
3. Verify the agent picks up your changes

---

## License

MIT
