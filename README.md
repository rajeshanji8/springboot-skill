# springboot-skill

A reusable **Spring Boot 3.x** skill for AI coding agents. Install it once and every agent follows the same conventions — project structure, REST APIs, JPA, security, testing, Docker, and more.

**Supported agents:** Claude Code · Codex · Gemini CLI · Cursor · GitHub Copilot

---

## Quick Install

### All agents — project level (recommended)

**macOS / Linux / Git Bash:**
```bash
curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- ~/projects/my-api
```

**Windows PowerShell:**
```powershell
irm https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.ps1 | iex
```

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

# Install for Claude only
./install.sh --agent claude ~/projects/my-api

# Install at user level for Gemini
./install.sh --user --agent gemini

# Windows
.\install.ps1 C:\projects\my-api
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
