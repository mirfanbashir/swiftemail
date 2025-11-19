import XCTest
@testable import SwiftEmailCore
@testable import SwiftEmailProviders
@testable import SwiftEmailMocks

final class SwiftEmailTests: XCTestCase {
    
    func testEmailAddressValidation() {
        let validEmail = EmailAddress("test@example.com", name: "Test User")
        XCTAssertTrue(validEmail.isValid)
        
        let invalidEmail = EmailAddress("not-an-email", name: "Test")
        XCTAssertFalse(invalidEmail.isValid)
    }
    
    func testMockTransportSuccess() async throws {
        let transport = MockTransport(behavior: .success)
        
        let message = EmailMessage(
            from: EmailAddress("sender@example.com"),
            to: [EmailAddress("recipient@example.com")],
            subject: "Test",
            text: "Body"
        )
        
        let response = try await transport.send(message, context: SendContext())
        
        XCTAssertTrue(response.accepted)
        XCTAssertEqual(response.provider, .ses)
    }
    
    func testEmailMessageValidation() throws {
        // Valid message
        let validMessage = EmailMessage(
            from: EmailAddress("sender@example.com"),
            to: [EmailAddress("recipient@example.com")],
            subject: "Test Subject",
            text: "Test body"
        )
        XCTAssertNoThrow(try validMessage.validate())
        
        // Invalid - empty recipients
        let noRecipients = EmailMessage(
            from: EmailAddress("sender@example.com"),
            to: [],
            subject: "Test",
            text: "Body"
        )
        XCTAssertThrowsError(try noRecipients.validate()) { error in
            guard case EmailError.invalidMessage = error else {
                return XCTFail("Expected invalidMessage error")
            }
        }
        
        // Invalid - empty subject
        let emptySubject = EmailMessage(
            from: EmailAddress("sender@example.com"),
            to: [EmailAddress("recipient@example.com")],
            subject: "",
            text: "Body"
        )
        XCTAssertThrowsError(try emptySubject.validate()) { error in
            guard case EmailError.invalidMessage = error else {
                return XCTFail("Expected invalidMessage error")
            }
        }
    }
    
    func testMockTransportFailure() async throws {
        let transport = MockTransport(behavior: .failure(.provider(provider: .ses, code: "500", description: "Internal Error")))
        
        let message = EmailMessage(
            from: EmailAddress("sender@example.com"),
            to: [EmailAddress("recipient@example.com")],
            subject: "Test",
            text: "Body"
        )
        
        do {
            _ = try await transport.send(message, context: SendContext())
            XCTFail("Expected error to be thrown")
        } catch {
            guard case EmailError.provider = error else {
                return XCTFail("Expected provider error")
            }
        }
    }
    
    func testParameterInterpolation() throws {
        let message = EmailMessage(
            from: EmailAddress("sender@example.com"),
            to: [EmailAddress("recipient@example.com")],
            subject: "Hello {{name}}",
            text: "Welcome to {{company}}!"
        )
        let params = ["name": "John", "company": "Acme Corp"]
        
        let result = try Interpolation.default(message, params)
        XCTAssertEqual(result.subject, "Hello John")
        XCTAssertEqual(result.text, "Welcome to Acme Corp!")
    }
    
    func testParameterInterpolationWithMissingKey() throws {
        let message = EmailMessage(
            from: EmailAddress("sender@example.com"),
            to: [EmailAddress("recipient@example.com")],
            subject: "Hello {{name}}",
            text: "Your code is {{code}}"
        )
        let params = ["name": "John"]
        
        let result = try Interpolation.default(message, params)
        XCTAssertEqual(result.subject, "Hello John")
        XCTAssertEqual(result.text, "Your code is {{code}}")
    }
}
