# Coding Conventions

Follow these coding standards when writing or modifying Java code in a Spring Boot project.

---

## TLDR — Mandatory Rules
- Use constructor injection (`@RequiredArgsConstructor`) — NEVER field `@Autowired`
- Lombok is mandatory: `@Slf4j` for logging, `@Getter`/`@Setter` for accessors — never manual getters/setters
- Java records for all immutable DTOs — never `@Data` on entities
- Override `toString()` on every entity AND every Java record DTO — records auto-generate non-JSON `toString()`, you MUST still override it with `JsonUtil.toJson(this)`. NEVER log inside `toString()`
- Strict layer discipline: no business logic in controllers, no entities in API responses
- `@JsonIgnore` on every sensitive field (password, token, secret, apiKey)
- Services MUST be stateless — no mutable shared state in Spring beans, no request-scoped data in instance fields

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

3. **ALWAYS return `Optional<T>`** from repository/service methods for single lookups. Never pass `Optional` as a method parameter.

4. **Use constructor injection** — no `@Autowired` on fields.
   ```java
   @Service
   @RequiredArgsConstructor  // or explicit constructor
   public class UserService {
       private final UserRepository userRepository;
   }
   ```

5. **Lombok is standard and required** — it is a mandatory dependency in every project. Do not remove it or avoid it unless a strong justification is documented and approved by the team.
   - `@RequiredArgsConstructor` on every service/component for constructor injection
   - `@Slf4j` on every class that needs logging (this is the **only** way to get a logger)
   - `@Builder` for flexible object construction
   - `@Getter`, `@Setter`, `@NoArgsConstructor` on entities
   - **Never use `@Data` on DTOs** — prefer Java records for all immutable DTOs (requests and responses). Only use `@Data` on a mutable DTO class when MapStruct's `@MappingTarget` requires setters (see [mapper-conventions.md](mapper-conventions.md)). `@Data` is **never** allowed on entities.
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
               .disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
               .disable(SerializationFeature.FAIL_ON_EMPTY_BEANS);
       }
   }
   ```

8. **Override `toString()` on every DTO, entity, and model class** to return JSON. When serialization fails, log the error and fall back to class name + hashcode.

   First, create a **pure utility class** (no Spring dependency) in `util/`:
   ```java
   public final class JsonUtil {

       private static final ObjectMapper MAPPER = new ObjectMapper()
           .registerModule(new JavaTimeModule())
           .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
           .disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
           .disable(SerializationFeature.FAIL_ON_EMPTY_BEANS);

       private JsonUtil() {}

       public static String toJson(Object obj) {
           try {
               return MAPPER.writeValueAsString(obj);
           } catch (Exception e) {
               return obj.getClass().getSimpleName() + "@" + Integer.toHexString(obj.hashCode());
           }
       }
   }
   ```
   - `JsonUtil` is a **stateless utility** — no `@Component`, no Spring injection, no static mutable state.
   - It owns its own `ObjectMapper` instance configured identically to the `JacksonConfig` bean.
   - The Spring-managed `ObjectMapper` bean in `JacksonConfig` is for injection into services/controllers. `JsonUtil` is exclusively for `toString()` and other static contexts.
   - **Do not make `JsonUtil` a Spring bean** — mixing static access with dependency injection creates testing difficulties and class-loader issues.

   Then use it in every class:
   ```java
   @Entity
   @Getter
   @Setter
   @NoArgsConstructor
   public class User {

       // ... fields ...

       @Override
       public String toString() {
           return JsonUtil.toJson(this);
       }
   }
   ```
   **Rules for `toString()`:**
   - Every DTO, entity, request, and response class must override `toString()`.
   - Always return JSON via `JsonUtil.toJson(this)`. The method already handles exceptions internally — it returns `ClassName@hashCode` on failure.
   - **Never log inside `toString()`** — SLF4J's `{}` placeholder calls `toString()` on the argument. If `toString()` itself logs with `{}`, you get infinite recursion. Let `JsonUtil.toJson()` handle failures silently.
   - `JsonUtil` uses a static `ObjectMapper` so it works outside Spring context. The Spring-managed `ObjectMapper` bean in `JacksonConfig` is for injection into services/controllers — `JsonUtil` is for `toString()` and other static contexts.

   **Circular Reference Prevention (bidirectional JPA relationships):**

   Entities with bidirectional `@OneToMany` / `@ManyToOne` relationships **will cause infinite recursion** when serialized to JSON via `toString()`. Always break the cycle on the inverse (non-owning) side:

   ```java
   @Entity
   @Getter
   @Setter
   @NoArgsConstructor
   public class User {

       @Id
       @GeneratedValue(strategy = GenerationType.IDENTITY)
       private Long id;

       private String name;

       @OneToMany(mappedBy = "user", fetch = FetchType.LAZY)
       @JsonManagedReference  // serialized normally
       private List<Order> orders = new ArrayList<>();

       @Override
       public String toString() {
           return JsonUtil.toJson(this);
       }
   }

   @Entity
   @Getter
   @Setter
   @NoArgsConstructor
   public class Order {

       @Id
       @GeneratedValue(strategy = GenerationType.IDENTITY)
       private Long id;

       private String product;

       @ManyToOne(fetch = FetchType.LAZY)
       @JoinColumn(name = "user_id")
       @JsonBackReference  // excluded from serialization — breaks the cycle
       private User user;

       @Override
       public String toString() {
           return JsonUtil.toJson(this);
       }
   }
   ```

   **Which annotation to use:**

   | Annotation | Side | Effect |
   |-----------|------|--------|
   | `@JsonManagedReference` | Parent (owning the collection) | Serialized normally |
   | `@JsonBackReference` | Child (back-pointer to parent) | Excluded from serialization |
   | `@JsonIgnore` | Either side | Excluded from serialization entirely — use when you don't need the relationship in JSON at all |

   **Rules for circular references:**
   - **Always annotate bidirectional relationships** — every `@OneToMany` / `@ManyToOne` pair must have `@JsonManagedReference` + `@JsonBackReference`.
   - **Prefer `@JsonBackReference`** on the `@ManyToOne` side (child → parent). If you need the parent ID in the child's JSON, add a separate `@JsonProperty` getter:
     ```java
     @JsonBackReference
     private User user;

     @JsonProperty("userId")
     public Long getUserId() {
         return user != null ? user.getId() : null;
     }
     ```
   - **Use `@JsonIgnore`** for relationships that are never needed in JSON output (e.g., internal mappings).
   - **Never rely on `@ToString.Exclude`** — that's Lombok's `@ToString`, which we don't use. We override `toString()` manually with `JsonUtil.toJson(this)`, so Jackson annotations (`@JsonBackReference`, `@JsonIgnore`) are what actually break the cycle.

   **Sensitive Field Protection — security guardrail for `toString()` / JSON:**

   If an entity or DTO contains **passwords, tokens, API keys, secrets, PII** (SSN, credit card numbers), or any sensitive data — you **must** exclude those fields from serialization. Otherwise `toString()`, logging, and API responses will leak them.

   ```java
   @Entity
   @Getter
   @Setter
   @NoArgsConstructor
   public class User {

       @Id
       @GeneratedValue(strategy = GenerationType.IDENTITY)
       private Long id;

       private String name;
       private String email;

       @JsonIgnore  // NEVER serialize passwords
       private String password;

       @JsonIgnore  // NEVER serialize tokens
       private String refreshToken;

       @JsonIgnore  // NEVER serialize secrets
       private String apiKey;

       @Override
       public String toString() {
           return JsonUtil.toJson(this);
       }
   }
   ```

   **Rules for sensitive fields:**
   - **`@JsonIgnore`** on every field containing: `password`, `token`, `secret`, `apiKey`, `accessKey`, `ssn`, `creditCard`, `pin`, or any PII.
   - This protects **all paths** — `toString()`, Jackson serialization in API responses, and log statements.
   - For DTOs: if a request DTO receives a password (e.g., `CreateUserRequest`), annotate it with `@JsonProperty(access = JsonProperty.Access.WRITE_ONLY)` so it's accepted on input but never written to output:
     ```java
     public record CreateUserRequest(
         String name,
         String email,
         @JsonProperty(access = JsonProperty.Access.WRITE_ONLY) String password
     ) {}
     ```
   - **Audit regularly** — when adding new fields to entities/DTOs, check if they contain sensitive data before committing.
   - When in doubt, **exclude the field**. It's always safer to add it back than to leak it accidentally.

   **Performance considerations for `toString()` with JSON:**
   - **Lazy-loaded proxies**: Calling `toString()` on an entity with `FetchType.LAZY` collections **outside a transaction** will throw `LazyInitializationException`. `JsonUtil.toJson()` catches this internally and falls back to `ClassName@hashCode`.
   - **Don't call `toString()` in hot loops** — serializing an entity to JSON on every iteration is expensive. Use it for logging and debugging, not for data processing.
   - **Log at `DEBUG` level with parameterized logging** — `log.debug("Loaded user: {}", user)` — SLF4J only calls `toString()` if DEBUG is enabled, so there's zero cost in production when DEBUG is off.

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

## Layer Discipline

Strict boundaries between layers prevent architecture erosion. These rules are non-negotiable.

1. **Services must be stateless** — no mutable shared state in Spring beans. Never store request-scoped data in instance fields. If you need shared state, use a `@RequestScope` bean or pass it through method parameters.
   ```java
   // ❌ NEVER — mutable state in a singleton bean
   @Service
   public class OrderService {
       private User currentUser;  // shared across all requests!
   }

   // ✅ Stateless — everything passed as parameters
   @Service
   @RequiredArgsConstructor
   public class OrderService {
       private final OrderRepository orderRepository;
       private final OrderMapper orderMapper;

       public OrderResponse create(CreateOrderRequest request, Long userId) {
           // ...
       }
   }
   ```

2. **No `@Transactional` in controllers** — transactions belong in the service layer. Controllers are HTTP adapters; they must not manage database transactions.
   ```java
   // ❌ NEVER
   @RestController
   public class UserController {
       @Transactional  // wrong layer
       @PostMapping("/users")
       public UserResponse create(@RequestBody CreateUserRequest request) { ... }
   }

   // ✅ Transaction in service
   @Service
   public class UserService {
       @Transactional
       public UserResponse create(CreateUserRequest request) { ... }
   }
   ```

3. **No entity returned from controller** — controllers must always return DTOs (response records). Entities are internal to the service layer. Exposing entities leaks database structure, lazy proxies, and sensitive fields.
   ```java
   // ❌ NEVER — entity in API response
   @GetMapping("/users/{id}")
   public User getUser(@PathVariable Long id) {
       return userRepository.findById(id).orElseThrow(...);
   }

   // ✅ Always return a DTO
   @GetMapping("/users/{id}")
   public UserResponse getUser(@PathVariable Long id) {
       return userService.findById(id);  // service returns DTO
   }
   ```

4. **Mapping happens in the service layer** — controllers receive DTOs, pass them to services. Services call mappers internally and return DTOs. See [mapper-conventions.md](mapper-conventions.md).

5. **No raw repository results exposed** — service methods must never return `Optional<Entity>`, `List<Entity>`, or `Page<Entity>` directly. Always map to DTOs before returning.
   ```java
   // ❌ NEVER — leaking entity through service API
   public Optional<User> findById(Long id) {
       return userRepository.findById(id);
   }

   // ✅ Map to DTO inside the service
   public UserResponse findById(Long id) {
       var user = userRepository.findById(id)
           .orElseThrow(() -> new ResourceNotFoundException("User", id));
       return userMapper.toResponse(user);
   }
   ```

---

## Spring Annotations

- Prefer `@RestController` over `@Controller + @ResponseBody`.
- Use `@Transactional` on **service methods**, not repositories or controllers (see Layer Discipline above).
- Use `@Value` or `@ConfigurationProperties` for config — never hardcode values. See [configuration-properties.md](configuration-properties.md) for type-safe binding patterns.
- **All `@Bean` definitions must live in `config/` package only** — never define beans in service, controller, or other packages.
