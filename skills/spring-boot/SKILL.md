---
name: spring-boot-skill
description: Build Spring Boot 3.x applications following best practices. Use when developing or modifying Spring Boot apps that use Spring MVC, Spring Data JPA, Spring Security, or Spring Boot testing, including package structure, coding conventions, Java standards, REST APIs, entities/repositories, service layer, error handling, testing, mapping, caching, async/scheduling, configuration, logging, HTTP clients, security, Docker, dev scripts, and actuator/health.
---

# Spring Boot Skill

Apply the practices below when developing Spring Boot applications. Read the linked reference only when working on that area.

## Project Structure

Read [references/project-structure.md](references/project-structure.md) for package layout, module organization, and resource structure.

## Coding Conventions

Read [references/coding-conventions.md](references/coding-conventions.md) for naming standards, Java/Spring idioms, formatting, and logging guidelines.

## Java Standards

Follow [references/java-standards.md](references/java-standards.md) for string comparisons, Javadoc requirements, stream comments, imports, null handling, and other low-level Java conventions.

## Logging

Configure logging using [references/logging.md](references/logging.md) for Logback setup, `logback-spring.xml`, console + file appenders, and log level management via `application.properties`.

## REST API Design

Implement REST APIs using [references/api-design.md](references/api-design.md) for URL conventions, DTOs, validation, pagination, and response codes.

## Spring Data JPA

Implement the repository and entity layer using [references/database-jpa.md](references/database-jpa.md) for entity design, relationships, repositories, migrations, and transactions.

## Error Handling

Implement consistent error responses using [references/error-handling.md](references/error-handling.md) for global exception handling, Problem Details (RFC 9457), and custom exceptions.

## Testing

Test Spring Boot applications using [references/testing.md](references/testing.md) for unit tests, controller slice tests, repository tests, and integration tests.

## Mapper Conventions

Map entities to DTOs using [references/mapper-conventions.md](references/mapper-conventions.md) for MapStruct setup, manual mapping fallback, and service-layer mapping patterns.

## Configuration Properties

Externalize configuration using [references/configuration-properties.md](references/configuration-properties.md) for `@ConfigurationProperties`, environment variable placeholders, and validation.

## Caching

Add caching using [references/caching.md](references/caching.md) for `@Cacheable`, `@CacheEvict`, Caffeine and Redis configuration.

## Async & Scheduling

Run background work using [references/async-scheduling.md](references/async-scheduling.md) for `@Async`, `@Scheduled`, thread pool config, and cron expressions.

## Security

Secure the application using [references/security.md](references/security.md) for authentication, CORS, and secrets management.

## HTTP Client

Make outbound HTTP calls using [references/http-client.md](references/http-client.md) for RestClient configuration, timeouts, connection pooling, error handling, and WebClient for reactive needs.

## Actuator & Health

Monitor the application using [references/actuator-health.md](references/actuator-health.md) for health indicators, custom metrics, Micrometer, and runtime log level changes.

## Docker

Containerize the application using [references/docker.md](references/docker.md) for multi-stage Dockerfiles, Docker Compose for local dev, and Spring Boot build-image.

## Dev Scripts

Every project must include a `start.sh` — see [references/dev-scripts.md](references/dev-scripts.md) for the build-and-run script that handles Maven build, Docker/local startup, health check, and prints Swagger URL.

## Dependencies

Set up the Maven `pom.xml` using [references/dependencies.md](references/dependencies.md) for the canonical dependency list, BOM versioning rules, annotation processor configuration, and scope conventions.
