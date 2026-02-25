# Database & JPA

Follow these conventions for database access and JPA entity design in Spring Boot.

---

## Entity Design

1. **Use `@Entity`** on all persistent classes. Keep them in `model/entity/`.
2. **Use `Long` for IDs** with `@GeneratedValue(strategy = GenerationType.IDENTITY)`.
3. **Add audit fields to business entities** — `createdAt`, `updatedAt`, `createdBy`, `updatedBy`. Not every table needs auditing — lookup tables, configuration tables, and join tables typically don't. Apply audit fields to entities that represent **business objects users create or modify** (e.g., `User`, `Order`, `Invoice`), not to static reference data (e.g., `Country`, `Currency`, `Permission`).
4. **Use `@MappedSuperclass`** with `@EntityListeners(AuditingEntityListener.class)` for shared audit fields — see [JPA Auditing](#jpa-auditing) section below.
5. **Avoid Lombok `@Data`** on entities — use `@Getter`, `@Setter`, `@NoArgsConstructor` individually.
6. **Override `equals()` and `hashCode()`** based on the business key or ID (not all fields).

```java
@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false, unique = true)
    private String email;

    @CreatedDate
    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(nullable = false)
    private Instant updatedAt;
}
```

---

## Relationships

- **Default to `FetchType.LAZY`** for all associations.
- **Avoid bidirectional relationships** unless absolutely needed. Prefer owning side only.
- Use `@JoinColumn` explicitly — don't rely on defaults.
- When bidirectional is needed, manage both sides:
  ```java
  public void addOrder(Order order) {
      orders.add(order);
      order.setUser(this);
  }
  ```

---

## Repositories

- Extend **`JpaRepository<T, ID>`** for full CRUD + pagination.
- Use **derived query methods** for simple queries: `findByEmail(String email)`.
- Use **`@Query`** with JPQL for anything non-trivial.
- Prefer **projections** or **DTOs in queries** when you don't need full entities.
- For entity ↔ DTO mapping conventions, see [mapper-conventions.md](mapper-conventions.md).

```java
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);

    @Query("SELECT u FROM User u WHERE u.name LIKE %:name%")
    List<User> searchByName(@Param("name") String name);
}
```

---

## Database Migrations

- **Always use Liquibase** for all database migrations — never Flyway.
- Changelog format: use **YAML** changelogs.
- Master changelog: `src/main/resources/db/changelog/db.changelog-master.yaml`
- Individual changesets: `src/main/resources/db/changelog/changes/001-create-users-table.yaml`
- Configure in `application.properties`:
  ```properties
  spring.liquibase.change-log=classpath:db/changelog/db.changelog-master.yaml
  ```
- **Never modify existing changesets** — always add new ones.
- Use `ddl-auto=validate` in production — never `update` or `create`.
- Every changeset must have a meaningful `id` and `author`.

### Master Changelog Structure

The master changelog includes individual changeset files in order:

```yaml
# db/changelog/db.changelog-master.yaml
databaseChangeLog:
  - include:
      file: db/changelog/changes/001-create-users-table.yaml
  - include:
      file: db/changelog/changes/002-create-orders-table.yaml
  - include:
      file: db/changelog/changes/003-add-email-index.yaml
  - include:
      file: db/changelog/changes/004-add-phone-column.yaml
```

**Rules:**
- Use **sequential numbering** (`001-`, `002-`, ...) to maintain execution order.
- **One concern per changeset file** — don't mix creating a table with adding data.
- **Never reorder** includes — Liquibase tracks executed changesets by ID + author + file path.

### Changeset Examples

**Create table:**
```yaml
# db/changelog/changes/001-create-users-table.yaml
databaseChangeLog:
  - changeSet:
      id: 001-create-users-table
      author: team
      changes:
        - createTable:
            tableName: users
            columns:
              - column:
                  name: id
                  type: bigint
                  autoIncrement: true
                  constraints:
                    primaryKey: true
                    nullable: false
              - column:
                  name: name
                  type: varchar(255)
                  constraints:
                    nullable: false
              - column:
                  name: email
                  type: varchar(255)
                  constraints:
                    nullable: false
                    unique: true
              - column:
                  name: created_at
                  type: timestamp with time zone
                  constraints:
                    nullable: false
              - column:
                  name: updated_at
                  type: timestamp with time zone
                  constraints:
                    nullable: false
```

**Add column:**
```yaml
# db/changelog/changes/004-add-phone-column.yaml
databaseChangeLog:
  - changeSet:
      id: 004-add-phone-column
      author: team
      changes:
        - addColumn:
            tableName: users
            columns:
              - column:
                  name: phone
                  type: varchar(20)
                  constraints:
                    nullable: true
```

**Add index:**
```yaml
# db/changelog/changes/003-add-email-index.yaml
databaseChangeLog:
  - changeSet:
      id: 003-add-email-index
      author: team
      changes:
        - createIndex:
            indexName: idx_users_email
            tableName: users
            columns:
              - column:
                  name: email
```

**Data migration (seed/reference data):**
```yaml
# db/changelog/changes/005-seed-roles.yaml
databaseChangeLog:
  - changeSet:
      id: 005-seed-roles
      author: team
      context: "!test"
      changes:
        - insert:
            tableName: roles
            columns:
              - column: { name: name, value: ADMIN }
              - column: { name: description, value: Administrator }
        - insert:
            tableName: roles
            columns:
              - column: { name: name, value: USER }
              - column: { name: description, value: Standard user }
```

### Rollback Strategies

Always define rollbacks for schema changes so failed deployments can be reverted:

```yaml
databaseChangeLog:
  - changeSet:
      id: 004-add-phone-column
      author: team
      changes:
        - addColumn:
            tableName: users
            columns:
              - column:
                  name: phone
                  type: varchar(20)
      rollback:
        - dropColumn:
            tableName: users
            columnName: phone
```

**Rollback rules:**
- **`createTable`** — Liquibase auto-generates rollback (`dropTable`). Explicit rollback optional.
- **`addColumn`** — auto-rollback works. Explicit `dropColumn` recommended for clarity.
- **`insert` / data changes** — no auto-rollback. Always define explicit `delete` rollback.
- **`dropColumn` / `dropTable`** — rollback must recreate the column/table with data. This is destructive; avoid in production unless data is backed up.

### Contexts and Labels

Use **contexts** to control which changesets run in which environment:

```yaml
databaseChangeLog:
  - changeSet:
      id: 010-seed-test-users
      author: team
      context: "dev or test"
      changes:
        - insert:
            tableName: users
            columns:
              - column: { name: name, value: Test User }
              - column: { name: email, value: test@example.com }
```

Configure the active context in `application.properties`:
```properties
spring.liquibase.contexts=${LIQUIBASE_CONTEXTS:dev}
```

Common context patterns:
- `context: "!test"` — run everywhere except test
- `context: "dev or test"` — run in dev and test only
- `context: "prod"` — production-only seed data
- No context attribute — runs in all environments (default for schema changes)

### Preconditions

Use **preconditions** to guard against re-applying changes or applying to the wrong database:

```yaml
databaseChangeLog:
  - changeSet:
      id: 020-add-status-column
      author: team
      preConditions:
        - onFail: MARK_RAN
        - not:
            - columnExists:
                tableName: users
                columnName: status
      changes:
        - addColumn:
            tableName: users
            columns:
              - column:
                  name: status
                  type: varchar(20)
                  defaultValue: ACTIVE
```

### Production Migration Best Practices

1. **Lock timeout** — configure Liquibase lock wait time to avoid blocking deployments:
   ```properties
   spring.liquibase.liquibase-schema=public
   ```
   If Liquibase gets stuck on a lock, clear it manually: `DELETE FROM databasechangeloglock WHERE locked = true;`
2. **Never modify a deployed changeset** — Liquibase validates checksums. If a checksum fails, the app won't start. Always add new changesets.
3. **Test migrations against a copy of production data** — never run untested migrations in production.
4. **Make migrations backward-compatible** — add columns as nullable first, deploy code that handles both old and new schema, then add constraints in a later changeset.
5. **Separate destructive changes** — dropping columns or tables should be in their own changeset, deployed after the code no longer references them.
6. **Use `ddl-auto=validate`** in production — Hibernate validates that entities match the schema without making changes:
   ```properties
   spring.jpa.hibernate.ddl-auto=${DDL_AUTO:validate}
   ```

---

## Transactions

- `@Transactional` goes on **service methods**, not repositories.
- Use `@Transactional(readOnly = true)` for read-only operations.
- Keep transactions short — no HTTP calls or heavy computation inside them.

---

## Connection Pooling (HikariCP)

**HikariCP is Spring Boot's default connection pool.** Always configure it explicitly — the defaults are rarely optimal for production.

Add to `application.properties`:

```properties
# ===== HikariCP Connection Pool =====
spring.datasource.hikari.pool-name=AppHikariPool
spring.datasource.hikari.maximum-pool-size=${HIKARI_MAX_POOL_SIZE:10}
spring.datasource.hikari.minimum-idle=${HIKARI_MIN_IDLE:5}
spring.datasource.hikari.idle-timeout=300000
spring.datasource.hikari.max-lifetime=1800000
spring.datasource.hikari.connection-timeout=30000
spring.datasource.hikari.leak-detection-threshold=60000
spring.datasource.hikari.validation-timeout=5000
```

<!-- CUSTOMIZE: Adjust pool sizes based on your database and expected concurrency -->

| Property | Default | Description |
|----------|---------|-------------|
| `maximum-pool-size` | 10 | Max number of connections (active + idle). Formula: `connections = (core_count * 2) + effective_spindle_count`. Start with 10, increase based on load testing. |
| `minimum-idle` | same as max | Min idle connections kept in pool. Set lower than max to allow pool to shrink during low traffic. |
| `idle-timeout` | 600000 (10m) | How long an idle connection stays in pool before being retired. Use 300000 (5m). |
| `max-lifetime` | 1800000 (30m) | Max lifetime of a connection. Must be **shorter** than the database's `wait_timeout`. |
| `connection-timeout` | 30000 (30s) | How long to wait for a connection from the pool before throwing an exception. |
| `leak-detection-threshold` | 0 (disabled) | Log a warning if a connection is held longer than this (ms). Use 60000 (60s) to detect leaks. |
| `validation-timeout` | 5000 (5s) | Timeout for connection validation check. |

### Pool Sizing Guidelines

1. **Start small** — 10 connections handles more load than you think. Each connection consumes database memory and OS resources.
2. **Formula**: `pool_size = (core_count * 2) + effective_spindle_count` (from HikariCP wiki). For SSDs, `spindle_count = 1`.
3. **Monitor before scaling** — use Actuator metrics (`hikaricp.connections.active`, `hikaricp.connections.idle`, `hikaricp.connections.pending`) to right-size.
4. **Multiple microservices** — if 10 services each have `max-pool-size=10`, that's 100 connections to the database. Coordinate across services.
5. **Never set `maximum-pool-size` higher than the database's `max_connections`** — on PostgreSQL, check with `SHOW max_connections;`.

### Monitoring Pool Metrics

HikariCP automatically exposes metrics via Micrometer (see [actuator-health.md](actuator-health.md)):

```bash
# Active connections
curl http://localhost:8080/actuator/metrics/hikaricp.connections.active

# Idle connections
curl http://localhost:8080/actuator/metrics/hikaricp.connections.idle

# Pending connection requests (should be 0 under normal load)
curl http://localhost:8080/actuator/metrics/hikaricp.connections.pending

# Connection acquisition time
curl http://localhost:8080/actuator/metrics/hikaricp.connections.acquire
```

If `hikaricp.connections.pending` is consistently > 0, **increase the pool size or optimize slow queries**.

---

## JPA Auditing

**Every project using `@CreatedDate` / `@LastModifiedDate` must enable JPA auditing.**

### When to Use Auditing

Audit fields are for **business entities that users create or modify**. Not every entity needs them:

| Needs Auditing | Skip Auditing |
|---------------|---------------|
| `User`, `Order`, `Invoice`, `Payment` | `Country`, `Currency`, `Permission`, `Role` (static reference data) |
| `Comment`, `Document`, `Ticket` | Join tables (`user_roles`, `order_tags`) |
| Any entity created/updated by end users | Configuration or seed data tables |

Entities that need auditing extend `BaseAuditEntity`. Entities that don't simply extend nothing (or their own base class without audit fields).

### Enable Auditing

Create a config class in `config/`:

```java
@Configuration
@EnableJpaAuditing
public class JpaAuditingConfig {
}
```

### Base Audit Entity

Use a `@MappedSuperclass` to share audit fields across all entities:

```java
@Getter
@Setter
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseAuditEntity {

    @CreatedDate
    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(nullable = false)
    private Instant updatedAt;

    @CreatedBy
    @Column(updatable = false)
    private String createdBy;

    @LastModifiedBy
    private String updatedBy;
}
```

Then extend it in your entities that need auditing:
```java
// ✅ Business entity — needs auditing
@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
public class User extends BaseAuditEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false, unique = true)
    private String email;
}
```

Reference/lookup entities do **not** extend `BaseAuditEntity`:
```java
// ✅ Static reference data — no auditing needed
@Entity
@Table(name = "countries")
@Getter
@Setter
@NoArgsConstructor
public class Country {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String code;

    @Column(nullable = false)
    private String name;
}
```

### AuditorAware — Track Who Made Changes

Implement `AuditorAware` to automatically populate `@CreatedBy` and `@LastModifiedBy`:

```java
@Component
public class SecurityAuditorAware implements AuditorAware<String> {

    @Override
    public Optional<String> getCurrentAuditor() {
        return Optional.ofNullable(SecurityContextHolder.getContext().getAuthentication())
            .filter(Authentication::isAuthenticated)
            .map(Authentication::getName)
            .or(() -> Optional.of("system"));
    }
}
```

Register it in the auditing config:
```java
@Configuration
@EnableJpaAuditing(auditorAwareRef = "securityAuditorAware")
public class JpaAuditingConfig {
}
```

<!-- CUSTOMIZE: If not using Spring Security, return a fixed value like "system" or extract from a custom request header -->

### Audit Trail / History Tables (Optional)

For compliance or debugging, use **Hibernate Envers** to automatically track all entity changes in history tables:

```xml
<dependency>
    <groupId>org.hibernate.orm</groupId>
    <artifactId>hibernate-envers</artifactId>
</dependency>
```

Annotate entities that need full history:
```java
@Entity
@Audited
@Table(name = "orders")
public class Order extends BaseAuditEntity {
    // All changes are tracked in an orders_aud table
}
```

Query audit history:
```java
@Service
@RequiredArgsConstructor
public class OrderAuditService {

    private final EntityManager entityManager;

    /**
     * Returns all revisions of an order, newest first.
     */
    public List<Order> getOrderHistory(Long orderId) {
        var reader = AuditReaderFactory.get(entityManager);
        var revisions = reader.getRevisions(Order.class, orderId);
        return revisions.stream()
            .sorted(Comparator.reverseOrder())
            .map(rev -> reader.find(Order.class, orderId, rev))
            .toList();
    }
}
```

**Rules for auditing:**
1. **Always enable `@EnableJpaAuditing`** when using `@CreatedDate` / `@LastModifiedDate` — they don't work without it.
2. **Use `BaseAuditEntity`** as a superclass only for business entities that users create or modify — not for lookup/reference tables.
3. **Implement `AuditorAware`** when you need to track who made changes (requires authentication context).
4. **Use Envers only when required** — it adds a history table per audited entity, which increases storage and write overhead. Apply `@Audited` selectively to entities that need compliance-grade change tracking.
5. **Add audit columns to Liquibase migrations** — `created_at`, `updated_at`, `created_by`, `updated_by`.

---

## Performance — N+1 Prevention

**N+1 queries are the #1 performance killer. Always prevent them.**

1. **Default ALL relationships to `FetchType.LAZY`** — this is non-negotiable.
2. **Use `@EntityGraph`** on repository methods when you need related data:
   ```java
   @EntityGraph(attributePaths = {"orders", "orders.items"})
   Optional<User> findWithOrdersById(Long id);
   ```
3. **Use `JOIN FETCH` in JPQL** for custom queries:
   ```java
   @Query("SELECT u FROM User u JOIN FETCH u.orders WHERE u.id = :id")
   Optional<User> findWithOrdersFetchById(@Param("id") Long id);
   ```
4. **Set batch fetch size** globally in `application.properties`:
   ```properties
   spring.jpa.properties.hibernate.default_batch_fetch_size=20
   ```
5. **Disable Open-in-View** — set `spring.jpa.open-in-view=false` in `application.properties`:
   ```properties
   spring.jpa.open-in-view=false
   ```
   Open-in-View keeps a Hibernate session open for the entire HTTP request, allowing lazy loading in controllers and views. This **hides N+1 bugs**, ties database connections to slow HTTP responses, and violates layered architecture. With it disabled, any lazy access outside a `@Transactional` service method throws `LazyInitializationException` — which forces you to fix the real problem (missing `JOIN FETCH` or `@EntityGraph`).
6. **Avoid fetching full entities** when only a few fields are needed — use projections.
7. **Enable SQL logging in dev** to catch N+1 early:
   ```properties
   spring.jpa.show-sql=true
   logging.level.org.hibernate.SQL=DEBUG
   logging.level.org.hibernate.orm.jdbc.bind=TRACE
   ```
8. **Review every repository method** — if it touches a `@OneToMany` or `@ManyToOne`, it must use `@EntityGraph` or `JOIN FETCH`.
