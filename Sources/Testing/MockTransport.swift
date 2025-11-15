import Foundation
@testable import Core

/// Mock transport for testing email functionality
public actor MockTransport: Transport {
    
    public enum MockBehavior: Sendable {
        case success
        case failure(EmailError)
        indirect case delay(Duration, then: MockBehavior)
    }
    
    private var behavior: MockBehavior
    private(set) var sentMessages: [EmailMessage] = []
    private(set) var sendCount: Int = 0
    
    public init(behavior: MockBehavior = .success) {
        self.behavior = behavior
    }
    
    public func send(_ message: EmailMessage, context: SendContext?) async throws -> SendResponse {
        sentMessages.append(message)
        sendCount += 1
        
        return try await handleBehavior(behavior, message: message, context: context)
    }
    
    private func handleBehavior(_ behavior: MockBehavior, message: EmailMessage, context: SendContext?) async throws -> SendResponse {
        switch behavior {
        case .success:
            return SendResponse(
                provider: .ses,
                providerMessageId: "mock-\(UUID().uuidString)",
                accepted: true,
                remoteStatus: "200",
                requestId: "mock-request-\(UUID().uuidString)"
            )
            
        case .failure(let error):
            throw error
            
        case .delay(let duration, let nextBehavior):
            try await Task.sleep(for: duration)
            return try await handleBehavior(nextBehavior, message: message, context: context)
        }
    }
    
    public func reset() {
        sentMessages.removeAll()
        sendCount = 0
    }
    
    public func setBehavior(_ newBehavior: MockBehavior) {
        behavior = newBehavior
    }
    
    public func getLastMessage() -> EmailMessage? {
        return sentMessages.last
    }
    
    public func getAllMessages() -> [EmailMessage] {
        return sentMessages
    }
}
