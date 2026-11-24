import Foundation
import MexcKitProtobuf
import SwiftProtobuf
@testable import MexcKit

/// What the account stream suites share: an account that logs in with a fixed key and time, its
/// login request, and building filters and pushes.
enum AccountStreamSupport {
    static let account = StreamConnection.Account(
        credentials: { MexcCredentials(apiKey: "mx0testkey", secret: "testsecret") },
        clock: ServerClock(localNow: { Date(timeIntervalSince1970: 1_700_000_000) })
    )
    /// The login for the account above: the signature is HMAC-SHA256 over the API key and the request
    /// time, as REST signs a request without parameters.
    static let login = #"{"method":"login","param":{"apiKey":"mx0testkey","reqTime":"1700000000000","#
        + #""signature":"714a5b3c4e04c2cb808c224fe8f77bbbec89c8014d52eee3d9b064004ca0e9f9"},"subscribe":false}"#

    static func filter(_ filters: String) -> String {
        #"{"method":"personal.filter","param":{"filters":["# + filters + "]}}"
    }

    static func push(_ channel: String, _ data: ContractWrapper.OneOf_Data) throws -> Data {
        try ContractWrapper.with {
            $0.channel = channel
            $0.ts = 1_760_942_212_000
            $0.data = data
        }.serializedBytes()
    }

    static func take<Element>(
        _ count: Int, from stream: AsyncThrowingStream<Element, any Error>
    ) async throws -> [Element] {
        var values: [Element] = []
        for try await value in stream {
            values.append(value)
            if values.count == count { break }
        }
        return values
    }
}
