````markdown
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
COPY --from=build /app/target/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
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
      - postgres
    restart: unless-stopped

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

````
