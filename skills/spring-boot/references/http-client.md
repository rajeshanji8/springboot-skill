# HTTP Client

Follow these conventions when making outbound HTTP calls from a Spring Boot application.

---

## Strategy

1. **Use `RestClient`** (Spring 6.1+) as the default HTTP client — it's the modern, synchronous replacement for `RestTemplate`.
2. **Use `WebClient`** only when you need reactive/non-blocking calls or streaming responses.
3. **Never use `RestTemplate` in new code** — it's in maintenance mode. Use `RestClient` instead.
4. **Define client beans in `config/` package** — never create HTTP clients inline in services.
5. **Always configure timeouts** — no HTTP call should wait indefinitely.

---

## Dependencies

`RestClient` is included with `spring-boot-starter-web`. No extra dependencies needed.

For `WebClient`, add:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-webflux</artifactId>
</dependency>
```

---

## RestClient Configuration

### Define a Configured RestClient Bean

Create in `config/` package with timeouts, base URL, and default headers:

```java
@Configuration
public class RestClientConfig {

    @Bean
    public RestClient restClient(RestClient.Builder builder) {
        return builder
            .baseUrl("${app.external-api.base-url}")
            .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
            .defaultHeader(HttpHeaders.ACCEPT, MediaType.APPLICATION_JSON_VALUE)
            .requestFactory(clientHttpRequestFactory())
            .build();
    }

    /**
     * Configures connection and read timeouts for all outbound HTTP calls.
     */
    private ClientHttpRequestFactory clientHttpRequestFactory() {
        var factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofSeconds(5));
        factory.setReadTimeout(Duration.ofSeconds(10));
        return factory;
    }
}
```

<!-- CUSTOMIZE: Adjust timeouts based on the external service's expected latency -->

### Multiple External Services

When calling multiple external APIs, define **named beans** — one per service:

```java
@Configuration
public class RestClientConfig {

    @Bean("paymentRestClient")
    public RestClient paymentRestClient(RestClient.Builder builder,
                                         AppProperties appProperties) {
        return builder
            .baseUrl(appProperties.getPayment().getBaseUrl())
            .defaultHeader("X-API-Key", appProperties.getPayment().getApiKey())
            .requestFactory(requestFactory(
                Duration.ofSeconds(5),
                Duration.ofSeconds(15)
            ))
            .build();
    }

    @Bean("notificationRestClient")
    public RestClient notificationRestClient(RestClient.Builder builder,
                                              AppProperties appProperties) {
        return builder
            .baseUrl(appProperties.getNotification().getBaseUrl())
            .requestFactory(requestFactory(
                Duration.ofSeconds(3),
                Duration.ofSeconds(5)
            ))
            .build();
    }

    private ClientHttpRequestFactory requestFactory(Duration connectTimeout,
                                                     Duration readTimeout) {
        var factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(connectTimeout);
        factory.setReadTimeout(readTimeout);
        return factory;
    }
}
```

Inject by qualifier — **`@Qualifier` requires Lombok configuration** to work with `@RequiredArgsConstructor`:

Add to `lombok.config` in the project root:
```
lombok.copyableAnnotations += org.springframework.beans.factory.annotation.Qualifier
```

Then inject normally:
```java
@Service
@RequiredArgsConstructor
public class PaymentService {

    @Qualifier("paymentRestClient")
    private final RestClient restClient;
}
```

Without `lombok.config`, use an explicit constructor instead:
```java
@Service
public class PaymentService {

    private final RestClient restClient;

    public PaymentService(@Qualifier("paymentRestClient") RestClient restClient) {
        this.restClient = restClient;
    }
}
```

### Externalize Client Configuration

In `application.properties`:
```properties
# ===== External Services =====
app.payment.base-url=${PAYMENT_API_URL:https://api.payment-provider.com}
app.payment.api-key=${PAYMENT_API_KEY:}
app.payment.connect-timeout-ms=${PAYMENT_CONNECT_TIMEOUT:5000}
app.payment.read-timeout-ms=${PAYMENT_READ_TIMEOUT:15000}

app.notification.base-url=${NOTIFICATION_API_URL:https://api.notification-provider.com}
app.notification.connect-timeout-ms=${NOTIFICATION_CONNECT_TIMEOUT:3000}
app.notification.read-timeout-ms=${NOTIFICATION_READ_TIMEOUT:5000}
```

---

## Making Requests

### GET

```java
@Slf4j
@Service
@RequiredArgsConstructor
public class UserExternalService {

    private final RestClient restClient;

    /**
     * Fetches a user profile from the external identity service.
     */
    public ExternalUserResponse getUser(String externalId) {
        log.debug("Fetching external user id={}", externalId);
        return restClient.get()
            .uri("/users/{id}", externalId)
            .retrieve()
            .body(ExternalUserResponse.class);
    }

    /**
     * Fetches a list of users with query parameters.
     */
    public List<ExternalUserResponse> searchUsers(String query, int page) {
        return restClient.get()
            .uri(uriBuilder -> uriBuilder
                .path("/users")
                .queryParam("q", query)
                .queryParam("page", page)
                .build())
            .retrieve()
            .body(new ParameterizedTypeReference<>() {});
    }
}
```

### POST

```java
/**
 * Creates a payment in the external payment service.
 */
public PaymentResponse createPayment(CreatePaymentRequest request) {
    log.info("Creating payment for orderId={}", request.orderId());
    return restClient.post()
        .uri("/payments")
        .body(request)
        .retrieve()
        .body(PaymentResponse.class);
}
```

### PUT / PATCH / DELETE

```java
// PUT — full update
restClient.put()
    .uri("/users/{id}", userId)
    .body(updateRequest)
    .retrieve()
    .body(UserResponse.class);

// PATCH — partial update
restClient.patch()
    .uri("/users/{id}", userId)
    .body(patchRequest)
    .retrieve()
    .body(UserResponse.class);

// DELETE — no response body
restClient.delete()
    .uri("/users/{id}", userId)
    .retrieve()
    .toBodilessEntity();
```

### Accessing Full Response (status, headers)

```java
ResponseEntity<UserResponse> response = restClient.get()
    .uri("/users/{id}", userId)
    .retrieve()
    .toEntity(UserResponse.class);

HttpStatusCode status = response.getStatusCode();
HttpHeaders headers = response.getHeaders();
UserResponse body = response.getBody();
```

---

## Error Handling

**Never let HTTP client exceptions propagate uncaught to the global handler.** Wrap external calls and translate failures into domain exceptions.

### Using RestClient Status Handlers

```java
public ExternalUserResponse getUser(String externalId) {
    return restClient.get()
        .uri("/users/{id}", externalId)
        .retrieve()
        .onStatus(HttpStatusCode::is4xxClientError, (request, response) -> {
            log.warn("External API client error: status={}, uri={}", 
                response.getStatusCode(), request.getURI());
            if (response.getStatusCode() == HttpStatus.NOT_FOUND) {
                throw new ResourceNotFoundException("ExternalUser", externalId);
            }
            throw new ExternalServiceException(
                "Client error from identity service: " + response.getStatusCode()
            );
        })
        .onStatus(HttpStatusCode::is5xxServerError, (request, response) -> {
            log.error("External API server error: status={}, uri={}",
                response.getStatusCode(), request.getURI());
            throw new ExternalServiceException(
                "Identity service unavailable: " + response.getStatusCode()
            );
        })
        .body(ExternalUserResponse.class);
}
```

### Custom Exception for External Failures

```java
public class ExternalServiceException extends RuntimeException {
    public ExternalServiceException(String message) {
        super(message);
    }

    public ExternalServiceException(String message, Throwable cause) {
        super(message, cause);
    }
}
```

Handle it in the global exception handler (see [error-handling.md](error-handling.md)):
```java
@ExceptionHandler(ExternalServiceException.class)
public ProblemDetail handleExternalService(ExternalServiceException ex) {
    log.error("External service failure: {}", ex.getMessage());
    return ProblemDetail.forStatusAndDetail(
        HttpStatus.BAD_GATEWAY, "An upstream service is unavailable"
    );
}
```

### Try-Catch Wrapper Pattern

For services where you want to catch all HTTP failures:

```java
/**
 * Fetches user from external service. Returns empty if not found or service unavailable.
 */
public Optional<ExternalUserResponse> getUser(String externalId) {
    try {
        var user = restClient.get()
            .uri("/users/{id}", externalId)
            .retrieve()
            .body(ExternalUserResponse.class);
        return Optional.ofNullable(user);
    } catch (RestClientResponseException ex) {
        log.warn("External API error fetching user {}: status={}", 
            externalId, ex.getStatusCode());
        return Optional.empty();
    } catch (ResourceAccessException ex) {
        log.error("External API unreachable when fetching user {}: {}", 
            externalId, ex.getMessage());
        return Optional.empty();
    }
}
```

---

## Timeouts

**Every outbound HTTP call must have timeouts configured. No exceptions.**

| Timeout | Purpose | Recommended |
|---------|---------|-------------|
| **Connect timeout** | Max time to establish a TCP connection | 3–5 seconds |
| **Read timeout** | Max time to wait for response data after connection is established | 5–15 seconds |

### Per-Request Timeout Override

If a specific call needs a different timeout than the client default, create a separate `RestClient` bean with different timeouts — don't try to change timeouts per request on `SimpleClientHttpRequestFactory`.

### Apache HttpClient 5 for Advanced Connection Pooling

For production apps with high outbound traffic, replace `SimpleClientHttpRequestFactory` with **Apache HttpClient 5** for connection pooling, keep-alive, and per-route limits:

```xml
<dependency>
    <groupId>org.apache.httpcomponents.client5</groupId>
    <artifactId>httpclient5</artifactId>
</dependency>
```

```java
@Configuration
public class RestClientConfig {

    @Bean
    public RestClient restClient(RestClient.Builder builder) {
        return builder
            .baseUrl("${app.external-api.base-url}")
            .requestFactory(apacheHttpRequestFactory())
            .build();
    }

    private ClientHttpRequestFactory apacheHttpRequestFactory() {
        var connectionManager = PoolingHttpClientConnectionManagerBuilder.create()
            .setMaxConnTotal(100)          // Total connections across all routes
            .setMaxConnPerRoute(20)        // Max connections per host
            .setDefaultConnectionConfig(ConnectionConfig.custom()
                .setConnectTimeout(Timeout.ofSeconds(5))
                .setSocketTimeout(Timeout.ofSeconds(10))
                .build())
            .build();

        var httpClient = HttpClients.custom()
            .setConnectionManager(connectionManager)
            .setDefaultRequestConfig(RequestConfig.custom()
                .setResponseTimeout(Timeout.ofSeconds(10))
                .build())
            .evictIdleConnections(TimeValue.ofSeconds(30))
            .build();

        return new HttpComponentsClientHttpRequestFactory(httpClient);
    }
}
```

<!-- CUSTOMIZE: Adjust pool sizes and timeouts based on your traffic patterns -->

| Setting | Default | Description |
|---------|---------|-------------|
| `maxConnTotal` | 25 | Total connection pool size across all hosts |
| `maxConnPerRoute` | 5 | Max connections to a single host. Increase if you call one service heavily. |
| `connectTimeout` | — | TCP connection timeout |
| `socketTimeout` | — | Timeout waiting for data on an established connection |
| `evictIdleConnections` | — | Close idle connections after this duration to free resources |

---

## Logging HTTP Requests and Responses

Enable request/response logging for debugging outbound calls. Add to `application.properties`:

```properties
# Log outbound HTTP requests (headers + body summary)
logging.level.org.springframework.web.client.RestClient=DEBUG

# For Apache HttpClient — wire-level logging (very verbose, use sparingly)
# logging.level.org.apache.hc.client5.http=DEBUG
# logging.level.org.apache.hc.client5.http.wire=DEBUG
```

---

## WebClient (Reactive / Non-Blocking)

Use `WebClient` only when you need non-blocking I/O or reactive stream processing. For standard synchronous calls, prefer `RestClient`.

```java
@Configuration
public class WebClientConfig {

    @Bean
    public WebClient webClient(WebClient.Builder builder) {
        return builder
            .baseUrl("${app.external-api.base-url}")
            .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
            .build();
    }
}
```

```java
@Service
@RequiredArgsConstructor
public class ReactiveExternalService {

    private final WebClient webClient;

    public Mono<ExternalUserResponse> getUser(String externalId) {
        return webClient.get()
            .uri("/users/{id}", externalId)
            .retrieve()
            .bodyToMono(ExternalUserResponse.class)
            .timeout(Duration.ofSeconds(10))
            .doOnError(ex -> log.error("Failed to fetch user {}", externalId, ex));
    }
}
```

---

## Rules

1. **Use `RestClient` for all synchronous outbound HTTP calls** — never `RestTemplate` in new code.
2. **Define client beans in `config/` package** — one bean per external service, with its own base URL, timeouts, and headers.
3. **Always configure connect and read timeouts** — never make an HTTP call without timeouts. Default: 5s connect, 10s read.
4. **Handle errors explicitly** — use `.onStatus()` handlers or try-catch. Never let raw `RestClientResponseException` reach end users.
5. **Translate external failures into domain exceptions** — `ExternalServiceException` → 502 Bad Gateway in the global handler.
6. **Log outbound calls** — at minimum `DEBUG` level for troubleshooting. Include the target URI, status code, and duration.
7. **Externalize base URLs, API keys, and timeouts** — in `application.properties` with `${ENV_VAR:default}` placeholders. See [configuration-properties.md](configuration-properties.md).
8. **Use Apache HttpClient 5 for high-traffic apps** — connection pooling prevents socket exhaustion and improves performance.
9. **Never create `RestClient` instances inline** — always inject a Spring-managed bean so configuration is centralized and testable.
10. **Use `WebClient` only for reactive/non-blocking needs** — don't add `spring-boot-starter-webflux` just for outbound HTTP.
11. **Write health indicators for critical external services** — see [actuator-health.md](actuator-health.md) for custom health checks.
12. **Test external calls with `MockRestServiceServer` or WireMock** — see [testing.md](testing.md) for test conventions.
