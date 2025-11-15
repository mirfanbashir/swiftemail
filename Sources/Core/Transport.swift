import Foundation

/// Protocol for email transport implementations
public protocol Transport: Sendable {
    /// Send an email message
    /// - Parameters:
    ///   - message: The email message to send
    ///   - context: Optional context for the send operation
    /// - Returns: Response from the email provider
    /// - Throws: EmailError if the send fails
    func send(_ message: EmailMessage, context: SendContext?) async throws -> SendResponse
}
