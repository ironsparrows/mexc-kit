import Foundation

/// A GET request's parameters as `name=value` pairs sorted by name and joined with `&`,
/// with names and values percent-encoded.
struct QueryString {
    /// The query as sent, without the leading `?`. Empty when there are no parameters.
    let encoded: String

    init(_ parameters: [String: String]) {
        encoded = parameters
            .sorted { $0.key.utf8.lexicographicallyPrecedes($1.key.utf8) }
            .map { "\($0.key.percentEncoded)=\($0.value.percentEncoded)" }
            .joined(separator: "&")
    }

    /// The query as signed.
    func signed(_ commaSigning: CommaSigning) -> String {
        switch commaSigning {
        case .encoded: encoded
        case .raw: encoded.replacingOccurrences(of: "%2C", with: ",")
        }
    }
}

extension QueryString {
    /// How a comma inside a query value appears in the string to sign.
    ///
    /// A comma-separated list such as `order_ids=1,2,3` is always sent percent-encoded. MEXC's
    /// documentation says to sign it encoded too; MEXC's own sample clients sign the commas as they
    /// are. Values without a comma sign the same either way.
    enum CommaSigning: Sendable {
        /// Signs `%2C`, exactly as sent.
        case encoded
        /// Signs `,` in place of `%2C`.
        case raw
    }
}

extension String {
    /// The string with every byte percent-encoded except RFC 3986's unreserved characters: letters,
    /// digits, `-`, `.`, `_` and `~`.
    var percentEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlUnreserved) ?? self
    }
}

extension CharacterSet {
    fileprivate static let urlUnreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )
}
