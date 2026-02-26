---
applyTo: "**/*Test.java,**/*IT.java"
---

# Test Conventions

Follow the spring-boot skill at `.github/skills/spring-boot/SKILL.md` — specifically the Testing section.

## Rules
- Every service method gets a unit test — happy path + at least one failure case
- Every controller endpoint gets a `@WebMvcTest` slice test — verify status codes, response shape, validation
- Use `@MockitoBean` in slice tests (Spring Boot 3.4+) — `@MockBean` is deprecated, NEVER use it
- Use AssertJ for all assertions — prefer over JUnit's built-in
- Use Mockito with `@ExtendWith(MockitoExtension.class)` for mocking
- Test naming: `should{Expected}When{Condition}` — e.g., `shouldReturnUserWhenIdExists`
- No `Thread.sleep` in tests — use Awaitility for async assertions
- Don't test framework behavior — test your custom queries and business logic, not `findById`
- Repository tests use `@DataJpaTest` with Testcontainers for real database testing
- Integration tests use `@SpringBootTest` with Testcontainers
