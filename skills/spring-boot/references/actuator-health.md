````markdown
# Actuator & Health

Follow these conventions for monitoring, health checks, and metrics in Spring Boot.

---

## Dependencies

Spring Boot Actuator is included with:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

For Prometheus metrics export (optional):
```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

<!-- CUSTOMIZE: Add Prometheus dependency if you use Prometheus/Grafana for monitoring -->

---

## Configuration

Configure in `application.properties`:

```properties
# ===== Actuator =====
management.endpoints.web.exposure.include=health,info,metrics,env,loggers,caches,prometheus
management.endpoint.health.show-details=when-authorized
management.endpoint.env.show-values=when-authorized
management.info.env.enabled=true

# ===== Application Info =====
info.app.name=${spring.application.name}
info.app.description=Spring Boot application
info.app.version=@project.version@
info.app.java-version=${java.version}
```

---

## Key Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/actuator/health` | Application health status (UP/DOWN) |
| `/actuator/info` | Application metadata |
| `/actuator/metrics` | All available metrics |
| `/actuator/metrics/{name}` | Specific metric (e.g., `jvm.memory.used`) |
| `/actuator/loggers` | View and change log levels at runtime |
| `/actuator/caches` | Cache statistics |
| `/actuator/env` | Environment properties (redacted by default) |
| `/actuator/prometheus` | Prometheus-format metrics (if micrometer-registry-prometheus is added) |

---

## Custom Health Indicators

Create custom health checks for external dependencies:

```java
@Component
public class DatabaseHealthIndicator implements HealthIndicator {

    private final DataSource dataSource;

    public DatabaseHealthIndicator(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    public Health health() {
        try (var conn = dataSource.getConnection()) {
            if (conn.isValid(2)) {
                return Health.up()
                    .withDetail("database", "PostgreSQL")
                    .withDetail("validationQuery", "isValid()")
                    .build();
            }
        } catch (Exception ex) {
            return Health.down(ex)
                .withDetail("database", "PostgreSQL")
                .build();
        }
        return Health.down().withDetail("database", "connection invalid").build();
    }
}
```

```java
@Component
public class ExternalApiHealthIndicator implements HealthIndicator {

    private final RestClient restClient;

    public ExternalApiHealthIndicator(RestClient restClient) {
        this.restClient = restClient;
    }

    @Override
    public Health health() {
        try {
            restClient.get()
                .uri("/health")
                .retrieve()
                .toBodilessEntity();
            return Health.up().withDetail("externalApi", "reachable").build();
        } catch (Exception ex) {
            return Health.down(ex).withDetail("externalApi", "unreachable").build();
        }
    }
}
```

---

## Custom Metrics with Micrometer

Use `MeterRegistry` to record application-specific metrics:

```java
@Slf4j
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final MeterRegistry meterRegistry;

    public OrderResponse createOrder(CreateOrderRequest request) {
        var order = // ... create order
        meterRegistry.counter("orders.created", "type", request.type()).increment();
        return toResponse(order);
    }
}
```

Common metric types:
```java
// Counter — things that only go up
meterRegistry.counter("orders.created").increment();

// Gauge — current value that can go up or down
Gauge.builder("orders.pending", orderRepository, repo -> repo.countByStatus("PENDING"))
    .register(meterRegistry);

// Timer — measure durations
Timer.builder("orders.processing.time")
    .register(meterRegistry)
    .record(() -> processOrder(order));
```

---

## Changing Log Levels at Runtime

Actuator's `/loggers` endpoint allows changing log levels without restart:

```bash
# View current level
curl http://localhost:8080/actuator/loggers/com.example.appname

# Change level to DEBUG
curl -X POST http://localhost:8080/actuator/loggers/com.example.appname \
  -H "Content-Type: application/json" \
  -d '{"configuredLevel": "DEBUG"}'
```

---

## Security

Lock down actuator endpoints in `SecurityConfig` (see [security.md](security.md) for full security setup):

```java
.authorizeHttpRequests(auth -> auth
    .requestMatchers("/actuator/health", "/actuator/info").permitAll()
    .requestMatchers("/actuator/**").hasRole("ADMIN")
    // ...
)
```

---

## Rules

1. **Always include `spring-boot-starter-actuator`** in every project.
2. **Expose only what you need** — don't use `management.endpoints.web.exposure.include=*` in production.
3. **Use `when-authorized` for sensitive endpoints** — `health.show-details`, `env.show-values`.
4. **Write custom health indicators** for every external dependency — databases, APIs, message brokers.
5. **Add application-level metrics** for key business events — orders created, payments processed, etc.
6. **Secure actuator endpoints** — health and info can be public, everything else behind auth.
7. **Use `/actuator/loggers` for runtime debugging** — change log levels without redeploying.
8. **Include `/actuator/health` in load balancer checks** — it's the standard readiness probe.

````
