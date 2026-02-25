# Project Structure

When generating or modifying a Spring Boot project, follow this package layout and structure.

---

## Build Tool

- Use **Maven** with the standard `pom.xml`.
<!-- CUSTOMIZE: Switch to Gradle if preferred -->

## Java Version

- Target **Java 21** (LTS).
<!-- CUSTOMIZE: Change to your project's Java version -->

## Spring Boot Version

- Use the latest stable **Spring Boot 3.x** release.

---

## Package Layout

Use a **layered package structure** rooted at the base package:

```
com.example.appname
├── config/              # @Configuration classes, beans, properties binding
├── controller/          # @RestController classes (thin, delegation only)
├── service/             # @Service classes (business logic)
├── repository/          # @Repository / Spring Data interfaces
├── model/
│   ├── entity/          # JPA @Entity classes
│   ├── dto/             # Request/Response DTOs (records preferred)
│   └── enums/           # Enums used across layers
├── exception/           # Custom exceptions and global handler
├── mapper/              # Mapping logic between entities ↔ DTOs
├── util/                # Pure utility/helper classes (stateless)
└── Application.java     # Main class with @SpringBootApplication
```

---

## Key Rules

1. **No business logic in controllers** — always controllers delegate to services.
2. **No repository access from controllers** — always go through a service.
3. **DTOs cross boundaries, entities stay internal** — never expose JPA entities in API responses.
4. **One `@SpringBootApplication` class** — keep it clean, no extra beans there.
5. **Configuration in dedicated `config/` classes** — not scattered across the codebase.
6. **ALL `@Bean` definitions live in `config/` package only** — controllers, services, and other packages must never define beans. This includes `WebClient`, `RestTemplate`, `ObjectMapper`, security filters, CORS configs, etc.
7. **Global exception handling is mandatory** — every project must have a `@RestControllerAdvice` in the `exception/` package (see [error-handling.md](references/error-handling.md)).
8. **Use MapStruct or manual mappers in `mapper/` package** — see [mapper-conventions.md](references/mapper-conventions.md) for mapping patterns.
9. **Externalize configuration with `@ConfigurationProperties`** — see [configuration-properties.md](references/configuration-properties.md).

---

## Resource Structure

```
src/main/resources/
├── application.properties              # Single config file — no profiles
├── logback-spring.xml                  # Logging config (see logging reference)
├── db/changelog/
│   ├── db.changelog-master.yaml        # Liquibase master changelog
│   └── changes/                        # Individual changesets
│       ├── 001-create-users-table.yaml
│       └── 002-add-email-index.yaml
└── static/                             # Static assets (if any)
```

**Rules:**
- **Always use `application.properties`** — no YAML config files (rarely go for `.yaml`).
- **No profiles** (`application-dev.properties`, `application-prod.properties`). Use a single `application.properties` with environment variable placeholders for values that differ per environment.
- **Include comprehensive logging config** in `application.properties` so users can toggle to `DEBUG` when needed (see [logging.md](references/logging.md) for full Logback setup):
  ```properties
  # ===== Logging =====
  logging.level.root=INFO
  logging.level.com.example.appname=INFO
  logging.level.org.springframework.web=INFO
  logging.level.org.springframework.security=INFO
  logging.level.org.hibernate.SQL=INFO
  logging.level.org.hibernate.orm.jdbc.bind=INFO
  # Change to DEBUG for troubleshooting:
  # logging.level.com.example.appname=DEBUG
  # logging.level.org.springframework.web=DEBUG
  # logging.level.org.hibernate.SQL=DEBUG
  # logging.level.org.hibernate.orm.jdbc.bind=TRACE
  ```

---

## .gitignore

**Every project must have a `.gitignore` at the root.** Include at minimum:

```gitignore
# ===== Build =====
target/
build/
!.mvn/wrapper/maven-wrapper.jar

# ===== IDE =====
.idea/
*.iml
.vscode/
.settings/
.classpath
.project
.factorypath
*.swp
*~

# ===== OS =====
.DS_Store
Thumbs.db
desktop.ini

# ===== Logs =====
logs/
*.log

# ===== Environment / Secrets =====
.env
*.env
application-local.properties

# ===== Dependencies =====
node_modules/

# ===== Spring Boot =====
*.jar
!gradle/wrapper/gradle-wrapper.jar
hs_err_pid*
replay_pid*
```
