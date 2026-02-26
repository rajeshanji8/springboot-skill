# Logging

Use **Logback** (Spring Boot's default) with a custom `logback-spring.xml` for full control over console and file logging.

---

## TLDR — Mandatory Rules
- Always use `@Slf4j` — never `LoggerFactory.getLogger(...)` manually (exception: `AsyncUncaughtExceptionHandler` where `@Slf4j` is unavailable)
- Every project must have `logback-spring.xml` with 3 appenders: CONSOLE + FILE + ERROR_FILE
- Parameterized logging: `log.info("id={}", id)` — never string concatenation
- Never log and throw — either log or throw, not both
- Never use `System.out.println()` or `e.printStackTrace()` — always use the SLF4J logger
- Every ERROR must include the exception object: `log.error("msg", ex)`
- Add MDC request correlation (requestId, userId) in a servlet filter for all log entries

---

## Setup

1. **Always use Lombok's `@Slf4j`** — this is the only way to get a logger. Never use `LoggerFactory.getLogger(...)` manually.
2. **Place `logback-spring.xml`** in `src/main/resources/` — Spring Boot picks it up automatically.
3. **Control log levels** via `application.properties` — the logback file defines appenders and patterns, properties control levels.

---

## logback-spring.xml

Always include this file in every project:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>

    <!-- ===== Properties (overridable via application.properties) ===== -->
    <springProperty scope="context" name="APP_NAME" source="spring.application.name" defaultValue="app"/>
    <springProperty scope="context" name="LOG_DIR" source="logging.file.path" defaultValue="logs"/>
    <springProperty scope="context" name="LOG_FILE" source="logging.file.name" defaultValue="${LOG_DIR}/${APP_NAME}.log"/>

    <!-- ===== Console Appender ===== -->
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>

    <!-- ===== File Appender (rolling daily, 30 days retention) ===== -->
    <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>${LOG_FILE}</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
            <fileNamePattern>${LOG_DIR}/${APP_NAME}.%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
            <maxFileSize>50MB</maxFileSize>
            <maxHistory>30</maxHistory>
            <totalSizeCap>1GB</totalSizeCap>
        </rollingPolicy>
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>

    <!-- ===== Error-only File Appender ===== -->
    <appender name="ERROR_FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>${LOG_DIR}/${APP_NAME}-error.log</file>
        <filter class="ch.qos.logback.classic.filter.ThresholdFilter">
            <level>ERROR</level>
        </filter>
        <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
            <fileNamePattern>${LOG_DIR}/${APP_NAME}-error.%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
            <maxFileSize>50MB</maxFileSize>
            <maxHistory>30</maxHistory>
            <totalSizeCap>500MB</totalSizeCap>
        </rollingPolicy>
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>

    <!-- ===== Root Logger ===== -->
    <root level="INFO">
        <appender-ref ref="CONSOLE"/>
        <appender-ref ref="FILE"/>
        <appender-ref ref="ERROR_FILE"/>
    </root>

</configuration>
```

---

## application.properties — Logging Section

Control all log levels from `application.properties`. The logback file handles appenders and rotation; properties handle levels.

```properties
# ===== Application =====
spring.application.name=appname

# ===== Logging File Config =====
logging.file.path=logs
logging.file.name=logs/appname.log

# ===== Log Levels =====
logging.level.root=INFO
logging.level.com.example.appname=INFO
logging.level.org.springframework.web=INFO
logging.level.org.springframework.security=INFO
logging.level.org.hibernate.SQL=INFO
logging.level.org.hibernate.orm.jdbc.bind=INFO

# Change to DEBUG for troubleshooting (uncomment as needed):
# logging.level.com.example.appname=DEBUG
# logging.level.org.springframework.web=DEBUG
# logging.level.org.springframework.security=DEBUG
# logging.level.org.hibernate.SQL=DEBUG
# logging.level.org.hibernate.orm.jdbc.bind=TRACE
```

---

## Usage in Code

Always use `@Slf4j` from Lombok:

```java
@Slf4j
@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;

    public UserResponse findById(Long id) {
        log.debug("Looking up user with id={}", id);
        var user = userRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("User", id));
        log.info("Found user with id={}", id);
        return userMapper.toResponse(user); // see mapper-conventions.md
    }
}
```

---

## Logging Level Policy

Teams abuse logging when there's no clear policy. Follow these definitions strictly:

| Level | When to Use | Example |
|-------|------------|---------|
| `ERROR` | **Unexpected failure** — something broke that shouldn't have. Requires investigation. | `log.error("Payment processing failed for orderId={}", orderId, ex)` |
| `WARN` | **Recoverable issue** — something unexpected happened but the system handled it. | `log.warn("Retry attempt {} for external API call", retryCount)` |
| `INFO` | **Business milestones** — key events that matter to operations. | `log.info("User created id={}", user.getId())` |
| `DEBUG` | **Diagnostic detail** — flow tracing, variable values, branch decisions. Off in production. | `log.debug("Fetching user with id={}", id)` |
| `TRACE` | **Very verbose** — only for specific libraries (Hibernate binds, HTTP wire logs). Never in app code. | Configured per-library, not used in your code. |

**Rules for log levels:**
- **`INFO` is the production level** — `INFO` logs should tell the story of what the application is doing. If you read only `INFO` logs, you should understand every significant business event.
- **`DEBUG` is off in production** — use it freely for diagnostic detail, but never log sensitive data at any level.
- **`ERROR` means someone should look at it** — don't log expected business conditions (validation failures, not-found) as `ERROR`. Those are `WARN` or `INFO`.
- **Every `ERROR` must include the exception** — `log.error("msg", ex)` never `log.error("msg: " + ex.getMessage())`.
- **Never log and throw** — either log the error or throw an exception, not both. The global exception handler logs thrown exceptions.
  ```java
  // ❌ NEVER — duplicates the log entry
  catch (Exception ex) {
      log.error("Failed to process", ex);
      throw new ServiceException("Failed to process", ex);
  }

  // ✅ Just throw — let the exception handler log it
  catch (Exception ex) {
      throw new ServiceException("Failed to process", ex);
  }
  ```

---

## Rules

1. **Every project must have `logback-spring.xml`** — never rely on Spring Boot's default console-only output.
2. **Three appenders always**: CONSOLE + FILE (all levels) + ERROR_FILE (errors only).
3. **Use parameterized logging** — never string concatenation: `log.info("id={}", id)` not `log.info("id=" + id)`.
4. **Log levels are set in `application.properties`** — users can toggle to DEBUG without touching logback XML.
5. **File logs rotate daily** with 50MB max per file, 30-day retention, 1GB total cap.
6. **Add `logs/` to `.gitignore`** — never commit log files.
7. **Follow the logging level policy** — see the table above. `INFO` for business milestones, `ERROR` for unexpected failures. Don't abuse levels.

---

## Structured / JSON Logging

**For production log aggregation (ELK, Loki, Datadog, Splunk), use JSON-format logs** so they can be parsed automatically. Keep console logging human-readable for local development.

### Dependencies

Add Logback's JSON encoder:
```xml
<dependency>
    <groupId>ch.qos.logback.contrib</groupId>
    <artifactId>logback-json-classic</artifactId>
    <version>0.1.5</version>
</dependency>
<dependency>
    <groupId>ch.qos.logback.contrib</groupId>
    <artifactId>logback-jackson</artifactId>
    <version>0.1.5</version>
</dependency>
```

Or use **Logstash Logback Encoder** (preferred — more features):
```xml
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>8.0</version>
</dependency>
```

<!-- CUSTOMIZE: Update version to latest stable release -->

### logback-spring.xml with JSON for Production

Use logback-spring.xml `<springProfile>` tags to switch between human-readable (local) and JSON (production). Note: this uses Spring's logback integration — NOT Spring profiles (`application-{profile}.properties`), which are banned. The single `application.properties` controls the active profile via `${SPRING_PROFILES_ACTIVE:local}`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>

    <springProperty scope="context" name="APP_NAME" source="spring.application.name" defaultValue="app"/>
    <springProperty scope="context" name="LOG_DIR" source="logging.file.path" defaultValue="logs"/>

    <!-- ===== Console Appender (human-readable, always active) ===== -->
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} [%X{traceId:-}] - %msg%n</pattern>
        </encoder>
    </appender>

    <!-- ===== JSON File Appender (for production log aggregation) ===== -->
    <appender name="JSON_FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>${LOG_DIR}/${APP_NAME}.json.log</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
            <fileNamePattern>${LOG_DIR}/${APP_NAME}.%d{yyyy-MM-dd}.%i.json.log.gz</fileNamePattern>
            <maxFileSize>50MB</maxFileSize>
            <maxHistory>30</maxHistory>
            <totalSizeCap>1GB</totalSizeCap>
        </rollingPolicy>
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <includeMdcKeyName>traceId</includeMdcKeyName>
            <includeMdcKeyName>requestId</includeMdcKeyName>
            <includeMdcKeyName>userId</includeMdcKeyName>
        </encoder>
    </appender>

    <!-- ===== Standard File Appender (plain text) ===== -->
    <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>${LOG_DIR}/${APP_NAME}.log</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
            <fileNamePattern>${LOG_DIR}/${APP_NAME}.%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
            <maxFileSize>50MB</maxFileSize>
            <maxHistory>30</maxHistory>
            <totalSizeCap>1GB</totalSizeCap>
        </rollingPolicy>
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} [%X{traceId:-}] - %msg%n</pattern>
        </encoder>
    </appender>

    <!-- ===== Error-only File Appender ===== -->
    <appender name="ERROR_FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>${LOG_DIR}/${APP_NAME}-error.log</file>
        <filter class="ch.qos.logback.classic.filter.ThresholdFilter">
            <level>ERROR</level>
        </filter>
        <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
            <fileNamePattern>${LOG_DIR}/${APP_NAME}-error.%d{yyyy-MM-dd}.%i.log.gz</fileNamePattern>
            <maxFileSize>50MB</maxFileSize>
            <maxHistory>30</maxHistory>
            <totalSizeCap>500MB</totalSizeCap>
        </rollingPolicy>
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} [%X{traceId:-}] - %msg%n</pattern>
        </encoder>
    </appender>

    <root level="INFO">
        <appender-ref ref="CONSOLE"/>
        <appender-ref ref="FILE"/>
        <appender-ref ref="ERROR_FILE"/>
        <appender-ref ref="JSON_FILE"/>
    </root>

</configuration>
```

<!-- CUSTOMIZE: Remove JSON_FILE appender if you don't need structured logging -->

---

## MDC (Mapped Diagnostic Context)

**Use MDC to attach request-scoped context (request ID, user ID, trace ID) to every log line.** This makes it possible to filter all logs for a single request across services.

### Request Correlation Filter

Create a filter in `config/` that sets MDC values for every HTTP request:

```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class MdcFilter implements Filter {

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        try {
            var httpRequest = (HttpServletRequest) request;
            var requestId = Optional.ofNullable(httpRequest.getHeader("X-Request-Id"))
                .orElse(UUID.randomUUID().toString().substring(0, 8));
            MDC.put("requestId", requestId);
            MDC.put("method", httpRequest.getMethod());
            MDC.put("uri", httpRequest.getRequestURI());
            chain.doFilter(request, response);
        } finally {
            MDC.clear();  // always clear to prevent leaks across threads
        }
    }
}
```

### Usage

MDC values appear automatically in log output via the `%X{requestId}` pattern in logback. No changes needed in application code:

```java
log.info("User created id={}", user.getId());
// Output: 2025-01-15 10:30:45.123 [http-nio-8080-exec-1] INFO  UserService [abc12345] - User created id=42
```

JSON output includes MDC fields automatically:
```json
{
  "timestamp": "2025-01-15T10:30:45.123Z",
  "level": "INFO",
  "logger": "com.example.app.service.UserService",
  "message": "User created id=42",
  "requestId": "abc12345",
  "method": "POST",
  "uri": "/api/v1/users"
}
```

### MDC Rules

1. **Always clear MDC in a `finally` block** — prevents context leaking to other requests in the thread pool.
2. **Propagate MDC to `@Async` threads** — Spring's default `TaskExecutor` doesn't copy MDC. Use a decorator:
   ```java
   @Bean
   public TaskExecutor taskExecutor() {
       var executor = new ThreadPoolTaskExecutor();
       executor.setTaskDecorator(runnable -> {
           var context = MDC.getCopyOfContextMap();
           return () -> {
               try {
                   if (context != null) MDC.setContextMap(context);
                   runnable.run();
               } finally {
                   MDC.clear();
               }
           };
       });
       executor.initialize();
       return executor;
   }
   ```
3. **Standard MDC keys**: `requestId`, `traceId`, `userId`. Keep them consistent across all services.
