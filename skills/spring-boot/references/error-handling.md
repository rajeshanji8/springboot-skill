# Error Handling

Follow these conventions for consistent error handling across the Spring Boot application.

---

## Strategy

**Global exception handling is mandatory in every project — no exceptions.**

1. **Every project must have a `@RestControllerAdvice` class** in the `exception/` package to handle all exceptions in one place.
2. **Use RFC 9457 Problem Details** format for error responses.
3. **Throw custom exceptions from services** — never return nulls to signal errors.
4. **Don't catch generic `Exception`** — catch specific types or let the global handler deal with it.
5. **This is not optional** — if a project has REST endpoints, it must have a `GlobalExceptionHandler`.

---

## Problem Details Response Format

Spring Boot 3.x supports RFC 9457 natively. Enable it in `application.properties`:

```properties
spring.mvc.problemdetails.enabled=true
```

Error responses should look like:

```json
{
  "type": "about:blank",
  "title": "Not Found",
  "status": 404,
  "detail": "User with id 42 not found",
  "instance": "/api/users/42"
}
```

---

## Custom Exceptions

Define domain-specific exceptions in the `exception/` package:

```java
public class ResourceNotFoundException extends RuntimeException {
    public ResourceNotFoundException(String resource, Object id) {
        super("%s with id %s not found".formatted(resource, id));
    }
}

public class BusinessRuleException extends RuntimeException {
    public BusinessRuleException(String message) {
        super(message);
    }
}

public class ConflictException extends RuntimeException {
    public ConflictException(String message) {
        super(message);
    }
}

public class ExternalServiceException extends RuntimeException {
    public ExternalServiceException(String message) {
        super(message);
    }

    public ExternalServiceException(String message, Throwable cause) {
        super(message, cause);
    }
}
```

---

## Global Exception Handler

```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    public ProblemDetail handleNotFound(ResourceNotFoundException ex) {
        log.warn(ex.getMessage());
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        var detail = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        detail.setTitle("Validation Failed");
        // Use groupingBy to handle multiple errors per field
        var errors = ex.getFieldErrors().stream()
            .collect(Collectors.groupingBy(
                FieldError::getField,
                Collectors.mapping(
                    fe -> fe.getDefaultMessage() != null ? fe.getDefaultMessage() : "invalid",
                    Collectors.toList()
                )
            ));
        detail.setProperty("fieldErrors", errors);
        return detail;
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ProblemDetail handleConstraintViolation(ConstraintViolationException ex) {
        var detail = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        detail.setTitle("Constraint Violation");
        var errors = ex.getConstraintViolations().stream()
            .collect(Collectors.toMap(
                v -> v.getPropertyPath().toString(),
                ConstraintViolation::getMessage,
                (a, b) -> a + "; " + b
            ));
        detail.setProperty("violations", errors);
        return detail;
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ProblemDetail handleMalformedJson(HttpMessageNotReadableException ex) {
        log.warn("Malformed request body: {}", ex.getMessage());
        var detail = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        detail.setTitle("Malformed Request Body");
        detail.setDetail("The request body could not be parsed. Ensure it is valid JSON.");
        return detail;
    }

    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ProblemDetail handleMissingParam(MissingServletRequestParameterException ex) {
        var detail = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        detail.setTitle("Missing Request Parameter");
        detail.setDetail("Required parameter '" + ex.getParameterName() + "' is missing.");
        return detail;
    }

    @ExceptionHandler(ConflictException.class)
    public ProblemDetail handleConflict(ConflictException ex) {
        log.warn(ex.getMessage());
        return ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.getMessage());
    }

    @ExceptionHandler(BusinessRuleException.class)
    public ProblemDetail handleBusinessRule(BusinessRuleException ex) {
        log.warn(ex.getMessage());
        return ProblemDetail.forStatusAndDetail(HttpStatus.UNPROCESSABLE_ENTITY, ex.getMessage());
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ProblemDetail handleDataIntegrity(DataIntegrityViolationException ex) {
        log.warn("Data integrity violation: {}", ex.getMostSpecificCause().getMessage());
        var detail = ProblemDetail.forStatus(HttpStatus.CONFLICT);
        detail.setTitle("Data Conflict");
        detail.setDetail("The operation conflicts with existing data (e.g., duplicate value).");
        return detail;
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ProblemDetail handleAccessDenied(AccessDeniedException ex) {
        var detail = ProblemDetail.forStatus(HttpStatus.FORBIDDEN);
        detail.setTitle("Forbidden");
        detail.setDetail("You do not have permission to perform this action.");
        return detail;
    }

    @ExceptionHandler(ExternalServiceException.class)
    public ProblemDetail handleExternalService(ExternalServiceException ex) {
        log.error("External service failure: {}", ex.getMessage());
        return ProblemDetail.forStatusAndDetail(
            HttpStatus.BAD_GATEWAY, "An upstream service is unavailable"
        );
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleUnexpected(Exception ex) {
        log.error("Unexpected error", ex);
        return ProblemDetail.forStatusAndDetail(
            HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred"
        );
    }
}
```

---

## Rules

1. **Never expose stack traces** in API responses.
2. **Log the full exception server-side** (`log.error("msg", ex)`), return a safe message to clients.
3. **Use appropriate HTTP status codes** — see [api-design.md](api-design.md) for the full table.
4. **Validation errors return 400** with field-level details.
5. **Business rule violations** return 409 (Conflict) or 422 (Unprocessable Entity).
