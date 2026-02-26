---
applyTo: "**/application*.properties"
---

# Spring Boot Properties Conventions

Follow the spring-boot skill — specifically the Configuration and Database & JPA sections.

## Rules
- Single `application.properties` only — NEVER create `application-dev.properties`, `application-prod.properties`, or any profile-specific files
- NEVER use YAML (`application.yml`) — properties format only
- Use `${ENV_VAR:default}` for all environment-specific values — never hardcode
- `spring.jpa.open-in-view=false` — always disabled, non-negotiable
- `spring.jpa.hibernate.ddl-auto=validate` — Hibernate must never modify the schema
- `spring.mvc.problemdetails.enabled=true` — required for RFC 9457 Problem Details
- `spring.jpa.properties.hibernate.default_batch_fetch_size=20` — prevents N+1 in collection loading
- Include comprehensive logging levels for troubleshooting
- Never put secrets (passwords, API keys, tokens) as literal values — always `${ENV_VAR}`
