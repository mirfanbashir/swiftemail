import Foundation
import Core
import Providers

/// Example usage of SwiftEmail SDK
@main
struct ExampleApp {
    static func main() async throws {
        print("🚀 SwiftEmail SDK Example\n")
        
        // Example 1: Basic email with SES
        try await exampleBasicEmail()
        
        // Example 2: Email with parameter interpolation
        try await exampleWithInterpolation()
        
        // Example 3: Email with custom middleware
        try await exampleWithMiddleware()
        
        print("\n✅ All examples completed!")
    }
    
    static func exampleBasicEmail() async throws {
        print("📧 Example 1: Basic Email")
        print("-------------------------")
        
        // Configure SES (using mock for this example)
        let config = SESConfig(
            accessKeyId: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            region: "us-east-1",
            httpLogging: .minimal  // Enable HTTP logging
        )
        
        // For demonstration, we'll use mock transport
        // In production: let transport = SESTransport(config: config)
        let transport = Testing.MockTransport(behavior: .success)
        
        let client = SimpleEmailClient(transport: transport)
        
        let message = EmailMessage(
            from: EmailAddress("noreply@example.com", name: "Example App"),
            to: [EmailAddress("user@example.com", name: "Test User")],
            subject: "Welcome to SwiftEmail!",
            text: "Thank you for using SwiftEmail SDK.",
            html: "<h1>Welcome!</h1><p>Thank you for using SwiftEmail SDK.</p>"
        )
        
        let response = try await client.send(message, params: nil, context: nil)
        print("✓ Email sent successfully!")
        print("  Provider: \(response.provider)")
        print("  Message ID: \(response.providerMessageId ?? "N/A")")
        print("")
    }
    
    static func exampleWithInterpolation() async throws {
        print("📧 Example 2: Email with Parameter Interpolation")
        print("------------------------------------------------")
        
        let transport = Testing.MockTransport(behavior: .success)
        let client = SimpleEmailClient(transport: transport)
        
        let message = EmailMessage(
            from: EmailAddress("noreply@example.com"),
            to: [EmailAddress("alice@example.com")],
            subject: "Hello {{firstName}}!",
            text: "Your verification code is {{code}}. Valid for {{validMinutes}} minutes.",
            html: """
                <h1>Hello {{firstName}}!</h1>
                <p>Your verification code is: <strong>{{code}}</strong></p>
                <p>Valid for {{validMinutes}} minutes.</p>
            """
        )
        
        let params = [
            "firstName": "Alice",
            "code": "123456",
            "validMinutes": "15"
        ]
        
        let response = try await client.send(message, params: params, context: nil)
        print("✓ Email with interpolation sent!")
        print("  Parameters used: \(params.keys.joined(separator: ", "))")
        
        // Show the interpolated message
        let sentMessage = await transport.getLastMessage()
        print("  Subject: \(sentMessage?.subject ?? "")")
        print("")
    }
    
    static func exampleWithMiddleware() async throws {
        print("📧 Example 3: Email with Custom Middleware")
        print("------------------------------------------")
        
        let transport = Testing.MockTransport(behavior: .success)
        
        // Use the built-in console logger
        let logger = ConsoleLoggerMiddleware()
        
        let client = SimpleEmailClient(
            transport: transport,
            retryPolicy: .exponentialJitter(maxAttempts: 3),
            middlewares: [logger]
        )
        
        let message = EmailMessage(
            from: EmailAddress("system@example.com"),
            to: [
                EmailAddress("user1@example.com"),
                EmailAddress("user2@example.com")
            ],
            cc: [EmailAddress("manager@example.com")],
            subject: "System Notification",
            text: "This is a system notification.",
            replyTo: EmailAddress("support@example.com")
        )
        
        let context = SendContext(
            timeout: .seconds(30),
            traceId: "trace-\(UUID().uuidString)"
        )
        
        let response = try await client.send(message, params: nil, context: context)
        print("✓ Email with middleware sent!")
        print("  Recipients: \(message.to.count) direct, \(message.cc.count) CC")
        print("")
    }
}
