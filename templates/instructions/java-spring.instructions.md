---
applyTo: "**/*.java"
---

# Java & Spring Boot Conventions

Follow the spring-boot skill at `.github/skills/spring-boot/SKILL.md` for all Java code.

## Injection & Lombok
- Use `@RequiredArgsConstructor` for dependency injection — NEVER `@Autowired` on fields
- Use `@Slf4j` for logging — never `LoggerFactory.getLogger()` or `System.out.println()`
- Use `@Getter`/`@Setter` on entities — never write manual getters/setters
- Never use `@Data` on JPA entities — use `@Getter`, `@Setter`, `@NoArgsConstructor` individually

## DTOs & Entities
- Java records for all DTOs — suffix with `Request`/`Response`
- Entities never cross the service boundary — always return DTOs from services
- Override `toString()` with `JsonUtil.toJson(this)` on all DTOs and entities
- `@JsonIgnore` on every sensitive field (password, token, secret, apiKey)

## Architecture
- No business logic in controllers — delegate to services only
- `@Transactional` on service methods only — never controllers
- All `@Bean` definitions in `config/` package only
- MapStruct with `componentModel = "spring"` for entity↔DTO mapping

## Code Style
- Max 120 characters per line, max 1,000 lines per file
- No wildcard imports — import specific classes
- Never return `null` — use `Optional<T>`, empty collections, or throw exceptions
- Parameterized logging: `log.info("id={}", id)` — never string concatenation
- `BigDecimal` (from `String`) for financial values — never `double`/`float`
