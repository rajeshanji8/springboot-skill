````markdown
# Java Standards

Low-level Java coding standards that apply to every class, method, and variable. These are small but critical — follow them without exception.

---

## Line Length

**Maximum line length is 120 characters** — no exceptions. If a line exceeds 120 characters, break it.

Breaking rules:
- Break **after** an opening parenthesis or **before** a dot (`.`).
- Indent continuation lines by **8 spaces** (or align with the opening delimiter).
- Each parameter on its own line if a method call doesn't fit in 120 characters.

```java
// ✅ Fits in 120 chars — keep on one line
var user = userRepository.findByEmailAndStatus(email, Status.ACTIVE);

// ✅ Exceeds 120 chars — break and indent
var result = userRepository
        .findByEmailAndStatusAndCreatedAtAfter(
                email,
                Status.ACTIVE,
                Instant.now().minus(Duration.ofDays(30))
        );
```

---

## File Length

**No Java file should exceed 1,000 lines.** If a file grows past this limit, refactor and split it.

- **Services**: extract related methods into a focused sub-service (e.g., `UserService` → `UserService` + `UserNotificationService`).
- **Utility classes**: split by domain area (e.g., `StringUtil`, `DateUtil` instead of one big `CommonUtil`).
- **Configuration classes**: split by concern (e.g., `SecurityConfig`, `CacheConfig`, `AsyncConfig`).

**Exceptions** — these files may exceed 1,000 lines if breaking them would reduce clarity:
- **Controllers** — a controller with many endpoints for a single resource is acceptable.
- **Global exception handlers** — a single `@RestControllerAdvice` handling many exception types.
- **Entity classes** — entities with many columns and relationships.
- **Test classes** — comprehensive test classes with many test methods.

---

## String Comparisons

**Always put the known literal on the left** to avoid `NullPointerException`:

```java
// ✅ Correct — safe if status is null
if ("ACTIVE".equals(status)) { ... }

// ❌ Wrong — throws NPE if status is null
if (status.equals("ACTIVE")) { ... }
```

For enum comparisons, use `==` instead of `.equals()`:
```java
if (user.getRole() == Role.ADMIN) { ... }
```

---

## Javadoc

**Every method must have Javadoc** — public, protected, and package-private.

```java
/**
 * Finds a user by their unique identifier.
 *
 * @param id the user ID
 * @return the user response DTO
 * @throws ResourceNotFoundException if no user exists with the given ID
 */
public UserResponse findById(Long id) { ... }
```

Rules:
- First line is a **concise summary** of what the method does.
- Document every `@param`, `@return`, and `@throws`.
- Private methods: Javadoc optional, but add a brief comment if the logic isn't obvious.
- Classes: add a class-level Javadoc explaining purpose and responsibility.

```java
/**
 * Service responsible for user lifecycle operations — creation,
 * retrieval, updates, and deactivation.
 */
@Service
@RequiredArgsConstructor
public class UserService { ... }
```

---

## Stream Comments

**Every non-trivial stream pipeline must have a comment explaining what it does** — streams can be hard to read at a glance.

**Stream formatting rules:**
- Each stream operation (`.filter`, `.map`, `.collect`, etc.) goes on its **own line**.
- When a stream operation has **nested method calls** (e.g., `Collectors.groupingBy` with multiple arguments), break the arguments onto separate lines with proper indentation.
- Close parentheses align with the opening method call — never pile them on one line.

```java
// Collect active user emails into a comma-separated string for the report
String emails = users.stream()
    .filter(u -> u.isActive())
    .map(User::getEmail)
    .collect(Collectors.joining(", "));

// Group orders by status, counting how many orders are in each status
Map<OrderStatus, Long> ordersByStatus = orders.stream()
    .collect(
        Collectors.groupingBy(
            Order::getStatus,
            Collectors.counting()
        )
    );
```

Simple one-liner streams (`.map`, `.filter`, `.toList()`) don't need a comment if the intent is obvious:
```java
var userIds = users.stream().map(User::getId).toList();
```

---

## Naming — No Consecutive Capitals

**Never use two or more consecutive uppercase letters** in class names, method names, or variable names. This conflicts with JavaBean conventions and causes issues with serialization, MapStruct, and Lombok.

```java
// ✅ Correct
class HttpClient { ... }
class JsonParser { ... }
class UrlValidator { ... }
String htmlContent;
String apiUrl;

// ❌ Wrong — consecutive capitals
class HTTPClient { ... }
class JSONParser { ... }
class URLValidator { ... }
String HTMLContent;
String APIUrl;
```

Exception: Constants use UPPER_SNAKE_CASE, so `MAX_HTTP_RETRIES` is fine.

---

## Imports

### No Wildcard Imports

**Never use wildcard imports** — always import the specific class:

```java
// ✅ Correct
import java.util.List;
import java.util.Map;
import java.util.Optional;

// ❌ Wrong
import java.util.*;
```

Configure your IDE to never auto-collapse imports into wildcards (IntelliJ: Settings → Editor → Code Style → Java → Imports → set "Class count to use import with '*'" to `999`).

### Prefer Static Imports

**Use static imports** for frequently used utilities to reduce noise:

```java
// ✅ Clean — static imports
import static org.springframework.http.HttpStatus.NOT_FOUND;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verify;
import static java.util.Collections.emptyList;

// Then use directly
return ProblemDetail.forStatusAndDetail(NOT_FOUND, ex.getMessage());
assertThat(result).isNotNull();
when(repo.findById(1L)).thenReturn(Optional.of(user));
```

Prefer static imports for:
- **AssertJ**: `assertThat`, `assertThatThrownBy`
- **Mockito**: `when`, `verify`, `mock`, `any`, `eq`
- **Spring test**: `status()`, `jsonPath()`, `get()`, `post()`
- **HTTP status codes**: `HttpStatus.OK`, `HttpStatus.NOT_FOUND`
- **Collections utilities**: `Collections.emptyList()`, `Collections.unmodifiableList()`

Do **not** static-import ambiguous methods that could confuse readers.

---

## Null Handling

1. **Never return `null` from a method** — return `Optional<T>`, an empty collection, or throw an exception.
   ```java
   // ✅ Correct
   public Optional<User> findByEmail(String email) { ... }
   public List<User> findAll() { return List.of(); }  // empty, not null

   // ❌ Wrong
   public User findByEmail(String email) { return null; }
   ```

2. **Use `Objects.requireNonNull()`** for mandatory parameters in constructors and public methods:
   ```java
   public void sendEmail(String to, String body) {
       Objects.requireNonNull(to, "email address must not be null");
       Objects.requireNonNull(body, "email body must not be null");
       // ...
   }
   ```

3. **Never use `null` as a meaningful value** — use `Optional`, enums, or sentinel objects instead.

---

## Collections

1. **Return unmodifiable collections** from getters when the caller shouldn't modify them:
   ```java
   public List<String> getRoles() {
       return Collections.unmodifiableList(roles);
   }
   ```

2. **Prefer `List.of()`, `Set.of()`, `Map.of()`** for creating immutable collections:
   ```java
   var statuses = List.of("ACTIVE", "PENDING", "INACTIVE");
   ```

3. **Use diamond operator** — never repeat the generic type on the right side:
   ```java
   // ✅ Correct
   Map<String, List<User>> usersByRole = new HashMap<>();

   // ❌ Wrong
   Map<String, List<User>> usersByRole = new HashMap<String, List<User>>();
   ```

---

## Exception Handling

1. **Never catch `Exception` or `Throwable`** in business code — catch specific types:
   ```java
   // ✅ Correct
   try {
       parseJson(input);
   } catch (JsonProcessingException e) {
       log.error("Failed to parse JSON", e);
       throw new BadRequestException("Invalid JSON input");
   }

   // ❌ Wrong
   try {
       parseJson(input);
   } catch (Exception e) {
       // too broad
   }
   ```

2. **Never swallow exceptions silently** — always log or rethrow:
   ```java
   // ❌ Never do this
   try { ... } catch (Exception e) { /* ignored */ }
   ```

3. **Use try-with-resources** for all `AutoCloseable` resources:
   ```java
   try (var reader = new BufferedReader(new FileReader(path))) {
       // reader is auto-closed
   }
   ```

---

## Miscellaneous

1. **Prefer `StringBuilder`** for string concatenation in loops — never use `+` in a loop:
   ```java
   var sb = new StringBuilder();
   for (String item : items) {
       sb.append(item).append(", ");
   }
   ```

2. **Use enhanced `switch` expressions** (Java 14+):
   ```java
   String label = switch (status) {
       case ACTIVE -> "Active";
       case INACTIVE -> "Inactive";
       case PENDING -> "Pending Review";
   };
   ```

3. **Use text blocks** for multi-line strings (Java 15+):
   ```java
   String query = """
       SELECT u.id, u.name, u.email
       FROM users u
       WHERE u.status = 'ACTIVE'
       ORDER BY u.name
       """;
   ```

4. **Use `record` for data carriers** — any class that just holds data and has no behavior:
   ```java
   public record Pair<A, B>(A first, B second) {}
   ```

5. **Boolean methods start with `is`, `has`, `can`, `should`**:
   ```java
   boolean isActive() { ... }
   boolean hasPermission(String role) { ... }
   boolean canRetry() { ... }
   ```

6. **Annotations order** — keep consistent:
   ```java
   @Slf4j                    // Lombok first
   @Service                  // Spring stereotype
   @RequiredArgsConstructor  // Lombok injection
   @Transactional            // Spring behavior
   public class UserService { ... }
   ```

7. **No newline at end of file** — files must **not** end with a trailing blank line. The last line should be the closing `}` or the last line of content, nothing after it.

8. **Never use `System.out` or `System.err`** — always use the logger (`@Slf4j`). This includes `System.out.println()`, `System.err.println()`, `e.printStackTrace()`, and `System.out.printf()`.
   ```java
   // ❌ Wrong
   System.out.println("User created: " + user.getId());
   e.printStackTrace();

   // ✅ Correct
   log.info("User created with id={}", user.getId());
   log.error("Unexpected error", e);
   ```

9. **Cyclomatic complexity must not exceed 16** per method. If a method has more than 16 independent paths (nested `if`/`else`, `switch` cases, loops, `&&`/`||`), refactor it:
   - Extract private helper methods for each logical branch.
   - Use early returns / guard clauses to reduce nesting.
   - Replace complex conditionals with strategy pattern or lookup maps.
   ```java
   // ❌ Too complex — nested ifs, multiple branches
   public String getLabel(Order order) {
       if (order.getStatus() == ACTIVE) {
           if (order.isPriority()) {
               // ... more branches
           }
       }
       // 20 more branches...
   }

   // ✅ Refactored — early returns, extracted methods
   public String getLabel(Order order) {
       if (order == null) return "Unknown";
       return switch (order.getStatus()) {
           case ACTIVE -> getActiveLabel(order);
           case PENDING -> getPendingLabel(order);
           case CANCELLED -> "Cancelled";
       };
   }
   ```

````
