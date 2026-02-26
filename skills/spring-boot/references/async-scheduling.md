# Async & Scheduling

Follow these conventions for asynchronous execution and scheduled tasks in Spring Boot.

---

## TLDR — Mandatory Rules
- Always define a custom `TaskExecutor` bean — never rely on Spring's default single-thread executor
- `@Async` only works on public methods called from another bean — same-class calls bypass the proxy
- Handle async exceptions via `AsyncUncaughtExceptionHandler` — failures must not vanish silently
- Scheduled tasks must be idempotent — use ShedLock for distributed locking
- Externalize cron expressions into `application.properties` — never hardcode schedules

---

## Enable Async and Scheduling

Add both to a configuration class in `config/`:

```java
@Configuration
@EnableAsync
@EnableScheduling
public class AsyncConfig {

    @Bean
    public TaskExecutor taskExecutor() {
        var executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);
        executor.setMaxPoolSize(10);
        executor.setQueueCapacity(25);
        executor.setThreadNamePrefix("async-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.initialize();
        return executor;
    }
}
```

<!-- CUSTOMIZE: Adjust pool sizes based on your workload and hardware -->

---

## @Async Methods

Use `@Async` on service methods that can run in the background:

```java
@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final EmailClient emailClient;

    @Async
    public CompletableFuture<Void> sendWelcomeEmail(String email, String name) {
        log.info("Sending welcome email to {}", email);
        emailClient.send(email, "Welcome " + name, "...");
        return CompletableFuture.completedFuture(null);
    }

    @Async
    public void sendOrderConfirmation(Long orderId) {
        log.info("Sending order confirmation for orderId={}", orderId);
        // Fire-and-forget — no return value needed
    }
}
```

### Async Exception Handling

Configure a global handler for uncaught async exceptions:

```java
@Configuration
public class AsyncExceptionConfig implements AsyncConfigurer {

    @Override
    public AsyncUncaughtExceptionHandler getAsyncUncaughtExceptionHandler() {
        // LoggerFactory used here because @Slf4j is not available in a lambda/interface impl
        return (ex, method, params) -> {
            LoggerFactory.getLogger(method.getDeclaringClass())
                .error("Async error in {}: {}", method.getName(), ex.getMessage(), ex);
        };
    }
}
```

---

## @Scheduled Tasks

Use `@Scheduled` for recurring tasks. Place scheduled methods in dedicated `@Component` classes:

```java
@Slf4j
@Component
@RequiredArgsConstructor
public class CleanupTask {

    private final ExpiredTokenRepository tokenRepository;

    @Scheduled(cron = "0 0 2 * * *")  // Every day at 2:00 AM
    public void purgeExpiredTokens() {
        log.info("Running expired token cleanup");
        int count = tokenRepository.deleteExpiredBefore(Instant.now());
        log.info("Purged {} expired tokens", count);
    }
}

@Slf4j
@Component
public class HealthCheckTask {

    @Scheduled(fixedRate = 60_000)  // Every 60 seconds
    public void checkExternalServices() {
        log.debug("Checking external service health");
        // ...
    }
}
```

### Schedule Expressions

| Expression | Meaning |
|-----------|---------|
| `@Scheduled(fixedRate = 5000)` | Run every 5 seconds (from start of previous) |
| `@Scheduled(fixedDelay = 5000)` | Run 5 seconds after previous completes |
| `@Scheduled(cron = "0 0 * * * *")` | Run every hour |
| `@Scheduled(cron = "0 0 2 * * *")` | Run daily at 2:00 AM |
| `@Scheduled(cron = "0 */15 * * * *")` | Run every 15 minutes |

### Externalize Cron Expressions

Keep schedules configurable via `application.properties`:

```java
@Scheduled(cron = "${app.cleanup.cron:0 0 2 * * *}")
public void purgeExpiredTokens() { ... }
```

```properties
app.cleanup.cron=0 0 2 * * *
```

---

## Rules

1. **Always define a custom `TaskExecutor` bean** — never rely on Spring's default single-thread executor.
2. **`@Async` only works on public methods** called from another bean — calling an async method within the same class bypasses the proxy.
3. **Return `CompletableFuture<T>`** when the caller needs the result; return `void` for fire-and-forget.
4. **Handle async exceptions** — configure `AsyncUncaughtExceptionHandler` so failures don't silently disappear.
5. **Scheduled tasks must be idempotent** — if the app runs multiple instances, use distributed locks (e.g., ShedLock) to prevent duplicate execution.
6. **Keep scheduled tasks fast** — if the task is heavy, have it enqueue work for async processing.
7. **Externalize cron expressions** into `application.properties` — don't hardcode schedules.
8. **Log start and completion** of every scheduled task with relevant counts/metrics.
9. **Put scheduled tasks in their own classes** — don't mix them into service classes.
