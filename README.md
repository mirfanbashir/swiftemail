# SwiftEmail

A lightweight, cross-platform Swift SDK for sending emails via multiple providers. Currently supports **Amazon SES** with a clean, unified API designed for extensibility.

## Features

- ✅ **Amazon SES Support** - Full SES v2 API integration with AWS SigV4 authentication
- 🚀 **Cross-Platform** - macOS 12+, iOS 15+, tvOS 15+, watchOS 8+, and **Linux**
- 🔐 **Zero External Dependencies** - Pure Swift implementation using CryptoKit/CommonCrypto
- 🎯 **Type-Safe API** - Comprehensive validation and error handling
- 🔄 **Automatic Retries** - Configurable exponential backoff with jitter
- 📝 **Parameter Interpolation** - `{{placeholder}}` replacement in subject/body
- 🔍 **Observability** - Middleware hooks for logging and monitoring
- ⚡ **Swift Concurrency** - Async/await throughout
- 🧪 **Fully Tested** - Comprehensive unit tests with mock transport

## Installation

### Swift Package Manager

Add SwiftEmail to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mirfanbashir/swiftemail.git", from: "0.1.0")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "SwiftEmail", package: "swiftemail")
    ]
)
```

## Quick Start

### Basic Email with Amazon SES

```swift
import SwiftEmailCore
import SwiftEmailProviders

// Configure SES
let config = SESConfig(
    accessKeyId: "YOUR_ACCESS_KEY",
    secretAccessKey: "YOUR_SECRET_KEY",
    region: "us-east-1"
)

// Create transport and client
let transport = SESTransport(config: config)
let client = SimpleEmailClient(transport: transport)

// Create message
let message = EmailMessage(
    from: EmailAddress("noreply@example.com", name: "Example App"),
    to: [EmailAddress("user@example.com", name: "User")],
    subject: "Welcome!",
    text: "Welcome to our service!",
    html: "<h1>Welcome!</h1><p>Thank you for signing up.</p>"
)

// Send email
let response = try await client.send(message, params: nil, context: nil)
print("Sent! Message ID: \(response.providerMessageId ?? "N/A")")
```

### Parameter Interpolation

```swift
let message = EmailMessage(
    from: EmailAddress("noreply@example.com"),
    to: [EmailAddress("alice@example.com")],
    subject: "Hello {{firstName}}!",
    text: "Your code is {{code}}. Valid for {{minutes}} minutes.",
    html: "<h1>Hello {{firstName}}!</h1><p>Code: <strong>{{code}}</strong></p>"
)

let params = [
    "firstName": "Alice",
    "code": "123456",
    "minutes": "15"
]

let response = try await client.send(message, params: params, context: nil)
```

### Configuration from Environment

```swift
// Set environment variables:
// AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION

let config = try SESConfig.fromEnvironment()
let transport = SESTransport(config: config)
let client = SimpleEmailClient(transport: transport)
```

## Advanced Usage

### Custom Retry Policy

```swift
let retryPolicy = RetryPolicy(
    maxAttempts: 5,
    baseDelay: .milliseconds(500),
    jitter: true,
    retryOn: { error in
        // Custom retry logic
        if let emailError = error as? EmailError {
            return emailError.isRetryable
        }
        return false
    }
)

let client = SimpleEmailClient(
    transport: transport,
    retryPolicy: retryPolicy
)
```

### Middleware for Logging

```swift
let logger = ConsoleLoggerMiddleware()

let client = SimpleEmailClient(
    transport: transport,
    middlewares: [logger]
)
```

### Custom Middleware

```swift
actor CustomMetricsMiddleware: Middleware {
    func willSend(message: EmailMessage, provider: SendResponse.Provider) async {
        // Track send attempts
        await metrics.increment("email.send.attempts")
    }
    
    func didSend(result: Result<SendResponse, Error>) async {
        switch result {
        case .success:
            await metrics.increment("email.send.success")
        case .failure:
            await metrics.increment("email.send.failure")
        }
    }
}
```

### Send Context with Timeout

```swift
let context = SendContext(
    timeout: .seconds(30),
    traceId: "request-123"
)

let response = try await client.send(message, params: nil, context: context)
```

### HTTP Request/Response Logging

Enable detailed HTTP logging for debugging:

```swift
// Minimal logging (URL and status code only)
let config = SESConfig(
    accessKeyId: "YOUR_ACCESS_KEY",
    secretAccessKey: "YOUR_SECRET_KEY",
    region: "us-east-1",
    httpLogging: .minimal
)

// Headers logging (includes all headers, sensitive ones redacted)
let config = SESConfig(
    accessKeyId: "YOUR_ACCESS_KEY",
    secretAccessKey: "YOUR_SECRET_KEY",
    region: "us-east-1",
    httpLogging: .headers
)

// Body logging (includes request/response bodies)
let config = SESConfig(
    accessKeyId: "YOUR_ACCESS_KEY",
    secretAccessKey: "YOUR_SECRET_KEY",
    region: "us-east-1",
    httpLogging: .body
)

// Verbose logging (everything plus timing)
let config = SESConfig(
    accessKeyId: "YOUR_ACCESS_KEY",
    secretAccessKey: "YOUR_SECRET_KEY",
    region: "us-east-1",
    httpLogging: .verbose
)

// Custom logging configuration
let customLogging = HTTPLoggingConfig(
    level: .body,
    redactedHeaders: ["Authorization", "x-amz-security-token", "x-api-key"],
    maxBodyBytes: 5000  // Limit body output to 5KB
)
let config = SESConfig(
    accessKeyId: "YOUR_ACCESS_KEY",
    secretAccessKey: "YOUR_SECRET_KEY",
    region: "us-east-1",
    httpLogging: customLogging
)
```

Example output with verbose logging:
```
🔵 [HTTP Request]
   POST https://email.us-east-1.amazonaws.com/v2/email/outbound-emails
   Headers:
      Content-Type: application/json
      Authorization: [REDACTED]
      x-amz-date: 20251115T120000Z
   Body (234 bytes):
      {"Content":{"Simple":{"Subject":{"Data":"Welcome"}...}}

🟢 [HTTP Response]
   Status: 200
   Duration: 0.456s
   Headers:
      content-type: application/json
      x-amzn-RequestId: abc123...
   Body (67 bytes):
      {"MessageId":"0102..."}
```

## Testing

SwiftEmail includes a `MockTransport` for easy testing:

```swift
import Testing

let mockTransport = MockTransport(behavior: .success)
let client = SimpleEmailClient(transport: mockTransport)

// Send test email
let response = try await client.send(testMessage, params: nil, context: nil)

// Verify
let sentMessage = await mockTransport.getLastMessage()
#expect(sentMessage?.subject == "Expected Subject")
```

### Mock Behaviors

```swift
// Always succeed
MockTransport(behavior: .success)

// Always fail
MockTransport(behavior: .failure(EmailError.authFailed(provider: .ses, underlying: nil)))

// Delay then succeed
MockTransport(behavior: .delay(.milliseconds(500), then: .success))
```

## API Reference

### Core Types

#### `EmailAddress`
```swift
EmailAddress(_ email: String, name: String? = nil)
```

#### `EmailMessage`
```swift
EmailMessage(
    from: EmailAddress,
    to: [EmailAddress],
    subject: String,
    text: String? = nil,
    html: String? = nil,
    cc: [EmailAddress] = [],
    bcc: [EmailAddress] = [],
    replyTo: EmailAddress? = nil,
    headers: [String: String] = [:],
    idempotencyKey: String? = nil
)
```

#### `SendResponse`
```swift
struct SendResponse {
    let provider: Provider
    let providerMessageId: String?
    let accepted: Bool
    let remoteStatus: String?
    let requestId: String
}
```

### Providers

#### Amazon SES

```swift
SESConfig(
    accessKeyId: String,
    secretAccessKey: String,
    region: String,
    endpoint: URL? = nil,
    sessionToken: String? = nil
)

SESTransport(config: SESConfig, session: URLSession = .shared)
```

**Supported Regions**: All AWS regions that support SES
**Authentication**: AWS Signature Version 4
**API Version**: SES v2

## Error Handling

```swift
do {
    let response = try await client.send(message, params: nil, context: nil)
} catch EmailError.invalidMessage(let msg) {
    print("Invalid message: \(msg)")
} catch EmailError.authFailed(let provider, let error) {
    print("Auth failed for \(provider): \(error)")
} catch EmailError.rateLimited(let provider, let retryAfter) {
    print("Rate limited by \(provider), retry after \(retryAfter)")
} catch EmailError.network(let error) {
    print("Network error: \(error)")
} catch EmailError.provider(let provider, let code, let desc) {
    print("Provider error (\(provider)) [\(code)]: \(desc)")
}
```

## Roadmap

### v0.1 (Current) ✅
- Core API and models
- Amazon SES transport
- Parameter interpolation
- Retry policies
- Middleware support
- Mock transport for testing

### v0.2 (Planned)
- SendGrid transport
- Azure Communication Services transport
- Attachment support
- Batch send operations

### v0.3 (Future)
- Provider-native templates
- Webhook support for delivery events
- Advanced routing strategies

## Requirements

- Swift 6.0+
- macOS 12.0+ / iOS 15.0+ / tvOS 15.0+ / watchOS 8.0+ / Linux

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See LICENSE file for details.

## Acknowledgments

- SigV4 implementation inspired by [storage-api-lite](https://github.com/mirfanbashir/storage-api-lite)
- Design follows Swift API guidelines and modern concurrency patterns
 
