# Spring Boot Skill

> A reusable AI coding skill for Spring Boot projects. Install into any project for any AI agent — Claude Code, Codex, Gemini CLI, Cursor, GitHub Copilot.

---

## Usage

### Quick Install (from GitHub — no clone needed)

**Bash (macOS/Linux):**
```bash
# Install for all agents at project level
curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- ~/projects/my-api

# Install for specific agent(s)
curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- ~/projects/my-api --agent claude

# Install at user level (applies to all your projects)
curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- --user

# Install at user level for specific agent
curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- --user --agent claude

# Uninstall
curl -fsSL https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.sh | bash -s -- --uninstall
```

**PowerShell (Windows):**
```powershell
# Install for all agents at project level
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/rajeshanji8/springboot-skill/main/install.ps1))) C:\projects\my-api

# Or clone + install + delete in one line
git clone --depth 1 https://github.com/rajeshanji8/springboot-skill.git $env:TEMP\springboot-skill; & $env:TEMP\springboot-skill\install.ps1 C:\projects\my-api; Remove-Item $env:TEMP\springboot-skill -Recurse -Force
```

### Install from Cloned Repo

```bash
git clone https://github.com/rajeshanji8/springboot-skill.git
cd springboot-skill
```

**Bash:**
```bash
./install.sh ~/projects/my-api                      # All agents, project level
./install.sh ~/projects/my-api --agent claude        # Claude only
./install.sh --user                                  # All agents, user level
./install.sh --user --agent claude --agent codex     # Specific agents, user level
./install.sh --uninstall                             # Remove skill
```

**PowerShell:**
```powershell
.\install.ps1 C:\projects\my-api                     # All agents, project level
.\install.ps1 C:\projects\my-api -Agent claude        # Claude only
.\install.ps1 -User                                   # All agents, user level
.\install.ps1 -User -Agent claude -Agent codex        # Specific agents, user level
.\install.ps1 -Uninstall                              # Remove skill
```

### Manual Installation

Copy the `skills/spring-boot` folder into the agent's skill directory:

| Agent | Project Level | User Level |
|-------|--------------|------------|
| Claude Code | `project/.claude/skills/spring-boot` | `~/.claude/skills/spring-boot` |
| Codex | `project/.codex/skills/spring-boot` | `~/.codex/skills/spring-boot` |
| Gemini CLI | `project/.gemini/skills/spring-boot` | `~/.gemini/skills/spring-boot` |
| Cursor | `project/.cursor/skills/spring-boot` | `~/.cursor/skills/spring-boot` |
| GitHub Copilot | `project/.github/skills/spring-boot` | `~/.github/skills/spring-boot` |

---

## Structure

```
springboot-skill/
├── springboot-skill.md                     # This file
├── install.sh                              # Bash installer
├── install.ps1                             # PowerShell installer
└── skills/
    └── spring-boot/
        ├── SKILL.md                        # Entry point — agent reads this first
        └── references/                     # Detailed guides (read on demand)
            ├── project-structure.md
            ├── coding-conventions.md
            ├── java-standards.md
            ├── api-design.md
            ├── database-jpa.md
            ├── error-handling.md
            ├── logging.md
            ├── testing.md
            ├── security.md
            ├── mapper-conventions.md
            ├── configuration-properties.md
            ├── caching.md
            ├── async-scheduling.md
            ├── actuator-health.md
            ├── docker.md
            ├── dev-scripts.md
            ├── dependencies.md
            └── http-client.md
```

### How it works

1. **SKILL.md** is the entry point with YAML frontmatter describing the skill
2. It links to **references/** — agents only read the reference they need for the current task
3. This keeps context small and focused instead of dumping everything upfront

---

## Skill Modules

| Module | Reference | Description |
|--------|-----------|-------------|
| Project Structure | `project-structure.md` | Package layout, module organization |
| Coding Conventions | `coding-conventions.md` | Naming, formatting, Java/Spring idioms |
| Java Standards | `java-standards.md` | String safety, Javadoc, imports, null handling |
| API Design | `api-design.md` | REST conventions, DTOs, validation, pagination |
| Database & JPA | `database-jpa.md` | Entity design, repositories, migrations |
| Error Handling | `error-handling.md` | Global exception handler, Problem Details |
| Logging | `logging.md` | Logback setup, appenders, log level management |
| Testing | `testing.md` | Unit, slice, and integration tests |
| Security | `security.md` | Auth, CORS, secrets management |
| Mapper Conventions | `mapper-conventions.md` | MapStruct, entity ↔ DTO mapping |
| Configuration Properties | `configuration-properties.md` | Type-safe config binding, env variables |
| Caching | `caching.md` | Spring Cache, Caffeine, Redis |
| Async & Scheduling | `async-scheduling.md` | @Async, @Scheduled, thread pools |
| Actuator & Health | `actuator-health.md` | Health indicators, metrics, Micrometer |
| Docker | `docker.md` | Dockerfile, Docker Compose, containerization |
| Dev Scripts | `dev-scripts.md` | Build-and-run script, Docker/local startup |
| Dependencies | `dependencies.md` | Consolidated pom.xml template, all required dependencies |
| HTTP Client | `http-client.md` | RestClient, timeouts, connection pooling, retry |

---

## Customizing

- Every customization point is marked with `<!-- CUSTOMIZE -->` in the reference files
- Edit files in `skills/spring-boot/references/` — re-run install to update projects
- Add new references and link them from `SKILL.md`

---

## References

- [Claude Agent Skills](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/skills)
- [OpenAI Codex](https://openai.com/index/openai-codex/)
- [Gemini CLI](https://github.com/google-gemini/gemini-cli)

