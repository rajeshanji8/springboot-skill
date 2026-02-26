# Optional: Boost Copilot Skill Compliance

The spring-boot skill works **standalone** — `SKILL.md` contains all critical rules inline and instructs the agent to read reference files before coding. No additional files are required.

However, for **maximum compliance** with GitHub Copilot, you can add these optional reinforcement layers:

---

## Layer 1: Always-On Instructions (`copilot-instructions.md`)

Append the snippet from `copilot-instructions-snippet.md` to your project's `.github/copilot-instructions.md`. This ensures the top rules are loaded on **every request**, not just when the skill is triggered.

**Manual:**
```bash
cat templates/copilot-instructions-snippet.md >> .github/copilot-instructions.md
```

**Automated (via installer):**
```bash
./install.sh --with-instructions ~/projects/my-api
```

The installer appends with marker comments (`<!-- springboot-skill:start/end -->`) so it can be cleanly removed later with `--uninstall`.

---

## Layer 2: Path-Specific Instructions (`.instructions.md` files)

Copy the instruction files from `instructions/` into your project's `.github/instructions/` directory. These fire **automatically** when Copilot touches matching file types:

| File | Triggers On | Purpose |
|------|-------------|---------|
| `java-spring.instructions.md` | `**/*.java` | Injection, Lombok, DTO/entity rules, code style |
| `pom.instructions.md` | `**/pom.xml` | BOM versions, scopes, processor order |
| `docker.instructions.md` | `**/Dockerfile` | Multi-stage builds, non-root, health checks |
| `test.instructions.md` | `**/*Test.java,**/*IT.java` | Test patterns, AssertJ, naming conventions |
| `properties.instructions.md` | `**/application*.properties` | No profiles, no YAML, required JPA/MVC settings |
| `liquibase.instructions.md` | `**/db/changelog/**` | YAML format, never modify deployed changesets |

**Manual:**
```bash
mkdir -p .github/instructions
cp templates/instructions/*.instructions.md .github/instructions/
```

**Automated (via installer):**
```bash
./install.sh --with-instructions ~/projects/my-api
```

---

## How the Layers Work Together

```
Request arrives
  │
  ├─ copilot-instructions.md          ← Always loaded (top 15 rules)
  ├─ instructions/java-spring.md      ← Auto-loaded when *.java in context
  ├─ skills/spring-boot/SKILL.md      ← Loaded when skill matches prompt
  │    ├─ Hard rules (inline)         ← Agent sees these immediately
  │    ├─ Pre-flight checklist        ← Forces reading of reference files
  │    └─ Verification checklist      ← Self-check before completing
  └─ references/*.md                  ← Deep-dive docs (TLDR at top)
```

The skill is designed to work at every layer. The more layers you enable, the higher the compliance rate — but even with just the skill alone, the most critical rules are enforced.
