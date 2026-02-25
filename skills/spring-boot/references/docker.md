# Docker

Follow these conventions for containerizing Spring Boot applications and running local development dependencies.

---

## Dockerfile

Use a **multi-stage build** to keep the final image small:

```dockerfile
# ===== Stage 1: Build =====
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
RUN chmod +x mvnw && ./mvnw dependency:resolve -B
COPY src src
RUN ./mvnw package -DskipTests -B

# ===== Stage 2: Runtime =====
FROM eclipse-temurin:21-jre
WORKDIR /app

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

COPY --from=build /app/target/*.jar app.jar
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

# Default JVM options — override at runtime via JAVA_OPTS env var
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0 -XX:+UseG1GC -XX:+UseContainerSupport"

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Shell form required so $JAVA_OPTS is expanded at runtime
ENTRYPOINT java $JAVA_OPTS -jar app.jar
```

<!-- CUSTOMIZE: Change Java version and base image to match your project -->

### .dockerignore

Always include a `.dockerignore` to keep the build context small:

```
target/
.git/
.idea/
.vscode/
*.iml
logs/
.env
docker-compose*.yml
README.md
```

---

## Docker Compose for Local Development

Use `docker-compose.yml` at the project root for local infrastructure (database, cache, etc.):

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: app-postgres
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    container_name: app-redis
    ports:
      - "6379:6379"

volumes:
  postgres-data:
```

<!-- CUSTOMIZE: Add/remove services based on your project's infrastructure needs -->

Matching `application.properties`:
```properties
spring.datasource.url=${DATABASE_URL:jdbc:postgresql://localhost:5432/mydb}
spring.datasource.username=${DATABASE_USERNAME:postgres}
spring.datasource.password=${DATABASE_PASSWORD:postgres}
```

---

## Spring Boot Docker Support

Spring Boot can build OCI images without a Dockerfile using **Cloud Native Buildpacks**:

```bash
# Build image using Spring Boot Maven plugin
./mvnw spring-boot:build-image -Dspring-boot.build-image.imageName=myapp:latest
```

This produces an optimized, layered image. Use this approach when you don't need a custom Dockerfile.

---

## JVM Memory Configuration for Containers

**Never set fixed `-Xmx` / `-Xms` values in containers** — use percentage-based flags so the JVM adapts to the container's memory limit.

### JAVA_OPTS Environment Variable

Define sensible defaults in the Dockerfile via `ENV JAVA_OPTS`, then override at runtime without rebuilding:

```dockerfile
# Defaults baked into image
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0 -XX:+UseG1GC -XX:+UseContainerSupport"

# Shell form — $JAVA_OPTS is expanded at runtime
ENTRYPOINT java $JAVA_OPTS -jar app.jar
```

**Why shell form instead of exec form?** The exec form (`["java", ...]`) does not expand environment variables. Shell form (`java $JAVA_OPTS -jar app.jar`) lets `$JAVA_OPTS` resolve at container start, so you can override it in Docker Compose, Kubernetes, or `docker run`.

Override at runtime:
```bash
# docker run
docker run -e JAVA_OPTS="-XX:MaxRAMPercentage=80.0 -XX:+UseZGC -XX:+UseContainerSupport" myapp:latest
```

```yaml
# docker-compose.yml
services:
  app:
    environment:
      JAVA_OPTS: "-XX:MaxRAMPercentage=80.0 -XX:+UseZGC -XX:+UseContainerSupport -Dspring.profiles.active=staging"
```

```yaml
# Kubernetes deployment
containers:
  - name: myapp
    env:
      - name: JAVA_OPTS
        value: "-XX:MaxRAMPercentage=80.0 -XX:+UseZGC -XX:+UseContainerSupport"
```

**Alternative: `JAVA_TOOL_OPTIONS`** — This is a JVM-native env var that the JVM reads automatically (no shell expansion needed). Use it when you can't control the ENTRYPOINT:
```bash
docker run -e JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=80.0" myapp:latest
```
The JVM prints `Picked up JAVA_TOOL_OPTIONS: ...` to stderr when it detects this. Prefer `JAVA_OPTS` with shell form for cleaner control; use `JAVA_TOOL_OPTIONS` as a fallback.

### JVM Flag Reference

| Flag | Purpose |
|------|---------|
| `-XX:MaxRAMPercentage=75.0` | Use 75% of container memory as max heap (leave room for metaspace, threads, OS) |
| `-XX:InitialRAMPercentage=50.0` | Start with 50% of container memory as initial heap |
| `-XX:+UseG1GC` | G1 garbage collector — best general-purpose GC for most workloads |
| `-XX:+UseContainerSupport` | JVM respects container memory/CPU limits (default on Java 11+, explicit for clarity) |

<!-- CUSTOMIZE: Use -XX:+UseZGC for low-latency workloads (Java 21+), or -XX:+UseShenandoahGC for sub-millisecond pauses -->

For production, set memory limits on the container (not the JVM):
```yaml
services:
  app:
    deploy:
      resources:
        limits:
          memory: 1024M
          cpus: '2.0'
```

The JVM will automatically compute its heap from the container's memory limit.

---

## Multi-Architecture Builds

Build images for both **AMD64** (x86) and **ARM64** (Apple Silicon, AWS Graviton) using Docker Buildx:

```bash
# Create a multi-arch builder (one-time setup)
docker buildx create --name multiarch --use

# Build and push multi-arch image
docker buildx build --platform linux/amd64,linux/arm64 \
  -t myregistry/myapp:latest --push .
```

Ensure the base image supports both platforms — **Eclipse Temurin** images are multi-arch by default.

For CI/CD pipelines (GitHub Actions example):
```yaml
- name: Build and push multi-arch image
  uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64
    push: true
    tags: myregistry/myapp:${{ github.sha }}
```

---

## Running the Application with Docker Compose

Add the app itself to Compose for full-stack local testing:

```yaml
services:
  app:
    build: .
    container_name: app
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: jdbc:postgresql://postgres:5432/mydb
      DATABASE_USERNAME: postgres
      DATABASE_PASSWORD: postgres
      SPRING_PROFILES_ACTIVE: ""
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1024M
          cpus: '2.0'
        reservations:
          memory: 512M
          cpus: '0.5'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 5s
      start_period: 30s
      retries: 3

  postgres:
    image: postgres:16-alpine
    container_name: app-postgres
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres-data:
```

---

## Rules

1. **Always use multi-stage builds** — build in a JDK image, run in a JRE image.
2. **Use Eclipse Temurin** as the base image — it's the standard OpenJDK distribution.
3. **Copy dependencies first, source code second** — this maximizes Docker layer caching.
4. **Never put secrets in the Dockerfile or docker-compose.yml** — use environment variables or `.env` files (add `.env` to `.gitignore`). See [configuration-properties.md](configuration-properties.md) for environment variable placeholders.
5. **Always include `.dockerignore`** — keep build context small and avoid leaking sensitive files.
6. **Use `docker-compose.yml` for local dev dependencies** — database, cache, message broker, etc.
7. **Pin image versions** — `postgres:16-alpine` not `postgres:latest`.
8. **Expose only the application port (8080)** — don't expose debug ports in production.
9. **Add `docker-compose*.yml` and `Dockerfile` to version control** — these are part of the project.
10. **Always run as a non-root user** — add `USER` instruction in the Dockerfile. Never run containers as root in production.
11. **Always include a `HEALTHCHECK`** — Docker and orchestrators use it to detect unhealthy containers.
12. **Use percentage-based JVM memory flags** — never hardcode `-Xmx`. Use `-XX:MaxRAMPercentage=75.0` and set memory limits on the container.
13. **Always use `JAVA_OPTS` env var for JVM flags** — define defaults in `ENV JAVA_OPTS` and use shell form `ENTRYPOINT java $JAVA_OPTS -jar app.jar` so flags can be overridden at deploy time without rebuilding the image.
14. **Set resource limits on every container** — `memory` and `cpus` in `deploy.resources.limits` to prevent runaway containers.
15. **Build multi-arch images** for ARM64 + AMD64 — required for mixed infrastructure (Apple Silicon devs, AWS Graviton, etc.).
16. **Use health-based `depends_on`** — `depends_on: { service: condition: service_healthy }` instead of bare `depends_on` to ensure dependencies are ready.
