import Foundation

/// Reads MEXC's response envelope: `{"success": true, "code": 0, "data": …}` on success, and
/// `{"success": false, "code": 1001, "message": "…"}` on failure.
///
/// MEXC reports most failures with HTTP status 200, so the envelope decides, not the status. A few
/// endpoints leave out `success` and report success as `code` 0 or 200, and some name the message
/// `msg`.
enum Envelope {
    /// Decodes the response's `data`, or throws the ``MexcError`` the response reports.
    ///
    /// A status outside 200–299 always throws a ``MexcError``. Its code is the envelope's when the
    /// envelope reports a failure, and the HTTP status otherwise. A response that is neither a failure
    /// nor decodable throws `DecodingError`.
    @concurrent
    static func data<Response: Decodable & Sendable>(
        _: Response.Type, from response: TransportResponse
    ) async throws -> Response {
        let decoded = Result { try JSONDecoder().decode(Body<Response>.self, from: response.body) }
        let envelope = try? decoded.get()
        let reportsFailure = envelope?.succeeded == false
        if reportsFailure || !(200..<300).contains(response.status) {
            throw MexcError(
                code: MexcError.Code(rawValue: reportsFailure ? envelope?.code ?? response.status : response.status),
                message: envelope?.message,
                httpStatus: response.status,
                body: response.body
            )
        }
        return try decoded.get().data.get()
    }

    /// The envelope, read leniently: a field of an unexpected type is treated as absent, so a failure
    /// is still recognized, and `data` keeps its decoding error until it is needed.
    private struct Body<Value: Decodable>: Decodable {
        var success: Bool?
        var code: Int?
        var message: String?
        var data: Result<Value, any Error>

        /// Whether the envelope reports success: `success`, or else whether `code` is 0 or 200; `nil`
        /// when the body has neither.
        var succeeded: Bool? { success ?? code.map { $0 == 0 || $0 == 200 } }

        private enum CodingKeys: String, CodingKey {
            case success, code, message, msg, data
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            success = try? container.decode(Bool.self, forKey: .success)
            code = (try? container.decode(Int.self, forKey: .code))
                ?? (try? container.decode(String.self, forKey: .code)).flatMap { Int($0) }
            message = (try? container.decode(String.self, forKey: .message))
                ?? (try? container.decode(String.self, forKey: .msg))
            data = Result {
                // An endpoint without data reads none, whatever MEXC sends.
                if let nothing = NoData() as? Value { return nothing }
                return try container.decode(Value.self, forKey: .data)
            }
        }
    }
}

/// The response of an endpoint whose success has no `data` worth reading, such as
/// `{"success": true, "code": 0}`. Any `data` MEXC does send is ignored.
struct NoData: Decodable, Sendable {
    init() {}
    init(from decoder: any Decoder) {}
}
