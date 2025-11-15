import Foundation

// MARK: - Retry Policy

/// Retry policy for handling transient failures
public struct RetryPolicy: Sendable {
    public var maxAttempts: Int
    public var baseDelay: Duration
    public var jitter: Bool
    public var retryOn: @Sendable (Error) -> Bool
    
    public init(
        maxAttempts: Int,
        baseDelay: Duration,
        jitter: Bool,
        retryOn: @escaping @Sendable (Error) -> Bool
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.jitter = jitter
        self.retryOn = retryOn
    }
    
    /// Creates an exponential backoff retry policy with jitter
    public static func exponentialJitter(maxAttempts: Int = 3) -> RetryPolicy {
        .init(
            maxAttempts: maxAttempts,
            baseDelay: .milliseconds(250),
            jitter: true,
            retryOn: { error in
                // Retry on network errors and rate limits
                if let emailError = error as? EmailError {
                    switch emailError {
                    case .network, .rateLimited:
                        return true
                    default:
                        return false
                    }
                }
                return true // Retry on unknown errors
            }
        )
    }
    
    /// No retry policy
    public static var noRetry: RetryPolicy {
        .init(
            maxAttempts: 1,
            baseDelay: .zero,
            jitter: false,
            retryOn: { _ in false }
        )
    }
    
    /// Calculate delay for a given attempt
    func delay(for attempt: Int) -> Duration {
        guard attempt > 0 else { return .zero }
        
        // Exponential backoff: baseDelay * 2^(attempt-1)
        let multiplier = Int(pow(2.0, Double(attempt - 1)))
        var delay = baseDelay * multiplier
        
        // Add jitter if enabled (0-50% of delay)
        if jitter {
            let jitterAmount = Double.random(in: 0...0.5)
            let nanoseconds = delay.components.seconds * 1_000_000_000 + delay.components.attoseconds / 1_000_000_000
            let jitteredNanoseconds = Int64(Double(nanoseconds) * (1.0 + jitterAmount))
            delay = Duration(secondsComponent: jitteredNanoseconds / 1_000_000_000, attosecondsComponent: (jitteredNanoseconds % 1_000_000_000) * 1_000_000_000)
        }
        
        return delay
    }
}

// MARK: - HTTP Logging

/// HTTP request/response logging configuration
public struct HTTPLoggingConfig: Sendable {
    public enum LogLevel: Sendable {
        case none
        case minimal      // Just URL and status code
        case headers      // URL, status, headers
        case body         // URL, status, headers, body
        case verbose      // Everything including timing
    }
    
    public let level: LogLevel
    public let redactedHeaders: Set<String>
    public let maxBodyBytes: Int
    
    public init(
        level: LogLevel = .none,
        redactedHeaders: Set<String> = ["Authorization", "x-amz-security-token"],
        maxBodyBytes: Int = 10_000
    ) {
        self.level = level
        self.redactedHeaders = redactedHeaders
        self.maxBodyBytes = maxBodyBytes
    }
    
    public static let disabled = HTTPLoggingConfig(level: .none)
    public static let minimal = HTTPLoggingConfig(level: .minimal)
    public static let headers = HTTPLoggingConfig(level: .headers)
    public static let body = HTTPLoggingConfig(level: .body)
    public static let verbose = HTTPLoggingConfig(level: .verbose)
}

/// HTTP request/response logger
public struct HTTPLogger: Sendable {
    private let config: HTTPLoggingConfig
    
    public init(config: HTTPLoggingConfig = .disabled) {
        self.config = config
    }
    
    public func logRequest(
        method: String,
        url: URL,
        headers: [String: String],
        body: Data?
    ) {
        guard config.level != .none else { return }
        
        print("\n🔵 [HTTP Request]")
        print("   \(method) \(url.absoluteString)")
        
        if config.level == .headers || config.level == .body || config.level == .verbose {
            print("   Headers:")
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                if config.redactedHeaders.contains(key) {
                    print("      \(key): [REDACTED]")
                } else {
                    print("      \(key): \(value)")
                }
            }
        }
        
        if (config.level == .body || config.level == .verbose), let body = body {
            print("   Body (\(body.count) bytes):")
            if body.count <= config.maxBodyBytes {
                if let bodyString = String(data: body, encoding: .utf8) {
                    print("      \(bodyString)")
                } else {
                    print("      [Binary data]")
                }
            } else {
                print("      [Body too large, showing first \(config.maxBodyBytes) bytes]")
                let truncated = body.prefix(config.maxBodyBytes)
                if let bodyString = String(data: truncated, encoding: .utf8) {
                    print("      \(bodyString)...")
                }
            }
        }
    }
    
    public func logResponse(
        statusCode: Int,
        headers: [AnyHashable: Any],
        body: Data?,
        duration: TimeInterval? = nil
    ) {
        guard config.level != .none else { return }
        
        let statusEmoji = statusCode >= 200 && statusCode < 300 ? "🟢" : "🔴"
        print("\n\(statusEmoji) [HTTP Response]")
        print("   Status: \(statusCode)")
        
        if let duration = duration, config.level == .verbose {
            print("   Duration: \(String(format: "%.3f", duration))s")
        }
        
        if config.level == .headers || config.level == .body || config.level == .verbose {
            print("   Headers:")
            for (key, value) in headers.sorted(by: { "\($0.key)" < "\($1.key)" }) {
                let keyString = "\(key)"
                if config.redactedHeaders.contains(keyString) {
                    print("      \(keyString): [REDACTED]")
                } else {
                    print("      \(keyString): \(value)")
                }
            }
        }
        
        if (config.level == .body || config.level == .verbose), let body = body {
            print("   Body (\(body.count) bytes):")
            if body.count <= config.maxBodyBytes {
                if let bodyString = String(data: body, encoding: .utf8) {
                    print("      \(bodyString)")
                } else {
                    print("      [Binary data]")
                }
            } else {
                print("      [Body too large, showing first \(config.maxBodyBytes) bytes]")
                let truncated = body.prefix(config.maxBodyBytes)
                if let bodyString = String(data: truncated, encoding: .utf8) {
                    print("      \(bodyString)...")
                }
            }
        }
        print("") // Empty line for readability
    }
}

// MARK: - Middleware

/// Middleware for observing email send operations
public protocol Middleware: Sendable {
    /// Called before sending an email
    func willSend(message: EmailMessage, provider: SendResponse.Provider) async
    
    /// Called after sending an email (success or failure)
    func didSend(result: Result<SendResponse, Error>) async
}

/// Console logging middleware
public struct ConsoleLoggerMiddleware: Middleware {
    public init() {}
    
    public func willSend(message: EmailMessage, provider: SendResponse.Provider) async {
        print("📧 [SwiftEmail] Sending email via \(provider):")
        print("   From: \(message.from.email)")
        print("   To: \(message.to.map(\.email).joined(separator: ", "))")
        print("   Subject: \(message.subject)")
    }
    
    public func didSend(result: Result<SendResponse, Error>) async {
        switch result {
        case .success(let response):
            print("✅ [SwiftEmail] Email sent successfully:")
            print("   Provider: \(response.provider)")
            print("   Message ID: \(response.providerMessageId ?? "N/A")")
            print("   Request ID: \(response.requestId)")
        case .failure(let error):
            print("❌ [SwiftEmail] Email send failed:")
            print("   Error: \(error)")
        }
    }
}
