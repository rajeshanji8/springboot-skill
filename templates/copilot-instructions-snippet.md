<!-- springboot-skill:start -->
<!-- Auto-added by springboot-skill installer. Do not edit this block manually. -->
<!-- To remove: run the installer with --uninstall, or delete this block. -->

## Spring Boot Skill — Global Conventions

This project uses Spring Boot 3.x. ALWAYS load and follow ALL rules in the spring-boot skill
before generating any Java code. Every rule in the skill and its referenced docs is mandatory
— not a suggestion.

Key non-negotiable conventions (full list in SKILL.md):
- Java 21 (LTS) — `<java.version>21</java.version>` in pom.xml. Not 17, not 22
- Java records for ALL DTOs, `@Getter`/`@Setter` on entities, NEVER `@Data` on entities
- Override `toString()` on every entity AND every record DTO with `JsonUtil.toJson(this)` — records auto-generate non-JSON format
- Constructor injection via `@RequiredArgsConstructor` — NEVER `@Autowired` on fields
- `@Slf4j` for logging — NEVER `LoggerFactory.getLogger()` or `System.out.println()`
- All `@Bean` definitions in `config/` package only
- `@Transactional` on service methods only — NEVER controllers or repositories
- Entities NEVER cross the service boundary — always return DTOs via MapStruct
- Services MUST be stateless — no mutable shared state in Spring beans
- `GlobalExceptionHandler` with `@RestControllerAdvice` — mandatory
- RFC 9457 Problem Details for all error responses
- Single `application.properties` — no profiles, no YAML; use `${ENV_VAR:default}`
- Liquibase for DB migrations — never Flyway, never `hibernate.ddl-auto=update/create`
- `spring.jpa.open-in-view=false` — always disabled
- `@EnableJpaAuditing` required when using `@CreatedDate` / `@LastModifiedDate`
- ALL entities MUST extend `BaseEntity` — no standalone audit fields
- All relationships default to `FetchType.LAZY` — non-negotiable
- Every endpoint MUST have Swagger annotations (`@Tag`, `@Operation`, `@ApiResponses`)
- Do NOT use Spring HATEOAS — return plain DTOs
- `@MockitoBean` in slice tests — `@MockBean` is deprecated
- At least one `@ConfigurationProperties` record with `@Validated` if the app defines custom `app.*` properties
- Every project must have `start.sh` at root
<!-- springboot-skill:end -->
