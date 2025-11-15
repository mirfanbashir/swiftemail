import Foundation
@testable import Core

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - SES Configuration

public struct SESConfig: Sendable {
    public let accessKeyId: String
    public let secretAccessKey: String
    public let region: String
    public let endpoint: URL?
    public let sessionToken: String?
    public let httpLogging: HTTPLoggingConfig
    
    public init(
        accessKeyId: String,
        secretAccessKey: String,
        region: String,
        endpoint: URL? = nil,
        sessionToken: String? = nil,
        httpLogging: HTTPLoggingConfig = .disabled
    ) {
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
        self.region = region
        self.endpoint = endpoint
        self.sessionToken = sessionToken
        self.httpLogging = httpLogging
    }
    
    /// Creates configuration from environment variables
    public static func fromEnvironment() throws -> SESConfig {
        guard let accessKeyId = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] else {
            throw EmailError.invalidMessage("Missing AWS_ACCESS_KEY_ID environment variable")
        }
        
        guard let secretAccessKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] else {
            throw EmailError.invalidMessage("Missing AWS_SECRET_ACCESS_KEY environment variable")
        }
        
        let region = ProcessInfo.processInfo.environment["AWS_REGION"] ?? "us-east-1"
        let sessionToken = ProcessInfo.processInfo.environment["AWS_SESSION_TOKEN"]
        
        var endpoint: URL?
        if let endpointString = ProcessInfo.processInfo.environment["AWS_SES_ENDPOINT"] {
            endpoint = URL(string: endpointString)
        }
        
        return SESConfig(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            region: region,
            endpoint: endpoint,
            sessionToken: sessionToken
        )
    }
}

// MARK: - SES Transport

public struct SESTransport: Transport {
    private let config: SESConfig
    private let urlSession: URLSession
    private let baseURL: String
    private let httpLogger: HTTPLogger
    
    public init(config: SESConfig, session: URLSession = .shared) {
        self.config = config
        self.urlSession = session
        self.httpLogger = HTTPLogger(config: config.httpLogging)
        
        if let endpoint = config.endpoint {
            self.baseURL = endpoint.absoluteString
        } else {
            self.baseURL = "https://email.\(config.region).amazonaws.com/v2/email/outbound-emails"
        }
    }
    
    public func send(_ message: EmailMessage, context: SendContext?) async throws -> SendResponse {
        // Build the request
        let url = URL(string: baseURL)!
        
        // Create SES v2 API request body
        let requestBody = try buildSESRequestBody(message)
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        // Prepare headers
        var headers: [String: String] = [
            "Content-Type": "application/json",
            "Content-Length": "\(bodyData.count)"
        ]
        
        // Add idempotency key if provided
        if let idempotencyKey = message.idempotencyKey {
            headers["X-Amzn-Idempotency-Token"] = idempotencyKey
        }
        
        // Sign the request using AWS SigV4
        let signer = AWSSignatureV4(
            accessKey: config.accessKeyId,
            secretKey: config.secretAccessKey,
            sessionToken: config.sessionToken,
            region: config.region,
            service: "ses"
        )
        
        let signedHeaders = signer.signRequest(
            method: "POST",
            url: url,
            headers: headers,
            payload: bodyData
        )
        
        // Create URL request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        
        for (key, value) in signedHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Apply timeout if specified
        if let timeout = context?.timeout {
            let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1_000_000_000_000_000_000.0
            request.timeoutInterval = seconds
        }
        
        // Log request if configured
        httpLogger.logRequest(
            method: "POST",
            url: url,
            headers: signedHeaders,
            body: bodyData
        )
        
        // Send the request
        let startTime = Date()
        let (data, response) = try await urlSession.data(for: request)
        let duration = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmailError.network(underlying: NSError(domain: "SwiftEmail", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]))
        }
        
        // Log response if configured
        httpLogger.logResponse(
            statusCode: httpResponse.statusCode,
            headers: httpResponse.allHeaderFields,
            body: data,
            duration: duration
        )
        
        // Parse response
        return try parseSESResponse(data: data, httpResponse: httpResponse, context: context)
    }
    
    private func buildSESRequestBody(_ message: EmailMessage) throws -> [String: Any] {
        var content: [String: Any] = [:]
        
        // Build simple content
        var simple: [String: Any] = [:]
        
        // Subject
        simple["Subject"] = [
            "Data": message.subject,
            "Charset": "UTF-8"
        ]
        
        // Body
        var body: [String: Any] = [:]
        
        if let text = message.text {
            body["Text"] = [
                "Data": text,
                "Charset": "UTF-8"
            ]
        }
        
        if let html = message.html {
            body["Html"] = [
                "Data": html,
                "Charset": "UTF-8"
            ]
        }
        
        simple["Body"] = body
        content["Simple"] = simple
        
        // Build destination
        var destination: [String: Any] = [:]
        destination["ToAddresses"] = message.to.map { formatEmailAddress($0) }
        
        if !message.cc.isEmpty {
            destination["CcAddresses"] = message.cc.map { formatEmailAddress($0) }
        }
        
        if !message.bcc.isEmpty {
            destination["BccAddresses"] = message.bcc.map { formatEmailAddress($0) }
        }
        
        // Build the main request
        var requestBody: [String: Any] = [
            "Content": content,
            "Destination": destination,
            "FromEmailAddress": formatEmailAddress(message.from)
        ]
        
        // Add reply-to if specified
        if let replyTo = message.replyTo {
            requestBody["ReplyToAddresses"] = [formatEmailAddress(replyTo)]
        }
        
        // Add custom headers if specified
        if !message.headers.isEmpty {
            var emailHeaders: [[String: String]] = []
            for (name, value) in message.headers {
                emailHeaders.append([
                    "Name": name,
                    "Value": value
                ])
            }
            requestBody["EmailTags"] = emailHeaders
        }
        
        return requestBody
    }
    
    private func formatEmailAddress(_ address: EmailAddress) -> String {
        if let name = address.name {
            // Encode the name if it contains special characters
            let encodedName = name.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(encodedName)\" <\(address.email)>"
        } else {
            return address.email
        }
    }
    
    private func parseSESResponse(data: Data, httpResponse: HTTPURLResponse, context: SendContext?) throws -> SendResponse {
        let requestId = httpResponse.value(forHTTPHeaderField: "x-amzn-RequestId") ?? UUID().uuidString
        
        switch httpResponse.statusCode {
        case 200...299:
            // Success
            var messageId: String?
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msgId = json["MessageId"] as? String {
                messageId = msgId
            }
            
            return SendResponse(
                provider: .ses,
                providerMessageId: messageId,
                accepted: true,
                remoteStatus: "\(httpResponse.statusCode)",
                requestId: requestId
            )
            
        case 401, 403:
            // Authentication error
            let errorMessage = parseErrorMessage(data: data)
            throw EmailError.authFailed(
                provider: .ses,
                underlying: NSError(domain: "SwiftEmail", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            )
            
        case 429:
            // Rate limit
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Int($0) }
                .map { Duration.seconds($0) }
            
            throw EmailError.rateLimited(provider: .ses, retryAfter: retryAfter)
            
        default:
            // Other error
            let errorMessage = parseErrorMessage(data: data)
            let errorCode = parseErrorCode(data: data)
            
            throw EmailError.provider(
                provider: .ses,
                code: errorCode,
                description: errorMessage
            )
        }
    }
    
    private func parseErrorMessage(data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? "Unknown error"
        }
        
        if let message = json["message"] as? String {
            return message
        } else if let message = json["Message"] as? String {
            return message
        }
        
        return "Unknown error"
    }
    
    private func parseErrorCode(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        if let code = json["__type"] as? String {
            return code
        } else if let code = json["Code"] as? String {
            return code
        }
        
        return nil
    }
}
