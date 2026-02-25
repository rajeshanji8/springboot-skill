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

## Kubernetes / Container Probes

Spring Boot Actuator has built-in support for **Kubernetes liveness and readiness probes**. These work in any container orchestrator (Kubernetes, ECS, Docker Swarm), not just Kubernetes.

### Enable Probe Endpoints

Add to `application.properties`:

```properties
# ===== Kubernetes Probes =====
management.endpoint.health.probes.enabled=true
management.health.livenessstate.enabled=true
management.health.readinessstate.enabled=true
```

This exposes two additional health groups:

| Endpoint | Purpose | When it reports DOWN |
|----------|---------|---------------------|
| `/actuator/health/liveness` | Is the app alive? | App is in a broken state and must be restarted |
| `/actuator/health/readiness` | Can the app accept traffic? | App is not ready (still starting, DB unavailable, etc.) |

### How Liveness vs. Readiness Work

- **Liveness** — If this fails, the orchestrator **kills and restarts** the container. Only report DOWN for unrecoverable states (deadlocked threads, corrupted state). Never include external dependency checks in liveness — a database outage should not trigger a restart loop.
- **Readiness** — If this fails, the orchestrator **stops routing traffic** to the container but does not restart it. Include external dependency checks here — database, cache, message broker availability.

### Assigning Health Indicators to Probe Groups

By default, Spring Boot assigns built-in indicators to the correct groups. For custom indicators, assign them explicitly in `application.properties`:

```properties
# Include database and Redis checks in readiness (traffic routing)
management.endpoint.health.group.readiness.include=readinessState,db,redis

# Liveness should only check internal state (keep it minimal)
management.endpoint.health.group.liveness.include=livenessState
```

### Kubernetes Deployment Configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
        - name: myapp
          image: myregistry/myapp:latest
          ports:
            - containerPort: 8080
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 3
          startupProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 30
          resources:
            requests:
              memory: "512Mi"
              cpu: "500m"
            limits:
              memory: "1024Mi"
              cpu: "2000m"
```

### Docker Compose Equivalent

For non-Kubernetes environments, use Docker `healthcheck`:

```yaml
services:
  app:
    image: myapp:latest
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health/readiness"]
      interval: 10s
      timeout: 5s
      start_period: 30s
      retries: 3
```

### Graceful Shutdown

Enable graceful shutdown so in-flight requests complete before the container stops:

```properties
# ===== Graceful Shutdown =====
server.shutdown=graceful
spring.lifecycle.timeout-per-shutdown-phase=30s
```

When a `SIGTERM` is received (e.g., during a rolling deployment):
1. The readiness probe immediately reports DOWN — the load balancer stops sending new requests.
2. In-flight requests are allowed to complete within the configured timeout (30s).
3. The application shuts down cleanly.

**Always pair graceful shutdown with readiness probes** — without readiness, the load balancer may send new requests to a container that's shutting down.

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
9. **Always enable liveness and readiness probes** — set `management.endpoint.health.probes.enabled=true` in every project.
10. **Never put external dependency checks in liveness probes** — a database outage should not trigger a restart loop. Put them in readiness only.
11. **Always enable graceful shutdown** — `server.shutdown=graceful` with a 30s timeout. Prevents dropped connections during deployments.
12. **Use startup probes for slow-starting apps** — prevents the liveness probe from killing the container before it finishes initialization.

````
