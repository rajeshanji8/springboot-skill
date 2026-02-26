# API Design

Follow these conventions when building REST APIs with Spring Boot.

---

## TLDR — Mandatory Rules
- URI versioning: always prefix with `/api/v1/`, lowercase hyphen-separated plural nouns
- Every endpoint MUST have Swagger/OpenAPI annotations (`@Tag`, `@Operation`, `@ApiResponses`)
- Always use DTOs (Java records) — never bind directly to entities
- `@Valid` on `@RequestBody` + `@Validated` on the controller class — both required
- Every list endpoint must define a default sort via `@PageableDefault` or `@SortDefault`
- Never modify the contract of a released API version
- Do NOT use Spring HATEOAS — return plain DTOs, document endpoints in Swagger/OpenAPI

---

## URL Conventions

- Use **lowercase, hyphen-separated** paths: `/api/user-profiles`
- Use **plural nouns** for resources: `/api/users`, `/api/orders`
- Nest sub-resources one level max: `/api/users/{id}/orders`
- Prefix all endpoints with `/api/v1` — always include the version.

---

## API Versioning

**Always use URI-based versioning** — the version is part of the URL path, not headers or query params.

```
/api/v1/users
/api/v1/orders/{id}
/api/v2/users
```

### When to Bump the Version

| Change Type | Version Bump? | Example |
|-------------|---------------|---------|
| **Breaking** — removing a field, renaming a field, changing a field's type, removing an endpoint, changing response structure | **Yes → new major version** (`v1` → `v2`) | Removing `email` from `UserResponse`, changing `id` from `Long` to `UUID` |
| **Non-breaking** — adding a new optional field, adding a new endpoint, adding a new query param | **No** | Adding `phone` to `UserResponse`, adding `GET /api/v1/users/search` |
| **Deprecation** — marking an endpoint for future removal | **No** — keep old version, add `@Deprecated` and document the replacement | `GET /api/v1/users/legacy` → replaced by `GET /api/v1/users` |

### Backward Compatibility Rules

1. **Non-breaking changes go into the current version** — adding fields, endpoints, or optional params never requires a version bump.
2. **Breaking changes require a new version** — create a new controller (e.g., `UserV2Controller`) mapped to `/api/v2/users`.
3. **Support at most 2 versions simultaneously** — `v1` (deprecated) + `v2` (current). Remove `v1` after a documented sunset period.
4. **Never modify the contract of a released version** — once `v1` is live, its request/response shape is frozen.
5. **Document deprecation in Swagger** — use `@Deprecated` on the controller and `@Operation(deprecated = true)` on endpoints.

### Controller Structure for Multiple Versions

```java
// Current version
@Tag(name = "Users v1", description = "User management APIs")
@RestController
@RequestMapping("/api/v1/users")
public class UserController {
    // ...
}

// New version with breaking changes
@Tag(name = "Users v2", description = "User management APIs (v2)")
@RestController
@RequestMapping("/api/v2/users")
public class UserV2Controller {
    // New response shape, different field names, etc.
}
```

Share business logic in the service layer — only the controller + DTOs change between versions. Never duplicate service code.

<!-- CUSTOMIZE: If your organization uses header-based versioning (Accept: application/vnd.myapp.v2+json), replace URI versioning with that approach -->

---

## HTTP Methods

| Action | Method | Path | Response |
|--------|--------|------|----------|
| List | GET | `/api/users` | 200 + list |
| Get one | GET | `/api/users/{id}` | 200 or 404 |
| Create | POST | `/api/users` | 201 + created resource |
| Update (full) | PUT | `/api/users/{id}` | 200 + updated resource |
| Update (partial) | PATCH | `/api/users/{id}` | 200 + updated resource |
| Delete | DELETE | `/api/users/{id}` | 204 (no content) |

---

## Swagger / OpenAPI

- **Every REST endpoint must have Swagger annotations** — no exceptions.
- Use **SpringDoc OpenAPI** (`springdoc-openapi-starter-webmvc-ui`).
- Add to `pom.xml`:
  ```xml
  <dependency>
      <groupId>org.springdoc</groupId>
      <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
  </dependency>
  ```
- Annotate every controller and endpoint:
  ```java
  @Tag(name = "Users", description = "User management APIs")
  @RestController
  @RequestMapping("/api/users")
  public class UserController {

      @Operation(summary = "Create a new user")
      @ApiResponses({
          @ApiResponse(responseCode = "201", description = "User created"),
          @ApiResponse(responseCode = "400", description = "Validation error")
      })
      @PostMapping
      public ResponseEntity<UserResponse> createUser(@Valid @RequestBody CreateUserRequest request) {
          // ...
      }
  }
  ```
- Configure in `application.properties`:
  ```properties
  springdoc.api-docs.path=/api-docs
  springdoc.swagger-ui.path=/swagger-ui.html
  ```
- Swagger UI must be accessible at `/swagger-ui.html` in all environments.

---

## Request / Response DTOs

- **Always use DTOs** — never bind directly to entities.
- Use **Java records** for ALL DTOs. Use mutable classes ONLY when MapStruct `@MappingTarget` requires setters (see [mapper-conventions.md](mapper-conventions.md)).
- Separate `CreateXRequest`, `UpdateXRequest`, and separate `CreateXResponse`, `UpdateXResponse`.
- For entity ↔ DTO mapping, see [mapper-conventions.md](mapper-conventions.md).

```java
public record CreateUserRequest(
    @NotBlank String name,
    @Email String email
) {}

public record UserResponse(
    Long id,
    String name,
    String email,
    Instant createdAt
) {}
```

---

## Validation

- Use **Jakarta Bean Validation** annotations on request DTOs: `@NotBlank`, `@Email`, `@Size`, `@Min`, `@Max`, `@Pattern`.
- Annotate controller parameters with `@Valid`.
- **Add `@Validated` on the controller class** to enable validation of `@PathVariable` and `@RequestParam` arguments.
- Return **400 Bad Request** with field-level error details on validation failure.

```java
@Validated  // enables @Min, @Max, etc. on path/query params
@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    @PostMapping
    public ResponseEntity<UserResponse> createUser(@Valid @RequestBody CreateUserRequest request) {
        // ...
    }

    @GetMapping("/{id}")
    public UserResponse getUser(@PathVariable @Min(1) Long id) {
        // @Min(1) validated because controller has @Validated
        return userService.findById(id);
    }
}
```

---

## Response Envelope

Return resources directly (no wrapping) for single items. For lists, use either:

- Direct list: `List<UserResponse>`
- Spring's `Page<UserResponse>` for paginated endpoints

---

## Pagination

- Use Spring Data's `Pageable` with query params: `?page=0&size=20&sort=name,asc`
- Return `Page<T>` which includes pagination metadata.
- Default page size: 20. Max page size: 100.

### Configuring Defaults and Limits

Set global pagination defaults in `application.properties`:

```properties
# ===== Pagination =====
spring.data.web.pageable.default-page-size=20
spring.data.web.pageable.max-page-size=100
spring.data.web.pageable.one-indexed-parameters=false
```

---

## Sorting

### Format

Sorting uses the `sort` query parameter with the field name and direction:

```
GET /api/v1/users?sort=name,asc
GET /api/v1/users?sort=createdAt,desc
```

### Multiple Sorts

**Multiple sort fields are allowed** — repeat the `sort` parameter:

```
GET /api/v1/users?sort=lastName,asc&sort=firstName,asc
GET /api/v1/orders?sort=status,asc&sort=createdAt,desc
```

Spring Data's `Pageable` handles this automatically — each `sort` param becomes a `Sort.Order` in the `Pageable` object.

### Default Sort

**Every list endpoint must define a default sort** — never return unsorted results. Use `@PageableDefault` or `@SortDefault`:

```java
@GetMapping
public Page<UserResponse> listUsers(
        @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC)
        Pageable pageable) {
    return userService.findAll(pageable);
}
```

Default sort guidance:
- **Business entities** (`User`, `Order`): sort by `createdAt,desc` (newest first)
- **Reference data** (`Country`, `Category`): sort by `name,asc` (alphabetical)
- **Search results**: sort by relevance if available, otherwise `createdAt,desc`

### Invalid Sort Fields

**Reject requests with invalid sort fields** — don't silently ignore them. Spring Data throws `PropertyReferenceException` when a sort field doesn't match an entity property. Handle it in the global exception handler:

```java
@ExceptionHandler(PropertyReferenceException.class)
public ProblemDetail handleInvalidSort(PropertyReferenceException ex) {
    log.warn("Invalid sort field: {}", ex.getMessage());
    var detail = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
    detail.setTitle("Invalid Sort Parameter");
    detail.setDetail("Unknown sort field: '" + ex.getPropertyName() 
        + "'. Allowed fields depend on the resource.");
    return detail;
}
```

### Restricting Sortable Fields

For sensitive resources, restrict which fields can be sorted on. Validate in the controller or use a custom `Pageable` resolver:

```java
private static final Set<String> ALLOWED_SORT_FIELDS = Set.of(
    "name", "email", "createdAt", "updatedAt"
);

@GetMapping
public Page<UserResponse> listUsers(Pageable pageable) {
    pageable.getSort().forEach(order -> {
        if (!ALLOWED_SORT_FIELDS.contains(order.getProperty())) {
            throw new InvalidSortFieldException(order.getProperty(), ALLOWED_SORT_FIELDS);
        }
    });
    return userService.findAll(pageable);
}
```

This prevents information leakage — callers can't probe for entity field names by trying random sort values.

---

## Response Status Codes

| Scenario | Status |
|----------|--------|
| Success (with body) | 200 OK |
| Created | 201 Created |
| Accepted (async) | 202 Accepted |
| No content (delete) | 204 No Content |
| Bad input | 400 Bad Request |
| Unauthorized | 401 Unauthorized |
| Forbidden | 403 Forbidden |
| Not found | 404 Not Found |
| Conflict | 409 Conflict |
| Server error | 500 Internal Server Error |

---

## HATEOAS

**Do not use Spring HATEOAS.** Return plain DTOs without hypermedia links. HATEOAS adds significant complexity with minimal benefit for most REST APIs. Document endpoints in Swagger/OpenAPI instead.
