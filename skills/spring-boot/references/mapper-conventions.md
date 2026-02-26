# Mapper Conventions

Follow these conventions for mapping between entities and DTOs in Spring Boot.

---

## TLDR — Mandatory Rules
- All mapping logic lives in `mapper/` package — never in controllers or services directly
- ALWAYS use MapStruct with `componentModel = "spring"` — no other mapper library
- Entities never cross the service boundary — services return DTOs via mappers
- One mapper per aggregate root (`UserMapper`, `OrderMapper`)
- Use `@BeanMapping(nullValuePropertyMappingStrategy = IGNORE)` for partial updates (PATCH)

---

## Strategy

**All mapping logic lives in the `mapper/` package — never in controllers or services.**

1. Controllers receive DTOs, pass them to services.
2. Services call mappers to convert DTOs ↔ entities internally.
3. Services return DTOs to controllers — entities never cross the service boundary.

---

## MapStruct (Preferred)

Use **MapStruct** for all entity ↔ DTO mapping. It generates type-safe, zero-reflection code at compile time.

### Dependency

Add to `pom.xml`:
```xml
<dependency>
    <groupId>org.mapstruct</groupId>
    <artifactId>mapstruct</artifactId>
    <version>${mapstruct.version}</version>
</dependency>
```

Configure the annotation processor (must come after Lombok's processor):
```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <configuration>
        <annotationProcessorPaths>
            <path>
                <groupId>org.projectlombok</groupId>
                <artifactId>lombok</artifactId>
                <version>${lombok.version}</version>
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
```

<!-- CUSTOMIZE: Update MapStruct version to the latest stable release -->

### Mapper Interface

```java
@Mapper(componentModel = "spring")
public interface UserMapper {

    UserResponse toResponse(User user);

    List<UserResponse> toResponseList(List<User> users);

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    User toEntity(CreateUserRequest request);

    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    void updateEntity(UpdateUserRequest request, @MappingTarget User user);
}
```

### Usage in Service

```java
@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;

    public UserResponse create(CreateUserRequest request) {
        var user = userMapper.toEntity(request);
        var saved = userRepository.save(user);
        return userMapper.toResponse(saved);
    }

    public UserResponse update(Long id, UpdateUserRequest request) {
        var user = userRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("User", id));
        userMapper.updateEntity(request, user);
        var saved = userRepository.save(user);
        return userMapper.toResponse(saved);
    }
}
```

---

## Manual Mapping (Fallback)

If MapStruct is not used, write manual mapper classes — still in `mapper/` package:

```java
@Component
public class UserMapper {

    public UserResponse toResponse(User user) {
        return new UserResponse(
            user.getId(),
            user.getName(),
            user.getEmail(),
            user.getCreatedAt()
        );
    }

    public User toEntity(CreateUserRequest request) {
        var user = new User();
        user.setName(request.name());
        user.setEmail(request.email());
        return user;
    }
}
```

---

## Rules

1. **One mapper per aggregate root** — `UserMapper`, `OrderMapper`, etc.
2. **Mapper classes are Spring-managed beans** — use `componentModel = "spring"` with MapStruct, or `@Component` for manual mappers.
3. **Never map inside controllers** — controllers call services, services call mappers.
4. **Never expose entities outside the service layer** — always return DTOs.
5. **Use `@Mapping(target = ..., ignore = true)`** for fields the caller shouldn't set (ID, audit fields).
6. **Use `@BeanMapping(nullValuePropertyMappingStrategy = IGNORE)`** for partial updates (PATCH) so null fields in the request don't overwrite existing values.
7. **Test mappers** — MapStruct generates code, but verify custom mappings and edge cases (see [testing.md](testing.md) for test conventions).
