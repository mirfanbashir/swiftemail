import Testing
import Foundation
@testable import SwiftEmailCore
@testable import SwiftEmailProviders
@testable import SwiftEmailTesting

@Test("Email address validation works correctly")
func testEmailAddressValidation() {
    let validEmail = EmailAddress("test@example.com", name: "Test User")
    #expect(validEmail.isValid == true)
    
    let invalidEmail = EmailAddress("not-an-email", name: "Test")
    #expect(invalidEmail.isValid == false)
}

@Test("Mock transport succeeds when configured")
func testMockTransportSuccess() async throws {
    let transport = MockTransport(behavior: .success)
    
    let message = EmailMessage(
        from: EmailAddress("sender@example.com"),
        to: [EmailAddress("recipient@example.com")],
        subject: "Test",
        text: "Body"
    )
    
    let response = try await transport.send(message, context: nil)
    
    #expect(response.accepted == true)
    #expect(response.provider == .ses)
}
