import XCTest
@testable import MuscatKit

/// The stream URL carries its token in the query string and `AVPlayer` uses that
/// string for the life of the item, so knowing when a token is about to expire is
/// the difference between music that keeps playing and music that stops partway
/// through a session with NSURLErrorUserAuthenticationRequired.
final class TokenExpiryTests: XCTestCase {
    private func jwt(expiringIn seconds: TimeInterval) -> String {
        let payload = #"{"sub":"u1","exp":\#(Int(Date().addingTimeInterval(seconds).timeIntervalSince1970))}"#
        let b64 = Data(payload.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "header.\(b64).signature"
    }

    func testReadsTheExpiryOutOfAToken() {
        let expiry = APIClient.expiry(ofJWT: jwt(expiringIn: 900))
        XCTAssertNotNil(expiry)
        XCTAssertEqual(expiry!.timeIntervalSinceNow, 900, accuracy: 5)
    }

    /// Base64url payloads are usually not a multiple of four characters; a decoder
    /// that doesn't pad them reads nothing and every token looks eternal.
    func testHandlesUnpaddedBase64url() {
        for length in 1...40 {
            let payload = #"{"exp":1789000000,"pad":"\#(String(repeating: "x", count: length))"}"#
            let b64 = Data(payload.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            XCTAssertNotNil(APIClient.expiry(ofJWT: "h.\(b64).s"), "failed at padding length \(length)")
        }
    }

    func testRefusesSomethingThatIsNotAToken() {
        XCTAssertNil(APIClient.expiry(ofJWT: "not-a-token"))
        XCTAssertNil(APIClient.expiry(ofJWT: "one.two"))
        XCTAssertNil(APIClient.expiry(ofJWT: "h.!!!not-base64!!!.s"))
    }

    func testATokenWithNoExpiryClaimIsNotTreatedAsExpired() {
        let b64 = Data(#"{"sub":"u1"}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        XCTAssertNil(APIClient.expiry(ofJWT: "h.\(b64).s"))
    }
}
