import Foundation

// MARK: - Email Address

/// Represents an email address with optional display name
public struct EmailAddress: Sendable, Hashable, Codable {
    public let name: String?
    public let email: String
    
    public init(_ email: String, name: String? = nil) {
        self.email = email
        self.name = name
    }
    
    /// Validates the email address format
    public var isValid: Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
}

// MARK: - Email Message

/// Minimal message model for v0.1 (no attachments/templates)
public struct EmailMessage: Sendable {
    public var from: EmailAddress
    public var to: [EmailAddress]
    public var cc: [EmailAddress]
    public var bcc: [EmailAddress]
    public var subject: String
    public var text: String?
    public var html: String?
    public var headers: [String: String]
    public var replyTo: EmailAddress?
    public var idempotencyKey: String?
    
    public init(
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
    ) {
        self.from = from
        self.to = to
        self.subject = subject
        self.text = text
        self.html = html
        self.cc = cc
        self.bcc = bcc
        self.replyTo = replyTo
        self.headers = headers
        self.idempotencyKey = idempotencyKey
    }
    
    /// Validates the message has required fields
    public func validate() throws {
        guard from.isValid else {
            throw EmailError.invalidMessage("Invalid 'from' email address: \(from.email)")
        }
        
        guard !to.isEmpty else {
            throw EmailError.invalidMessage("At least one recipient is required")
        }
        
        for recipient in to {
            guard recipient.isValid else {
                throw EmailError.invalidMessage("Invalid 'to' email address: \(recipient.email)")
            }
        }
        
        for recipient in cc {
            guard recipient.isValid else {
                throw EmailError.invalidMessage("Invalid 'cc' email address: \(recipient.email)")
            }
        }
        
        for recipient in bcc {
            guard recipient.isValid else {
                throw EmailError.invalidMessage("Invalid 'bcc' email address: \(recipient.email)")
            }
        }
        
        if let replyTo = replyTo {
            guard replyTo.isValid else {
                throw EmailError.invalidMessage("Invalid 'replyTo' email address: \(replyTo.email)")
            }
        }
        
        guard !subject.isEmpty else {
            throw EmailError.invalidMessage("Subject cannot be empty")
        }
        
        guard text != nil || html != nil else {
            throw EmailError.invalidMessage("Either text or html body must be provided")
        }
    }
}

// MARK: - Send Response

/// Response from sending an email
public struct SendResponse: Sendable {
    public enum Provider: String, Sendable {
        case ses
        case sendgrid
        case azure
    }
    
    public let provider: Provider
    public let providerMessageId: String?
    public let accepted: Bool
    public let remoteStatus: String?
    public let requestId: String
    
    public init(
        provider: Provider,
        providerMessageId: String?,
        accepted: Bool,
        remoteStatus: String?,
        requestId: String
    ) {
        self.provider = provider
        self.providerMessageId = providerMessageId
        self.accepted = accepted
        self.remoteStatus = remoteStatus
        self.requestId = requestId
    }
}

// MARK: - Send Context

/// Context for sending emails with optional timeout and tracing
public struct SendContext: Sendable {
    public var timeout: Duration?
    public var traceId: String?
    
    public init(timeout: Duration? = nil, traceId: String? = nil) {
        self.timeout = timeout
        self.traceId = traceId
    }
}

// MARK: - Email Error

/// Errors that can occur during email operations
public enum EmailError: Error, Sendable {
    case invalidMessage(String)
    case authFailed(provider: SendResponse.Provider, underlying: Error?)
    case rateLimited(provider: SendResponse.Provider, retryAfter: Duration?)
    case network(underlying: Error)
    case provider(provider: SendResponse.Provider, code: String?, description: String?)
    case interpolationFailed(String)
}

extension EmailError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidMessage(let message):
            return "Invalid message: \(message)"
        case .authFailed(let provider, let underlying):
            return "Authentication failed for \(provider): \(underlying?.localizedDescription ?? "unknown error")"
        case .rateLimited(let provider, let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited by \(provider), retry after \(retryAfter)"
            }
            return "Rate limited by \(provider)"
        case .network(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .provider(let provider, let code, let description):
            return "Provider error (\(provider)): [\(code ?? "unknown")] \(description ?? "no description")"
        case .interpolationFailed(let message):
            return "Parameter interpolation failed: \(message)"
        }
    }
}
