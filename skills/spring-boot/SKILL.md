---
name: spring-boot-skill
description: >
  Spring Boot 3.x REST API development. ALWAYS use this skill for ANY Spring Boot,
  Java backend, REST API, JPA/Hibernate, microservice, or CRUD task. Covers project
  setup, controllers, services, repositories, entities, DTOs, error handling, testing,
  Docker, configuration, security, caching, async, logging, HTTP clients, and monitoring.
---

# Spring Boot Skill

## BEFORE WRITING ANY CODE — Mandatory Pre-Flight

For every Spring Boot task, determine which areas apply and **READ and FOLLOW ALL rules in the corresponding reference doc BEFORE generating code**:

- **Creating/modifying endpoints?** → READ [references/api-design.md](references/api-design.md) AND [references/error-handling.md](references/error-handling.md)
- **Working with entities/DB?** → READ [references/database-jpa.md](references/database-jpa.md) AND [references/mapper-conventions.md](references/mapper-conventions.md)
- **Any new class?** → READ [references/coding-conventions.md](references/coding-conventions.md) AND [references/java-standards.md](references/java-standards.md)
- **Writing tests?** → READ [references/testing.md](references/testing.md)
- **Adding configuration?** → READ [references/configuration-properties.md](references/configuration-properties.md)
- **Setting up the project?** → READ [references/project-structure.md](references/project-structure.md) AND [references/dependencies.md](references/dependencies.md) AND [references/dev-scripts.md](references/dev-scripts.md)
- **Containerizing?** → READ [references/docker.md](references/docker.md)
- **Adding security?** → READ [references/security.md](references/security.md)
- **Adding caching?** → READ [references/caching.md](references/caching.md)
- **Adding async/scheduling?** → READ [references/async-scheduling.md](references/async-scheduling.md)
- **Making HTTP calls?** → READ [references/http-client.md](references/http-client.md)
- **Monitoring/health?** → READ [references/actuator-health.md](references/actuator-health.md)

**DO NOT generate code without first reading the applicable references above. Every rule in the referenced docs is mandatory — not a suggestion.**

---

## Hard Rules — Always Apply (Non-Negotiable)

These rules apply to EVERY file in EVERY Spring Boot task. Violating any of these is a bug.

### Project Structure
- Java 21 (LTS) — set `<java.version>21</java.version>` in pom.xml. Not 17, not 22
- Package layout: `com.company.module.{config,controller,service,repository,model/{entity,dto,enums},exception,mapper,util}`
- No business logic in controllers — controllers delegate to services only
- ALL `@Bean` definitions live in `config/` package only — never in controllers, services, or other packages
- Single `application.properties` — no profiles (`application-dev.properties`), no YAML; use `${ENV_VAR:default}` for per-environment values
- One `@SpringBootApplication` class — keep it clean, no extra beans

### Coding Conventions
- Constructor injection via `@RequiredArgsConstructor` — NEVER `@Autowired` on fields
- Lombok is mandatory: `@Slf4j` for logging, `@Getter`/`@Setter` for accessors — never write manual getters/setters
- Java records for all immutable DTOs — suffix with `Request`/`Response`
- NEVER use `@Data` on JPA entities — use `@Getter`, `@Setter`, `@NoArgsConstructor` individually
- Entities NEVER cross the service boundary — controllers always receive/return DTOs, services call mappers
- Override `toString()` on every entity AND every Java record DTO — records auto-generate non-JSON `toString()`, you MUST still override it with `JsonUtil.toJson(this)`. NEVER log inside `toString()`
- `@JsonIgnore` on every sensitive field (password, token, secret, apiKey)
- Use `var` for local variables when the type is obvious from the right side
- Services MUST be stateless — no mutable shared state in Spring beans, no request-scoped data in instance fields
- Repository methods return `Optional<Entity>` for single lookups. Service methods call `.orElseThrow()` and return DTOs directly — NEVER return `Optional` or `null` from services

### Java Standards
- Max 120 characters per line, max 1,000 lines per file
- No wildcard imports — always import the specific class
- Never return `null` — use `Optional<T>`, empty collections, or throw exceptions
- Use `BigDecimal` (constructed from `String`) for all financial values — never `double`/`float`
- No consecutive uppercase letters in names: `HttpClient` not `HTTPClient`
- NEVER use `System.out.println()` or `System.err.println()` — always use the SLF4J logger

### Error Handling
- Every project MUST have a `@RestControllerAdvice` `GlobalExceptionHandler` — not optional
- Use RFC 9457 Problem Details (`ProblemDetail`) for all error responses
- Throw custom domain exceptions (`ResourceNotFoundException`, `BusinessRuleException`) — never return null to signal errors
- Never expose stack traces in API responses — log the full exception server-side
- Never log AND throw — either log or throw, the global handler logs thrown exceptions

### Logging
- Always use `@Slf4j` — NEVER `LoggerFactory.getLogger()` manually
- Parameterized logging: `log.info("id={}", id)` — never string concatenation
- Never use `System.out.println()` or `e.printStackTrace()` — always use the SLF4J logger
- Every ERROR must include the exception object: `log.error("msg", ex)` — never `log.error(ex.getMessage())`

### Configuration
- `@Validated` on all `@ConfigurationProperties` classes — fail fast on bad config
- Never hardcode secrets, URLs, or env-specific values — always `${ENV_VAR:default}`
- All `@ConfigurationProperties` classes live in `config/` package

---

## Context-Specific Rules — Apply When Working in That Area

### REST API Design
Read [references/api-design.md](references/api-design.md) for full details.
- URI prefix `/api/v1/` — lowercase, hyphen-separated, plural nouns
- Every endpoint MUST have Swagger annotations: `@Tag`, `@Operation`, `@ApiResponses`
- `@Valid` on `@RequestBody` + `@Validated` on controller class — both required
- Every list endpoint must define a default sort via `@PageableDefault` or `@SortDefault`
- Never modify the contract of a released API version
- Do NOT use Spring HATEOAS — return plain DTOs, document endpoints in Swagger/OpenAPI

### Database & JPA
Read [references/database-jpa.md](references/database-jpa.md) for full details.
- Default ALL relationships to `FetchType.LAZY` — non-negotiable; use `@EntityGraph` or `JOIN FETCH` when you need eager
- Liquibase (YAML format) for all migrations — never Flyway, never modify deployed changesets
- `spring.jpa.hibernate.ddl-auto=validate` — Hibernate must never modify the schema
- `spring.jpa.open-in-view=false` — hides N+1 bugs and violates layered architecture
- `@Transactional` on service methods only — never on repositories or controllers; `readOnly = true` for reads
- ALL entities MUST extend `BaseEntity` (audit superclass with `@CreatedDate`, `@LastModifiedDate`) — no exceptions, even if an entity doesn't logically need `updatedAt`
- ALWAYS enable `@EnableJpaAuditing` in a `@Configuration` class when using `@CreatedDate` / `@LastModifiedDate`
- Set `spring.jpa.properties.hibernate.default_batch_fetch_size=20`

### Mapper Conventions
Read [references/mapper-conventions.md](references/mapper-conventions.md) for full details.
- ALWAYS use MapStruct with `componentModel = "spring"` — no other mapper library
- One mapper per aggregate root: `UserMapper`, `OrderMapper`
- Never map inside controllers — controllers call services, services call mappers
- Use `@Mapping(target = ..., ignore = true)` for auto-generated fields (ID, audit fields)
- Use `@BeanMapping(nullValuePropertyMappingStrategy = IGNORE)` for partial updates (PATCH)

### Testing
Read [references/testing.md](references/testing.md) for full details.
- Every service method gets a unit test — happy path + one failure case minimum
- Every controller endpoint gets a `@WebMvcTest` slice test
- Use `@MockitoBean` (Spring Boot 3.4+) in slice tests — `@MockBean` is deprecated, NEVER use it
- Use AssertJ for assertions, Mockito for mocking — JUnit 5 + `@ExtendWith(MockitoExtension.class)`
- Test naming: `should{Expected}When{Condition}`
- No `Thread.sleep` — use Awaitility for async assertions

### Dependencies
Read [references/dependencies.md](references/dependencies.md) for full details.
- Use Spring Boot BOM versions — never pin BOM-managed dependency versions
- Lombok: `<optional>true</optional>` — compile-time only
- Annotation processor order: Lombok → lombok-mapstruct-binding → MapStruct
- No snapshot versions on main branch

### Docker
Read [references/docker.md](references/docker.md) for full details.
- Multi-stage builds: JDK for build, JRE for runtime (Eclipse Temurin)
- Run as non-root user — `USER` instruction in Dockerfile
- Percentage-based JVM memory: `-XX:MaxRAMPercentage=75.0` — never hardcode `-Xmx`
- Always include `HEALTHCHECK` and `.dockerignore`

### Security
Read [references/security.md](references/security.md) for full details.
- All security config in `SecurityConfig` in `config/` — no security annotations in controllers
- Never commit secrets to source control — use env vars or vault
- Hash passwords with `BCryptPasswordEncoder` — never plaintext

### Caching
Read [references/caching.md](references/caching.md) for full details.
- Cache at the service layer only — never on controllers or repositories
- ALWAYS define an explicit TTL — never cache indefinitely. Default: 10 minutes
- Cache DTOs, not entities — lazy proxies break outside transactions

### Async & Scheduling
Read [references/async-scheduling.md](references/async-scheduling.md) for full details.
- Always define a custom `TaskExecutor` bean — never rely on Spring's default
- `@Async` only works on public methods called from another bean
- Scheduled tasks must be idempotent — ShedLock for distributed locking

### HTTP Client
Read [references/http-client.md](references/http-client.md) for full details.
- `RestClient` for all synchronous HTTP calls — never `RestTemplate` in new code
- Always configure connect (5s) and read (10s) timeouts — no call without timeouts
- Define client beans in `config/` — one per external service

### Actuator & Health
Read [references/actuator-health.md](references/actuator-health.md) for full details.
- Always include `spring-boot-starter-actuator`
- Enable liveness and readiness probes
- Graceful shutdown with `server.shutdown=graceful`

### Logging Setup
Read [references/logging.md](references/logging.md) for Logback config with CONSOLE + FILE + ERROR_FILE appenders.

### Dev Scripts
Read [references/dev-scripts.md](references/dev-scripts.md) for full details.
- Every project MUST have `start.sh` at root — mandatory, not optional
- Docker is the default mode; `--locally` for Maven spring-boot:run
- Health check gates readiness — waits for `/actuator/health` 200

---

## Pre-Completion Verification — STOP and verify before completing

**Confirm ALL of the following are true. Every violation is a bug.**

1. No `@Autowired` on fields — only constructor injection via `@RequiredArgsConstructor`
2. No JPA entities returned from controllers — always return DTOs
3. `GlobalExceptionHandler` exists with `@RestControllerAdvice`
4. All DTOs are Java records (unless MapStruct `@MappingTarget` needed)
5. `toString()` overridden with `JsonUtil.toJson(this)` on EVERY entity AND EVERY record DTO — records auto-generate non-JSON format, override is still required
6. Swagger annotations (`@Tag`, `@Operation`, `@ApiResponses`) on every endpoint
7. `@Slf4j` for logging — no `LoggerFactory.getLogger()` or `System.out`
8. All `@Bean` definitions are in `config/` package only
9. `start.sh` exists at project root
10. `@Transactional` only on service methods — never controllers or repositories
11. All relationships are `FetchType.LAZY`
12. No wildcard imports, no `@Data` on entities, no hardcoded secrets
13. `spring.jpa.open-in-view=false` in `application.properties`
14. `@Validated` on all `@ConfigurationProperties` classes
15. `@EnableJpaAuditing` present when using `@CreatedDate` / `@LastModifiedDate`
16. No `application-{profile}.properties` files — single `application.properties` only
17. No `@MockBean` — use `@MockitoBean` (Spring Boot 3.4+)
18. No Spring HATEOAS — plain DTOs only
19. `<java.version>21</java.version>` in pom.xml — not 17, not 22
20. ALL entities extend `BaseEntity` — no standalone audit fields
21. Count every public service method and every controller endpoint — verify each has at least one test. If any are missing, generate them now
