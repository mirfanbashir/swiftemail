import Foundation
import SwiftEmailCore
import SwiftEmailProviders

/// Example demonstrating HTTP request/response logging
func exampleHTTPLogging() async throws {
    print("🔍 HTTP Logging Examples\n")
    
    // Example 1: Minimal logging (just URL and status)
    print("1️⃣ Minimal Logging (URL + Status)")
    print("=" * 50)
    let minimalConfig = SESConfig(
        accessKeyId: "AKIAIOSFODNN7EXAMPLE",
        secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        region: "us-east-1",
        httpLogging: .minimal
    )
    print("✅ Configured\n")
    
    // Example 2: Headers logging (includes all headers)
    print("2️⃣ Headers Logging (URL + Status + Headers)")
    print("=" * 50)
    let headersConfig = SESConfig(
        accessKeyId: "AKIAIOSFODNN7EXAMPLE",
        secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        region: "us-east-1",
        httpLogging: .headers
    )
    print("✅ Configured")
    print("Note: Sensitive headers like 'Authorization' are redacted by default\n")
    
    // Example 3: Body logging (includes request/response bodies)
    print("3️⃣ Body Logging (Everything + Bodies)")
    print("=" * 50)
    let bodyConfig = SESConfig(
        accessKeyId: "AKIAIOSFODNN7EXAMPLE",
        secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        region: "us-east-1",
        httpLogging: .body
    )
    print("✅ Configured")
    print("Shows JSON request/response bodies (up to 10KB by default)\n")
    
    // Example 4: Verbose logging (includes timing)
    print("4️⃣ Verbose Logging (Everything + Timing)")
    print("=" * 50)
    let verboseConfig = SESConfig(
        accessKeyId: "AKIAIOSFODNN7EXAMPLE",
        secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        region: "us-east-1",
        httpLogging: .verbose
    )
    print("✅ Configured")
    print("Includes request duration in seconds\n")
    
    // Example 5: Custom logging configuration
    print("5️⃣ Custom Logging Configuration")
    print("=" * 50)
    let customLoggingConfig = HTTPLoggingConfig(
        level: .body,
        redactedHeaders: ["Authorization", "x-amz-security-token", "x-api-key"],
        maxBodyBytes: 5000  // Limit body output to 5KB
    )
    let customConfig = SESConfig(
        accessKeyId: "AKIAIOSFODNN7EXAMPLE",
        secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        region: "us-east-1",
        httpLogging: customLoggingConfig
    )
    print("✅ Configured")
    print("Custom redacted headers: Authorization, x-amz-security-token, x-api-key")
    print("Max body size: 5000 bytes\n")
    
    // Example output format explanation
    print("📝 Example Output Format")
    print("=" * 50)
    print("""
    When sending an email with verbose logging enabled, you'll see:
    
    🔵 [HTTP Request]
       POST https://email.us-east-1.amazonaws.com/v2/email/outbound-emails
       Headers:
          Content-Type: application/json
          Authorization: [REDACTED]
          x-amz-date: 20251115T120000Z
          host: email.us-east-1.amazonaws.com
       Body (234 bytes):
          {"Content":{"Simple":{"Subject":{"Data":"Test"}...}}
    
    🟢 [HTTP Response]
       Status: 200
       Duration: 0.456s
       Headers:
          content-type: application/json
          x-amzn-RequestId: abc123...
       Body (67 bytes):
          {"MessageId":"0102..."}
    
    """)
    
    print("💡 Tips:")
    print("- Use .minimal in production for basic debugging")
    print("- Use .verbose during development for detailed troubleshooting")
    print("- Use .body when you need to inspect API payloads")
    print("- Sensitive headers are automatically redacted for security")
    print("- Large bodies are truncated to prevent console overflow")
}

// Run the example
Task {
    try await exampleHTTPLogging()
}
