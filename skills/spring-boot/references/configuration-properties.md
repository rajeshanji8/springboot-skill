# Configuration Properties

Follow these conventions for externalizing and binding configuration in Spring Boot.

---

## Strategy

1. **Use `application.properties`** as the single config file — no YAML, no profiles.
2. **Use environment variable placeholders** for values that differ per environment.
3. **Use `@ConfigurationProperties`** for type-safe binding of related properties.
4. **Use `@Value`** only for simple, one-off values.
5. **All config classes live in `config/` package.**

---

## Type-Safe Configuration with @ConfigurationProperties

### Define a Properties Class

```java
@Getter
@Setter
@Validated
@ConfigurationProperties(prefix = "app")
public class AppProperties {

    @NotBlank
    private String name;

    @NotNull
    private final Api api = new Api();

    @NotNull
    private final Cors cors = new Cors();

    @Getter
    @Setter
    public static class Api {
        private String basePath = "/api";
        private int defaultPageSize = 20;
        private int maxPageSize = 100;
    }

    @Getter
    @Setter
    public static class Cors {
        private List<String> allowedOrigins = List.of("http://localhost:3000");
        private List<String> allowedMethods = List.of("GET", "POST", "PUT", "DELETE", "PATCH");
    }
}
```

### Enable in Configuration

```java
@Configuration
@EnableConfigurationProperties(AppProperties.class)
public class AppConfig {
}
```

### Usage

```java
@Service
@RequiredArgsConstructor
public class SomeService {

    private final AppProperties appProperties;

    public void doSomething() {
        int pageSize = appProperties.getApi().getDefaultPageSize();
        // ...
    }
}
```

### In application.properties

```properties
# ===== Application Config =====
app.name=${APP_NAME:my-app}
app.api.base-path=/api
app.api.default-page-size=20
app.api.max-page-size=100
app.cors.allowed-origins=http://localhost:3000
app.cors.allowed-methods=GET,POST,PUT,DELETE,PATCH
```

---

## Environment Variable Placeholders

Use `${ENV_VAR:default}` syntax for anything that changes per environment:

```properties
# Database
spring.datasource.url=${DATABASE_URL:jdbc:postgresql://localhost:5432/mydb}
spring.datasource.username=${DATABASE_USERNAME:postgres}
spring.datasource.password=${DATABASE_PASSWORD:}

# JWT
app.jwt.secret=${JWT_SECRET:dev-secret-change-in-production}
app.jwt.expiration-ms=${JWT_EXPIRATION:3600000}

# External services
app.email.api-key=${EMAIL_API_KEY:}
app.email.base-url=${EMAIL_BASE_URL:https://api.email-provider.com}
```

---

## @Value for Simple Cases

Use `@Value` only when you need a single property injected directly:

```java
@RestController
public class HealthController {

    @Value("${spring.application.name}")
    private String appName;
}
```

Prefer `@ConfigurationProperties` over `@Value` when:
- You have **3+ related properties** under the same prefix
- You need **validation** on config values
- You want **IDE autocomplete** via `spring-configuration-metadata.json`

---

## Validation

Add Jakarta Validation annotations to `@ConfigurationProperties` classes. Spring validates them at startup — the app won't start with invalid config:

```java
@Getter
@Setter
@Validated
@ConfigurationProperties(prefix = "app.jwt")
public class JwtProperties {

    @NotBlank
    private String secret;

    @Min(60000)   // at least 1 minute
    @Max(86400000) // at most 24 hours
    private long expirationMs = 3600000;
}
```

---

## Rules

1. **One `application.properties` file** — no `application-dev.properties` or `application-prod.properties`. Use environment variables for per-environment differences.
2. **All `@ConfigurationProperties` classes live in `config/` package.**
3. **Always use `@Validated`** on `@ConfigurationProperties` classes — fail fast on bad config.
4. **Use sensible defaults** in the placeholder syntax: `${ENV_VAR:default-value}`.
5. **Never hardcode secrets, URLs, or environment-specific values** — always externalize them. See [security.md](security.md) for secrets management and [docker.md](docker.md) for Docker environment variables.
6. **Group related properties under a common prefix**: `app.jwt.*`, `app.cors.*`, `app.email.*`.
7. **Use relaxed binding** — Spring maps `app.default-page-size` in properties to `defaultPageSize` in Java automatically.
