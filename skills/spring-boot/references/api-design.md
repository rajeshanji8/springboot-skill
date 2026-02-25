# API Design

Follow these conventions when building REST APIs with Spring Boot.

---

## URL Conventions

- Use **lowercase, hyphen-separated** paths: `/api/user-profiles`
- Use **plural nouns** for resources: `/api/users`, `/api/orders`
- Nest sub-resources one level max: `/api/users/{id}/orders`
- Prefix all endpoints with `/api` (or `/api/v1` for versioned APIs).

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
- Use **Java records** for immutability. If records aren't suitable, use plain objects.
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
- Return **400 Bad Request** with field-level error details on validation failure.

```java
@PostMapping("/api/users")
public ResponseEntity<UserResponse> createUser(@Valid @RequestBody CreateUserRequest request) {
    // ...
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
