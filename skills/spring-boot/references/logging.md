# Logging

Use **Logback** (Spring Boot's default) with a custom `logback-spring.xml` for full control over console and file logging.

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

## Rules

1. **Every project must have `logback-spring.xml`** — never rely on Spring Boot's default console-only output.
2. **Three appenders always**: CONSOLE + FILE (all levels) + ERROR_FILE (errors only).
3. **Use parameterized logging** — never string concatenation: `log.info("id={}", id)` not `log.info("id=" + id)`.
4. **Log levels are set in `application.properties`** — users can toggle to DEBUG without touching logback XML.
5. **File logs rotate daily** with 50MB max per file, 30-day retention, 1GB total cap.
6. **Add `logs/` to `.gitignore`** — never commit log files.
7. **Log level guidance**:
   - `ERROR` — something broke, needs attention
   - `WARN` — unexpected but recoverable
   - `INFO` — key business events (user created, order placed, etc.)
   - `DEBUG` — detailed flow for troubleshooting (off in production by default)
   - `TRACE` — very verbose, only for specific libraries like Hibernate bind parameters
