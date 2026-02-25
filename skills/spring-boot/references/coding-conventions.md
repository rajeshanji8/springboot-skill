# Coding Conventions

Follow these coding standards when writing or modifying Java code in a Spring Boot project.

---

## Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `UserService`, `OrderController` |
| Methods | camelCase, verb-first | `findById()`, `createUser()` |
| Variables | camelCase | `userId`, `orderList` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Packages | lowercase, no underscores | `com.example.appname.service` |
| DTOs | Suffix with `Request`/`Response` | `CreateUserRequest`, `UserResponse` |
| Entities | Singular noun, no suffix | `User`, `Order` |
| Repositories | Suffix with `Repository` | `UserRepository` |

---

## Java Idioms

1. **Use Java records for DTOs** — immutable by default, less boilerplate.
   ```java
   public record UserResponse(Long id, String name, String email) {}
   ```

2. **Use `var` for local variables** when the type is obvious from the right side.
   ```java
   var user = userRepository.findById(id);
   ```

3. **Prefer `Optional` returns** from repository/service methods for single lookups. Never pass `Optional` as a method parameter.

4. **Use constructor injection** — no `@Autowired` on fields.
   ```java
   @Service
   @RequiredArgsConstructor  // or explicit constructor
   public class UserService {
       private final UserRepository userRepository;
   }
   ```

5. **Always use Lombok** — it is a mandatory dependency in every project.
   - `@RequiredArgsConstructor` on every service/component for constructor injection
   - `@Slf4j` on every class that needs logging (this is the **only** way to get a logger)
   - `@Builder` for flexible object construction
   - `@Getter`, `@Setter`, `@NoArgsConstructor` on entities
   - `@Data` on DTOs (but **never** on entities)
   - **Do NOT use Lombok's `@ToString`** — always override `toString()` manually with JSON output (see below)
   - **NEVER write manual `get*()`/`set*()` methods** — always use `@Getter`/`@Setter` annotations. No exceptions.
     - Class-level `@Getter`/`@Setter` for classes where all fields need accessors
     - Field-level `@Getter`/`@Setter` when only specific fields need accessors
     - Use `@Getter(AccessLevel.NONE)` to suppress Lombok's getter for a specific field if needed
   ```java
   // ❌ NEVER do this — manual getters/setters are banned
   public String getName() { return name; }
   public void setName(String name) { this.name = name; }

   // ✅ Always use Lombok
   @Getter
   @Setter
   public class User {
       private String name;
   }
   ```

6. **Use `final` for fields and parameters** where possible to signal immutability.

7. **Every project must have a default `ObjectMapper` bean** in `config/` package:
   ```java
   @Configuration
   public class JacksonConfig {

       @Bean
       public ObjectMapper objectMapper() {
           return new ObjectMapper()
               .registerModule(new JavaTimeModule())
               .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
               .disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES);
       }
   }
   ```

8. **Override `toString()` on every DTO, entity, and model class** to return JSON. When serialization fails, log the error and fall back to class name + hashcode.

   First, create a shared utility in `util/` that reuses the Spring-managed `ObjectMapper` bean:
   ```java
   @Component
   public class JsonUtil {

       private static ObjectMapper MAPPER;

       // Fallback used before Spring context is ready
       private static final ObjectMapper DEFAULT_MAPPER = new ObjectMapper()
           .registerModule(new JavaTimeModule())
           .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
           .disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES);

       public JsonUtil(ObjectMapper objectMapper) {
           JsonUtil.MAPPER = objectMapper;
       }

       public static String toJson(Object obj) {
           try {
               ObjectMapper mapper = MAPPER != null ? MAPPER : DEFAULT_MAPPER;
               return mapper.writeValueAsString(obj);
           } catch (Exception e) {
               return obj.getClass().getSimpleName() + "@" + Integer.toHexString(obj.hashCode());
           }
       }
   }
   ```
   - Once Spring boots, `JsonUtil` picks up the `ObjectMapper` bean from `JacksonConfig` — single source of truth.
   - Before Spring context is ready (e.g., during deserialization), it falls back to a default instance with the same config.

   Then use it in every class:
   ```java
   @Slf4j
   @Entity
   @Getter
   @Setter
   @NoArgsConstructor
   public class User {

       // ... fields ...

       @Override
       public String toString() {
           try {
               return JsonUtil.toJson(this);
           } catch (Exception e) {
               log.error("Failed to serialize {} to JSON", getClass().getSimpleName(), e);
               return getClass().getSimpleName() + "@" + Integer.toHexString(hashCode());
           }
       }
   }
   ```
   **Rules for `toString()`:**
   - Every DTO, entity, request, and response class must override `toString()`.
   - Always return JSON via `JsonUtil.toJson(this)`.
   - Catch all exceptions — use `log.error()` to log the failure, never let `toString()` throw.
   - `JsonUtil` uses a static `ObjectMapper` so it works outside Spring context. The Spring-managed `ObjectMapper` bean in `JacksonConfig` is for injection into services/controllers — `JsonUtil` is for `toString()` and other static contexts.

---

## Formatting

- **Indentation**: 4 spaces (no tabs).
- **Line length**: max 120 characters.
- **Braces**: K&R style (opening brace on same line).
- **Blank lines**: one blank line between methods; no multiple consecutive blank lines.
- **Imports**: no wildcard imports (`*`). Let the IDE organize. See [java-standards.md](java-standards.md) for detailed import and static import rules.

For additional low-level Java conventions — string comparisons, Javadoc, stream comments, null handling, and more — see [java-standards.md](java-standards.md).

---

## Logging

- **Always use Lombok's `@Slf4j`** for logging — never use `LoggerFactory.getLogger(...)` manually.
  ```java
  @Slf4j
  @Service
  @RequiredArgsConstructor
  public class UserService {
      // log is available automatically via @Slf4j
  }
  ```
- Use **parameterized logging** — never string concatenation.
  ```java
  log.info("User created with id={}", user.getId());
  ```
- For full Logback setup with console, file, and error appenders, see [logging.md](logging.md).

---

## Comments

- **Don't state the obvious** — no `// get user` above `getUser()`.
- **Do explain why**, not what — `// retry due to eventual consistency lag`.
- **Use Javadoc** on public service methods and complex logic.
- **Delete commented-out code** — that's what version control is for.

---

## Spring Annotations

- Prefer `@RestController` over `@Controller + @ResponseBody`.
- Use `@Transactional` on **service methods**, not repositories or controllers.
- Use `@Value` or `@ConfigurationProperties` for config — never hardcode values. See [configuration-properties.md](configuration-properties.md) for type-safe binding patterns.
- **All `@Bean` definitions must live in `config/` package only** — never define beans in service, controller, or other packages.
