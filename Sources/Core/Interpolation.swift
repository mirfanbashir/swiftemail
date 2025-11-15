import Foundation

/// Parameter interpolation for email templates
public struct Interpolation: Sendable {
    
    /// Default interpolation function that replaces {{key}} tokens
    public static let `default`: @Sendable (EmailMessage, [String: String]?) throws -> EmailMessage = { message, params in
        guard let params = params, !params.isEmpty else {
            return message
        }
        
        var interpolated = message
        
        // Interpolate subject
        interpolated.subject = try interpolateString(message.subject, params: params)
        
        // Interpolate text body
        if let text = message.text {
            interpolated.text = try interpolateString(text, params: params)
        }
        
        // Interpolate HTML body
        if let html = message.html {
            interpolated.html = try interpolateString(html, params: params)
        }
        
        return interpolated
    }
    
    /// Interpolates {{key}} tokens in a string
    /// - Parameters:
    ///   - string: The string to interpolate
    ///   - params: Parameters to replace
    /// - Returns: Interpolated string
    /// - Throws: EmailError if interpolation fails
    private static func interpolateString(_ string: String, params: [String: String]) throws -> String {
        var result = string
        
        // Regex to match {{key}} with optional whitespace (trimmed)
        let pattern = #"\{\{\s*([a-zA-Z0-9_]+)\s*\}\}"#
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        
        let nsString = string as NSString
        let matches = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))
        
        // Process matches in reverse order to preserve ranges
        for match in matches.reversed() {
            let fullRange = match.range
            let keyRange = match.range(at: 1)
            
            guard keyRange.location != NSNotFound else {
                continue
            }
            
            let key = nsString.substring(with: keyRange)
            
            // If key exists in params, replace it; otherwise leave token as-is
            if let value = params[key] {
                let fullMatch = nsString.substring(with: fullRange)
                result = (result as NSString).replacingOccurrences(
                    of: fullMatch,
                    with: value,
                    options: [],
                    range: fullRange
                )
            }
        }
        
        return result
    }
}
