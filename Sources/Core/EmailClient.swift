import Foundation

// MARK: - Email Client Protocol

/// Protocol for sending emails
public protocol EmailClient: Sendable {
    /// Send an email with optional parameter interpolation
    /// - Parameters:
    ///   - message: The email message to send
    ///   - params: Optional parameters for {{placeholder}} interpolation
    ///   - context: Optional context for the send operation
    /// - Returns: Response from the email provider
    /// - Throws: EmailError if the send fails
    func send(_ message: EmailMessage, params: [String: String]?, context: SendContext?) async throws -> SendResponse
}

// MARK: - Simple Email Client

/// Simple email client that binds to exactly one provider transport
public struct SimpleEmailClient: EmailClient {
    let transport: Transport
    let interpolate: @Sendable (EmailMessage, [String: String]?) throws -> EmailMessage
    let retryPolicy: RetryPolicy
    let middlewares: [Middleware]
    
    public init(
        transport: Transport,
        retryPolicy: RetryPolicy = .exponentialJitter(maxAttempts: 3),
        middlewares: [Middleware] = [],
        interpolate: @escaping @Sendable (EmailMessage, [String: String]?) throws -> EmailMessage = Interpolation.default
    ) {
        self.transport = transport
        self.retryPolicy = retryPolicy
        self.middlewares = middlewares
        self.interpolate = interpolate
    }
    
    public func send(_ message: EmailMessage, params: [String: String]? = nil, context: SendContext? = nil) async throws -> SendResponse {
        // Validate message
        try message.validate()
        
        // Interpolate parameters
        let resolved = try interpolate(message, params)
        
        // Notify middleware
        let provider = getProviderType()
        for middleware in middlewares {
            await middleware.willSend(message: resolved, provider: provider)
        }
        
        // Send with retry policy
        let result: Result<SendResponse, Error>
        do {
            let response = try await sendWithRetry(resolved, context: context)
            result = .success(response)
            
            // Notify middleware of success
            for middleware in middlewares {
                await middleware.didSend(result: result)
            }
            
            return response
        } catch {
            result = .failure(error)
            
            // Notify middleware of failure
            for middleware in middlewares {
                await middleware.didSend(result: result)
            }
            
            throw error
        }
    }
    
    private func sendWithRetry(_ message: EmailMessage, context: SendContext?) async throws -> SendResponse {
        var lastError: Error?
        
        for attempt in 1...retryPolicy.maxAttempts {
            do {
                return try await transport.send(message, context: context)
            } catch {
                lastError = error
                
                // Check if we should retry
                guard attempt < retryPolicy.maxAttempts && retryPolicy.retryOn(error) else {
                    throw error
                }
                
                // Calculate and apply delay
                let delay = retryPolicy.delay(for: attempt)
                if delay > .zero {
                    try await Task.sleep(for: delay)
                }
            }
        }
        
        throw lastError ?? EmailError.network(underlying: NSError(domain: "SwiftEmail", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
    }
    
    private func getProviderType() -> SendResponse.Provider {
        // Try to determine provider type from transport
        // For now, we'll default to .ses since that's what we're implementing
        return .ses
    }
}
