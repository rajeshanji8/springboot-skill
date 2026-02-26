# Testing

Follow these conventions when writing tests for a Spring Boot application.

---

## TLDR — Mandatory Rules
- Every service method gets a unit test (happy path + one failure case minimum)
- Every controller endpoint gets a `@WebMvcTest` slice test — count endpoints, then count test methods; every endpoint MUST have at least one test
- Use AssertJ for assertions, Mockito for mocking — JUnit 5 + `@ExtendWith(MockitoExtension.class)`
- Test naming: `should{Expected}When{Condition}`
- No `Thread.sleep` in tests — use Awaitility for async assertions
- Don't test framework behavior — test your custom queries and business logic

---

## Test Structure

```
src/test/java/com/example/appname/
├── controller/        # @WebMvcTest — slice tests for controllers
├── service/           # Plain unit tests (mocked dependencies)
├── repository/        # @DataJpaTest — slice tests for JPA
└── integration/       # @SpringBootTest — full integration tests
```

---

## Testing Tiers

### 1. Unit Tests (Service layer)
- Use **JUnit 5** + **Mockito**.
- Test business logic in isolation — mock all dependencies.
- Fast, no Spring context.

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserService userService;

    @Test
    void shouldReturnUserWhenFound() {
        var user = new User();
        user.setId(1L);
        user.setName("Alice");

        when(userRepository.findById(1L)).thenReturn(Optional.of(user));

        var result = userService.findById(1L);

        assertThat(result.name()).isEqualTo("Alice");
        verify(userRepository).findById(1L);
    }
}
```

### 2. Controller Slice Tests
- Use **`@WebMvcTest`** to test controllers without full context.
- Mock service layer with `@MockitoBean` (Spring Boot 3.4+). `@MockBean` is deprecated — NEVER use it.
- Use `MockMvc` to send HTTP requests.

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserService userService;

    @Test
    void shouldReturn200WhenUserExists() throws Exception {
        when(userService.findById(1L))
            .thenReturn(new UserResponse(1L, "Alice", "alice@test.com", Instant.now()));

        mockMvc.perform(get("/api/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Alice"));
    }
}
```

### 3. Repository Slice Tests
- Use **`@DataJpaTest`** with an embedded database (H2).
- Test custom queries, not Spring Data's built-in methods.

### 4. Integration Tests
- Use **`@SpringBootTest`** with `webEnvironment = RANDOM_PORT`.
- Use **Testcontainers** for real database testing.
- Test full request → response flows.

---

## Naming Convention

- Test class: `{ClassName}Test` for unit, `{ClassName}IT` for integration.
- Test method: `should{ExpectedBehavior}When{Condition}` or descriptive sentence.

```java
void shouldThrowWhenUserNotFound()
void shouldReturn404WhenIdDoesNotExist()
```

---

## Assertions

- Use **AssertJ** — prefer it over JUnit's built-in assertions.
  ```java
  assertThat(result).isNotNull();
  assertThat(result.name()).isEqualTo("Alice");
  assertThat(list).hasSize(3).extracting("name").contains("Alice");
  ```

---

## Rules

1. **Every service method gets a unit test** — at minimum, happy path + one failure case.
2. **Every controller endpoint gets a slice test** — verify status codes, response shape, validation.
3. **Don't test framework behavior** — trust that `findById` works; test your custom queries.
4. **Use `@Transactional` on integration tests** so they auto-rollback.
5. **No Thread.sleep in tests** — use Awaitility for async assertions if needed (see [async-scheduling.md](async-scheduling.md) for async patterns).
6. **Test data builders or fixtures** — avoid creating test data inline everywhere.
