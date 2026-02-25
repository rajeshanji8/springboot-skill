# Database & JPA

Follow these conventions for database access and JPA entity design in Spring Boot.

---

## Entity Design

1. **Use `@Entity`** on all persistent classes. Keep them in `model/entity/`.
2. **Use `Long` for IDs** with `@GeneratedValue(strategy = GenerationType.IDENTITY)`.
3. **Add audit fields** to every entity: `createdAt`, `updatedAt`.
4. **Use `@MappedSuperclass`** or Spring Data's `@EntityListeners(AuditingEntityListener.class)` for common audit fields.
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

---

## Transactions

- `@Transactional` goes on **service methods**, not repositories.
- Use `@Transactional(readOnly = true)` for read-only operations.
- Keep transactions short — no HTTP calls or heavy computation inside them.

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
5. **Avoid fetching full entities** when only a few fields are needed — use projections.
6. **Enable SQL logging in dev** to catch N+1 early:
   ```properties
   spring.jpa.show-sql=true
   logging.level.org.hibernate.SQL=DEBUG
   logging.level.org.hibernate.orm.jdbc.bind=TRACE
   ```
7. **Review every repository method** — if it touches a `@OneToMany` or `@ManyToOne`, it must use `@EntityGraph` or `JOIN FETCH`.
