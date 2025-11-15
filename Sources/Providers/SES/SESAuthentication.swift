import Foundation

#if canImport(CommonCrypto)
import CommonCrypto
#endif

#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - Cross-Platform Crypto Implementation

internal struct CrossPlatformCrypto {
    
    static func sha256Hash(data: Data) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
        #elseif canImport(CommonCrypto)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
        #else
        // Fallback implementation for Linux using Foundation
        return sha256Fallback(data: data)
        #endif
    }
    
    static func hmacSHA256(data: Data, key: Data) -> Data {
        #if canImport(CryptoKit)
        let symmetricKey = SymmetricKey(data: key)
        let authenticationCode = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(authenticationCode)
        #elseif canImport(CommonCrypto)
        var result = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        key.withUnsafeBytes { keyBytes in
            data.withUnsafeBytes { dataBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, key.count, dataBytes.baseAddress, data.count, &result)
            }
        }
        return Data(result)
        #else
        return hmacSHA256Fallback(data: data, key: key)
        #endif
    }
    
    // MARK: - Fallback implementations for platforms without CommonCrypto or CryptoKit
    
    private static func sha256Fallback(data: Data) -> String {
        var h: [UInt32] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        ]
        
        let k: [UInt32] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
        ]
        
        var message = [UInt8](data)
        let originalLength = message.count
        
        // Padding
        message.append(0x80)
        while message.count % 64 != 56 {
            message.append(0x00)
        }
        
        // Append original length in bits as 64-bit big-endian
        let lengthInBits = UInt64(originalLength * 8)
        for i in stride(from: 56, through: 0, by: -8) {
            message.append(UInt8((lengthInBits >> i) & 0xFF))
        }
        
        // Process chunks
        for chunkStart in stride(from: 0, to: message.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 64)
            
            // Copy chunk into first 16 words of message schedule
            for i in 0..<16 {
                let offset = chunkStart + i * 4
                w[i] = (UInt32(message[offset]) << 24) |
                       (UInt32(message[offset + 1]) << 16) |
                       (UInt32(message[offset + 2]) << 8) |
                       UInt32(message[offset + 3])
            }
            
            // Extend the first 16 words into the remaining 48 words
            for i in 16..<64 {
                let s0 = rightRotate(w[i-15], 7) ^ rightRotate(w[i-15], 18) ^ (w[i-15] >> 3)
                let s1 = rightRotate(w[i-2], 17) ^ rightRotate(w[i-2], 19) ^ (w[i-2] >> 10)
                w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
            }
            
            // Initialize working variables
            var a = h[0], b = h[1], c = h[2], d = h[3]
            var e = h[4], f = h[5], g = h[6], h_ = h[7]
            
            // Compression function main loop
            for i in 0..<64 {
                let s1 = rightRotate(e, 6) ^ rightRotate(e, 11) ^ rightRotate(e, 25)
                let ch = (e & f) ^ (~e & g)
                let temp1 = h_ &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 = rightRotate(a, 2) ^ rightRotate(a, 13) ^ rightRotate(a, 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ maj
                
                h_ = g
                g = f
                f = e
                e = d &+ temp1
                d = c
                c = b
                b = a
                a = temp1 &+ temp2
            }
            
            // Add compressed chunk to current hash value
            h[0] = h[0] &+ a
            h[1] = h[1] &+ b
            h[2] = h[2] &+ c
            h[3] = h[3] &+ d
            h[4] = h[4] &+ e
            h[5] = h[5] &+ f
            h[6] = h[6] &+ g
            h[7] = h[7] &+ h_
        }
        
        // Produce final hash value as hex string
        return h.map { String(format: "%08x", $0) }.joined()
    }
    
    private static func rightRotate(_ value: UInt32, _ amount: UInt32) -> UInt32 {
        return (value >> amount) | (value << (32 - amount))
    }
    
    private static func hmacSHA256Fallback(data: Data, key: Data) -> Data {
        let blockSize = 64
        var keyData = [UInt8](key)
        
        // Pad or hash key if necessary
        if keyData.count > blockSize {
            let hashedKey = sha256Fallback(data: Data(keyData))
            keyData = hexStringToBytes(hashedKey)
        }
        
        while keyData.count < blockSize {
            keyData.append(0)
        }
        
        // Create inner and outer padding
        let innerPad = keyData.map { $0 ^ 0x36 }
        let outerPad = keyData.map { $0 ^ 0x5c }
        
        // Calculate inner hash
        let innerData = Data(innerPad) + data
        let innerHash = sha256Fallback(data: innerData)
        let innerBytes = hexStringToBytes(innerHash)
        
        // Calculate outer hash
        let outerData = Data(outerPad) + Data(innerBytes)
        let outerHash = sha256Fallback(data: outerData)
        let outerBytes = hexStringToBytes(outerHash)
        
        return Data(outerBytes)
    }
    
    private static func hexStringToBytes(_ hexString: String) -> [UInt8] {
        var bytes: [UInt8] = []
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            let byteString = String(hexString[index..<nextIndex])
            if let byte = UInt8(byteString, radix: 16) {
                bytes.append(byte)
            }
            index = nextIndex
        }
        return bytes
    }
}

// MARK: - AWS Signature Version 4

internal struct AWSSignatureV4 {
    let accessKey: String
    let secretKey: String
    let sessionToken: String?
    let region: String
    let service: String
    
    init(
        accessKey: String,
        secretKey: String,
        sessionToken: String? = nil,
        region: String,
        service: String = "ses"
    ) {
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.sessionToken = sessionToken
        self.region = region
        self.service = service
    }
    
    func signRequest(
        method: String,
        url: URL,
        headers: [String: String],
        payload: Data?
    ) -> [String: String] {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        let timestamp = dateFormatter.string(from: date)
        
        let shortDateFormatter = DateFormatter()
        shortDateFormatter.dateFormat = "yyyyMMdd"
        shortDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        let dateStamp = shortDateFormatter.string(from: date)
        
        var signedHeaders = headers
        signedHeaders["x-amz-date"] = timestamp
        signedHeaders["host"] = url.host ?? ""
        
        if let token = sessionToken {
            signedHeaders["x-amz-security-token"] = token
        }
        
        let payloadHash = CrossPlatformCrypto.sha256Hash(data: payload ?? Data())
        signedHeaders["x-amz-content-sha256"] = payloadHash
        
        let canonicalRequest = createCanonicalRequest(
            method: method,
            url: url,
            headers: signedHeaders,
            payloadHash: payloadHash
        )
        
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = createStringToSign(
            timestamp: timestamp,
            credentialScope: credentialScope,
            canonicalRequest: canonicalRequest
        )
        
        let signingKey = createSigningKey(
            secretKey: secretKey,
            dateStamp: dateStamp,
            region: region,
            service: service
        )
        
        let signature = CrossPlatformCrypto.hmacSHA256(data: stringToSign.data(using: .utf8)!, key: signingKey)
            .map { String(format: "%02x", $0) }.joined()
        
        let authorization = "AWS4-HMAC-SHA256 " +
            "Credential=\(accessKey)/\(credentialScope), " +
            "SignedHeaders=\(getSignedHeadersList(headers: signedHeaders)), " +
            "Signature=\(signature)"
        
        signedHeaders["Authorization"] = authorization
        return signedHeaders
    }
    
    private func createCanonicalRequest(
        method: String,
        url: URL,
        headers: [String: String],
        payloadHash: String
    ) -> String {
        let canonicalURI: String
        if url.path.isEmpty {
            canonicalURI = "/"
        } else {
            let pathComponents = url.path.split(separator: "/", omittingEmptySubsequences: false)
            let encodedComponents = pathComponents.map { component in
                String(component).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(component)
            }
            canonicalURI = "/" + encodedComponents.dropFirst().joined(separator: "/")
        }
        
        let canonicalQueryString = createCanonicalQueryString(url: url)
        let canonicalHeaders = createCanonicalHeaders(headers: headers)
        let signedHeaders = getSignedHeadersList(headers: headers)
        
        return [
            method,
            canonicalURI,
            canonicalQueryString,
            canonicalHeaders,
            "",
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")
    }
    
    private func createCanonicalQueryString(url: URL) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return ""
        }
        
        return queryItems
            .sorted { $0.name < $1.name }
            .map { item in
                let name = item.name.urlEncoded
                let value = item.value?.urlEncoded ?? ""
                return "\(name)=\(value)"
            }
            .joined(separator: "&")
    }
    
    private func createCanonicalHeaders(headers: [String: String]) -> String {
        let headerLines = headers
            .sorted { $0.key.lowercased() < $1.key.lowercased() }
            .map { "\($0.key.lowercased()):\($0.value.trimmingCharacters(in: .whitespaces))" }
        return headerLines.joined(separator: "\n")
    }
    
    private func getSignedHeadersList(headers: [String: String]) -> String {
        return headers.keys
            .map { $0.lowercased() }
            .sorted()
            .joined(separator: ";")
    }
    
    private func createStringToSign(
        timestamp: String,
        credentialScope: String,
        canonicalRequest: String
    ) -> String {
        let hashedCanonicalRequest = CrossPlatformCrypto.sha256Hash(data: canonicalRequest.data(using: .utf8)!)
        return [
            "AWS4-HMAC-SHA256",
            timestamp,
            credentialScope,
            hashedCanonicalRequest
        ].joined(separator: "\n")
    }
    
    private func createSigningKey(
        secretKey: String,
        dateStamp: String,
        region: String,
        service: String
    ) -> Data {
        let kDate = CrossPlatformCrypto.hmacSHA256(data: dateStamp.data(using: .utf8)!, key: "AWS4\(secretKey)".data(using: .utf8)!)
        let kRegion = CrossPlatformCrypto.hmacSHA256(data: region.data(using: .utf8)!, key: kDate)
        let kService = CrossPlatformCrypto.hmacSHA256(data: service.data(using: .utf8)!, key: kRegion)
        let kSigning = CrossPlatformCrypto.hmacSHA256(data: "aws4_request".data(using: .utf8)!, key: kService)
        return kSigning
    }
}

// MARK: - String Extension for URL Encoding

private extension String {
    var urlEncoded: String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return self.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? self
    }
}
