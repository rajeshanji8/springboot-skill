# Security

Follow these conventions for securing a Spring Boot application.

---

## Dependencies

Use **Spring Security** as the foundation. Add:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>
```

---

## Authentication

- Default: **Stateless JWT-based authentication**.
- Configure via a `SecurityConfig` class in `config/`.

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(csrf -> csrf.disable())  // Stateless API — no CSRF needed
            .sessionManagement(session -> session.sessionCreationPolicy(STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers("/actuator/**").permitAll()
                .anyRequest().authenticated()
            )
            .build();
    }
}
```

---

## CORS

Configure CORS in the security config or a dedicated `@Bean`:

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    var config = new CorsConfiguration();
    config.setAllowedOrigins(List.of("http://localhost:3000"));
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "PATCH"));
    config.setAllowedHeaders(List.of("*"));
    var source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", config);
    return source;
}
```
---

## Secrets Management

1. **Never commit secrets** to source control.
2. Store secrets in **environment variables** or a vault.
3. Reference in `application.properties`:
   ```properties
   spring.datasource.password=${DB_PASSWORD}
   jwt.secret=${JWT_SECRET}
   ```
4. Use `.env` files locally (add to `.gitignore`).

---

## Rules

1. **No security config in controllers** — all rules live in `SecurityConfig`.
2. **Use method-level security sparingly** — `@PreAuthorize` only when URL-based rules aren't enough.
3. **Hash passwords** with `BCryptPasswordEncoder` — never store plaintext.
4. **Validate all input** — security starts at the API boundary (see [api-design.md](api-design.md)).
5. **Return 401 for missing auth, 403 for insufficient permissions** — be precise.
6. **Actuator is always enabled** — expose health, info, and metrics. Lock down sensitive endpoints behind auth. See [actuator-health.md](actuator-health.md) for full configuration, custom health indicators, and metrics.
