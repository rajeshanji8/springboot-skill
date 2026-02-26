# Dependencies

Canonical `pom.xml` dependency list for Spring Boot 3.x projects using this skill. Copy the full template or pick only the modules you need.

---

## TLDR — Mandatory Rules
- Use Spring Boot BOM versions — only pin third-party libs (MapStruct, SpringDoc, Logstash Encoder)
- Lombok: `<optional>true</optional>`, JDBC drivers: `<scope>runtime</scope>`, test deps: `<scope>test</scope>`
- Annotation processor order: Lombok → lombok-mapstruct-binding → MapStruct
- No snapshot versions on main branch
- Add dependencies only when needed — don't blindly copy the full template

---

## Parent POM

```xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.4.1</version>   <!-- pin to latest stable -->
    <relativePath/>
</parent>
```

## Java Version

```xml
<properties>
    <java.version>21</java.version>
    <mapstruct.version>1.6.3</mapstruct.version>
    <springdoc.version>2.7.0</springdoc.version>
    <logstash-logback.version>8.0</logstash-logback.version>
</properties>
```

---

## Core Starters

```xml
<!-- Web (embedded Tomcat, Jackson, validation) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>

<!-- Bean Validation (Jakarta Validation + Hibernate Validator) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-validation</artifactId>
</dependency>

<!-- Actuator (health, info, metrics, Prometheus) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

---

## Data & Database

See [database-jpa.md](database-jpa.md) for JPA conventions and [database-jpa.md → Liquibase](database-jpa.md) for migration guidance.

```xml
<!-- Spring Data JPA -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>

<!-- Liquibase (database migrations) -->
<dependency>
    <groupId>org.liquibase</groupId>
    <artifactId>liquibase-core</artifactId>
</dependency>

<!-- PostgreSQL (production) -->
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
    <scope>runtime</scope>
</dependency>

<!-- H2 (local development / testing only) -->
<dependency>
    <groupId>com.h2database</groupId>
    <artifactId>h2</artifactId>
    <scope>runtime</scope>
</dependency>
```

---

## Security

See [security.md](security.md) for configuration patterns.

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>

<!-- JWT support (if using token-based auth) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-oauth2-resource-server</artifactId>
</dependency>
```

---

## Caching

See [caching.md](caching.md) for Caffeine and Redis configuration.

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-cache</artifactId>
</dependency>

<!-- Caffeine (in-process cache — default choice) -->
<dependency>
    <groupId>com.github.ben-manes.caffeine</groupId>
    <artifactId>caffeine</artifactId>
</dependency>

<!-- Redis (distributed cache — use when scaling horizontally) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
```

---

## HTTP Client

See [http-client.md](http-client.md) for `RestClient` configuration, timeouts, and connection pooling.

```xml
<!-- Apache HttpClient 5 (connection pooling for RestClient) -->
<dependency>
    <groupId>org.apache.httpcomponents.client5</groupId>
    <artifactId>httpclient5</artifactId>
</dependency>
```

---

## API Documentation

See [api-design.md](api-design.md) for OpenAPI annotations and Swagger UI conventions.

```xml
<!-- SpringDoc OpenAPI (Swagger UI + OpenAPI 3 spec) -->
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>${springdoc.version}</version>
</dependency>
```

---

## Async & Scheduling

See [async-scheduling.md](async-scheduling.md) for `@Async` and `@Scheduled` conventions.

No additional dependencies — `@EnableAsync` and `@EnableScheduling` are part of `spring-boot-starter`.

---

## Logging

See [logging.md](logging.md) for structured JSON logging and MDC patterns.

```xml
<!-- Logstash Logback Encoder (structured JSON logs) -->
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>${logstash-logback.version}</version>
</dependency>
```

---

## Code Generation (Lombok + MapStruct)

See [coding-conventions.md](coding-conventions.md) and [mapper-conventions.md](mapper-conventions.md).

```xml
<!-- Lombok -->
<dependency>
    <groupId>org.projectlombok</groupId>
    <artifactId>lombok</artifactId>
    <optional>true</optional>
</dependency>

<!-- MapStruct -->
<dependency>
    <groupId>org.mapstruct</groupId>
    <artifactId>mapstruct</artifactId>
    <version>${mapstruct.version}</version>
</dependency>
```

### Compiler Plugin (Lombok + MapStruct annotation processing)

```xml
<build>
    <plugins>
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-compiler-plugin</artifactId>
            <configuration>
                <annotationProcessorPaths>
                    <path>
                        <groupId>org.projectlombok</groupId>
                        <artifactId>lombok</artifactId>
                    </path>
                    <path>
                        <groupId>org.projectlombok</groupId>
                        <artifactId>lombok-mapstruct-binding</artifactId>
                        <version>0.2.0</version>
                    </path>
                    <path>
                        <groupId>org.mapstruct</groupId>
                        <artifactId>mapstruct-processor</artifactId>
                        <version>${mapstruct.version}</version>
                    </path>
                </annotationProcessorPaths>
            </configuration>
        </plugin>
    </plugins>
</build>
```

---

## Testing

See [testing.md](testing.md) for test conventions.

```xml
<!-- Spring Boot Test (JUnit 5, Mockito, MockMvc, AssertJ) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>

<!-- Spring Security Test (if using spring-boot-starter-security) -->
<dependency>
    <groupId>org.springframework.security</groupId>
    <artifactId>spring-security-test</artifactId>
    <scope>test</scope>
</dependency>

<!-- Testcontainers (integration tests with real database) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-testcontainers</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>junit-jupiter</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>postgresql</artifactId>
    <scope>test</scope>
</dependency>
```

---

## Docker

See [docker.md](docker.md) for multi-stage Dockerfile and Compose patterns.

```xml
<!-- Spring Boot Maven plugin (layered JAR for Docker) -->
<build>
    <plugins>
        <plugin>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-maven-plugin</artifactId>
            <configuration>
                <excludes>
                    <exclude>
                        <groupId>org.projectlombok</groupId>
                        <artifactId>lombok</artifactId>
                    </exclude>
                </excludes>
                <layers>
                    <enabled>true</enabled>
                </layers>
            </configuration>
        </plugin>
    </plugins>
</build>
```

---

## Rules

1. **Use Spring Boot BOM versions** — never pin versions for dependencies managed by `spring-boot-starter-parent`. Only pin versions for third-party libs like MapStruct, SpringDoc, and Logstash Logback Encoder.
2. **Keep the `<properties>` block** as the single place for third-party version numbers. Never scatter version strings across `<dependency>` blocks.
3. **`<scope>runtime</scope>`** for JDBC drivers — application code must never depend on driver classes directly.
4. **`<scope>test</scope>`** for all test-only dependencies — Spring Boot Test, Testcontainers, Security Test, H2 (when used only in tests).
5. **`<optional>true</optional>`** for Lombok — it is a compile-time-only tool and must not leak into transitive dependencies.
6. **Annotation processor order matters** — Lombok must come before MapStruct in `annotationProcessorPaths`, with `lombok-mapstruct-binding` in between.
7. **Add dependencies only when needed** — do not copy the entire template blindly. Each module should pull in only what it uses.
8. **Prefer starters over individual artifacts** — use `spring-boot-starter-data-jpa` instead of adding `spring-data-jpa` + `hibernate-core` separately.
9. **Update versions together** — when upgrading Spring Boot parent version, review all third-party version pins for compatibility.
10. **No snapshot versions in main branch** — only stable, released versions in production code.
