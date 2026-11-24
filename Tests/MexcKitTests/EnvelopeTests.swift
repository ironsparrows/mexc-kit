import Foundation
import Testing
@testable import MexcKit

@Suite("Envelope")
struct EnvelopeTests {
    @Test(arguments: [
        #"{"success":true,"code":0,"data":42}"#,
        #"{"code":0,"data":42}"#,
        #"{"code":200,"msg":"success","data":42}"#,
        #"{"success":true,"code":200,"message":"ok","data":42}"#,
    ])
    func `a successful envelope yields its data`(json: String) async throws {
        #expect(try await Envelope.data(Int.self, from: response(json)) == 42)
    }

    @Test(arguments: [
        #"{"success":true,"code":0}"#,
        #"{"success":true,"code":0,"data":[]}"#,
        #"{"success":true,"code":0,"data":null}"#,
    ])
    func `an endpoint without data accepts a success with or without it`(json: String) async throws {
        _ = try await Envelope.data(NoData.self, from: response(json))
    }

    @Test func `an endpoint without data still throws a failure`() async throws {
        let error = try await mexcError(
            from: response(#"{"success":false,"code":2041,"message":"order state cannot be cancelled"}"#),
            as: NoData.self
        )
        #expect(error.code == .orderNotCancellable)
    }

    @Test func `a failure with HTTP 200 throws MEXC's code and message`() async throws {
        let json = #"{"success":false,"code":1001,"message":"Contract does not exist"}"#
        let error = try await mexcError(from: response(json))
        #expect(error.code == .contractNotFound)
        #expect(error.message == "Contract does not exist")
        #expect(error.httpStatus == 200)
        #expect(error.body == Data(json.utf8))
    }

    @Test func `a failure without success reports its code`() async throws {
        let error = try await mexcError(from: response(#"{"code":600,"msg":"Parameter error"}"#))
        #expect(error.code == .invalidParameter)
        #expect(error.message == "Parameter error")
    }

    @Test func `an HTTP error with an envelope throws the envelope's code`() async throws {
        let json = #"{"success":false,"code":401,"message":"Not logged in or login has expired"}"#
        let error = try await mexcError(from: response(json, status: 401))
        #expect(error.code == .notLoggedIn)
        #expect(error.httpStatus == 401)
    }

    @Test func `an HTTP error without an envelope throws the status as the code`() async throws {
        let error = try await mexcError(from: response("<html>Bad Gateway</html>", status: 502))
        #expect(error.code.rawValue == 502)
        #expect(error.message == nil)
        #expect(error.httpStatus == 502)
    }

    @Test func `an HTTP error that reports success throws the status as the code`() async throws {
        let error = try await mexcError(from: response(#"{"success":true,"code":0,"data":1}"#, status: 500))
        #expect(error.code == .internalError)
        #expect(error.httpStatus == 500)
    }

    @Test func `a code sent as a string still reports the failure`() async throws {
        let error = try await mexcError(from: response(#"{"success":false,"code":"1001","message":7}"#))
        #expect(error.code == .contractNotFound)
        #expect(error.message == nil)
    }

    @Test func `a redirect throws the status as the code`() async throws {
        let error = try await mexcError(from: response("", status: 302))
        #expect(error.code.rawValue == 302)
    }

    @Test func `a body that isn't an envelope throws DecodingError`() async throws {
        await #expect(throws: DecodingError.self) {
            try await Envelope.data(Int.self, from: response("<html>OK</html>"))
        }
    }

    @Test func `data of the wrong type throws DecodingError`() async throws {
        await #expect(throws: DecodingError.self) {
            try await Envelope.data(Int.self, from: response(#"{"success":true,"code":0,"data":"x"}"#))
        }
    }

    private func response(_ json: String, status: Int = 200) -> TransportResponse {
        TransportResponse(status: status, body: Data(json.utf8))
    }

    private func mexcError<Value: Decodable & Sendable>(
        from response: TransportResponse, as _: Value.Type = Int.self
    ) async throws -> MexcError {
        try await #require(throws: MexcError.self) { try await Envelope.data(Value.self, from: response) }
    }
}
