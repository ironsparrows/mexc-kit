import Crypto
import Foundation

/// Signs private REST requests: HMAC-SHA256 of `apiKey + requestTime + parameters`, keyed with the
/// secret, as lowercase hex.
///
/// `parameters` is the sorted query string of a GET request, or the JSON body of a POST
/// request, exactly as sent.
struct RequestSigner {
    let credentials: MexcCredentials

    func signature(requestTime: String, parameters: String) -> String {
        let key = SymmetricKey(data: Data(credentials.secret.utf8))
        let message = Data((credentials.apiKey + requestTime + parameters).utf8)
        let code = HMAC<SHA256>.authenticationCode(for: message, using: key)
        return code.map { byte in
            let hex = String(byte, radix: 16)
            return byte < 0x10 ? "0" + hex : hex
        }.joined()
    }
}
