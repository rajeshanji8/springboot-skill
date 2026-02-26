# Caching

Follow these conventions for caching in Spring Boot applications.

---

## TLDR — Mandatory Rules
- Cache at the service layer only — never `@Cacheable` on controllers or repositories
- ALWAYS define an explicit TTL — never cache indefinitely. Default: 10 minutes if no business requirement
- Evict on every mutation — `@CacheEvict` or `@CachePut` on create/update/delete
- Cache DTOs, not entities — lazy proxies break outside transactions
- Self-invocation bypasses cache proxy — call `@Cacheable` methods from another bean

---

## Dependencies

Add Spring Cache starter:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-cache</artifactId>
</dependency>
```

For a production cache provider, add **Caffeine** (in-process) or **Redis** (distributed):

```xml
<!-- Caffeine (in-process, single-node) -->
<dependency>
    <groupId>com.github.ben-manes.caffeine</groupId>
    <artifactId>caffeine</artifactId>
</dependency>

<!-- Redis (distributed, multi-node) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
```

<!-- CUSTOMIZE: Choose Caffeine for single-instance apps, Redis for distributed or shared cache -->

---

## Enable Caching

Add `@EnableCaching` to a configuration class in `config/`:

```java
@Configuration
@EnableCaching
public class CacheConfig {
}
```

---

## Caffeine Configuration

Configure cache names, TTL, and max size in `application.properties`:

```properties
spring.cache.type=caffeine
spring.cache.caffeine.spec=maximumSize=1000,expireAfterWrite=10m
```

For per-cache configuration, define beans:

```java
@Configuration
@EnableCaching
public class CacheConfig {

    @Bean
    public CaffeineCacheManager cacheManager() {
        var manager = new CaffeineCacheManager();
        manager.setCaffeine(Caffeine.newBuilder()
            .maximumSize(1000)
            .expireAfterWrite(Duration.ofMinutes(10))
            .recordStats());
        return manager;
    }
}
```

### Per-Cache TTL Configuration

When different caches need different TTLs, define each cache individually:

```java
@Configuration
@EnableCaching
public class CacheConfig {

    @Bean
    public CacheManager cacheManager() {
        var manager = new SimpleCacheManager();
        manager.setCaches(List.of(
            buildCache("users", Duration.ofMinutes(10), 1000),
            buildCache("products", Duration.ofMinutes(30), 5000),
            buildCache("config", Duration.ofHours(1), 100)
        ));
        return manager;
    }

    private CaffeineCache buildCache(String name, Duration ttl, long maxSize) {
        return new CaffeineCache(name, Caffeine.newBuilder()
            .maximumSize(maxSize)
            .expireAfterWrite(ttl)
            .recordStats()
            .build());
    }
}
```

This gives each cache its own TTL and max size — short-lived user data vs. long-lived config.

---

## Redis Configuration

```properties
spring.cache.type=redis
spring.data.redis.host=${REDIS_HOST:localhost}
spring.data.redis.port=${REDIS_PORT:6379}
spring.cache.redis.time-to-live=600000
spring.cache.redis.key-prefix=myapp::
spring.cache.redis.use-key-prefix=true
```

---

## Using Cache Annotations

Apply cache annotations on **service methods**, never on controllers or repositories:

```java
@Slf4j
@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;

    @Cacheable(value = "users", key = "#id")
    public UserResponse findById(Long id) {
        log.debug("Cache miss — loading user id={}", id);
        var user = userRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("User", id));
        return userMapper.toResponse(user);
    }

    @CachePut(value = "users", key = "#result.id()")
    public UserResponse update(Long id, UpdateUserRequest request) {
        var user = userRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("User", id));
        userMapper.updateEntity(request, user);
        var saved = userRepository.save(user);
        return userMapper.toResponse(saved);
    }

    @CacheEvict(value = "users", key = "#id")
    public void delete(Long id) {
        userRepository.deleteById(id);
    }

    @CacheEvict(value = "users", allEntries = true)
    public void clearCache() {
        log.info("User cache cleared");
    }
}
```

---

## Cache Annotations Reference

| Annotation | Purpose |
|-----------|---------|
| `@Cacheable` | Return from cache if present; otherwise execute method and cache the result |
| `@CachePut` | Always execute method and update the cache |
| `@CacheEvict` | Remove entry from cache |
| `@Caching` | Combine multiple cache operations on one method |

---

## Rules

1. **Cache at the service layer** — never put `@Cacheable` on controllers or repositories.
2. **Use meaningful cache names** — `"users"`, `"products"`, `"config"` — not generic names.
3. **Always define a TTL** — never cache indefinitely. Start with 10 minutes and adjust.
4. **Evict on mutation** — every create/update/delete must `@CacheEvict` or `@CachePut` the affected cache.
5. **Cache DTOs, not entities** — entities have lazy-loaded proxies that break outside a transaction. Use mappers to convert first (see [mapper-conventions.md](mapper-conventions.md)).
6. **Log cache misses** — add `log.debug("Cache miss")` in `@Cacheable` methods to verify caching works.
7. **Use Caffeine for single-instance apps**, Redis for distributed deployments.
8. **Don't cache volatile data** — if data changes every few seconds, caching adds complexity without benefit.
9. **Spring cache proxies are method-level** — calling a `@Cacheable` method from within the same class bypasses the cache. Call from another bean.
