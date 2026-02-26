---
applyTo: "**/pom.xml"
---

# Maven pom.xml Conventions

Follow the spring-boot skill at `.github/skills/spring-boot/SKILL.md` — specifically the Dependencies section.

## Rules
- Use Spring Boot BOM versions — never pin versions for BOM-managed dependencies
- Lombok must be `<optional>true</optional>` — compile-time only, must not leak transitively
- Annotation processor order: Lombok → lombok-mapstruct-binding → MapStruct
- No snapshot versions on main branch — only stable released versions
- JDBC drivers: `<scope>runtime</scope>`
- Test dependencies: `<scope>test</scope>`
- Add dependencies only when needed — do not copy the full template blindly
- Required starters for any Spring Boot project: `spring-boot-starter-web`, `spring-boot-starter-actuator`, `spring-boot-starter-validation`, `springdoc-openapi-starter-webmvc-ui`
