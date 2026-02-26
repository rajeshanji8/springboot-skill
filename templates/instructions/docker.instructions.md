---
applyTo: "**/Dockerfile"
---

# Dockerfile Conventions

Follow the spring-boot skill at `.github/skills/spring-boot/SKILL.md` — specifically the Docker section.

## Rules
- Always use multi-stage builds — JDK (Eclipse Temurin) for build, JRE for runtime
- Run as non-root user — add `USER` instruction in Dockerfile
- Never hardcode `-Xmx`/`-Xms` — use `-XX:MaxRAMPercentage=75.0` with container memory limits
- Always include `HEALTHCHECK` instruction
- Always create a `.dockerignore` file
- Pin image versions — `postgres:16-alpine` not `postgres:latest`
- Never put secrets in Dockerfile — use environment variables or build args
- Expose only the application port (default 8080)
