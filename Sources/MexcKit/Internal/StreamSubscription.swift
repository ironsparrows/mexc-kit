import Foundation

/// One subscription to a channel of MEXC's WebSocket: the request that starts it and the route its
/// pushes take. A private channel has no subscribe request: the account connection's
/// `personal.filter` covers it, by its key or, for a channel without one, by an empty filter. The
/// subscribe and unsubscribe requests and the acknowledgement channel are for public channels.
struct StreamSubscription: Hashable, Sendable {
    /// What the subscription streams, in the API's words, for error messages, such as
    /// `BTC_USDT order books grouped by step 10`.
    var name: String
    /// The channel's name without the `sub.`, `unsub.` or `push.` prefix, such as `deal` or
    /// `depth.full`.
    var channel: String
    /// `nil` for a channel that covers every market.
    var symbol: MexcFutures.Symbol?
    /// The request's parameters besides the symbol.
    var parameters: [String: Parameter] = [:]
    /// What tells this subscription's pushes apart from another's on the same channel and market:
    /// a candle interval. Pushes of the other channels carry nothing to tell them apart, so a
    /// market can have only one subscription to each.
    var variant: String?
    /// The `personal.filter` key of a private channel, such as `order`; `nil` for a public channel
    /// and for a private channel the filter doesn't name, such as `personal.track.order`.
    var filter: String?

    var route: Route { Route(channel: channel, symbol: symbol?.rawValue ?? "", variant: variant) }

    /// The text frame that starts the subscription, such as
    /// `{"method":"sub.deal","param":{"symbol":"BTC_USDT"}}`.
    var subscribeRequest: String { request("sub") }

    /// The text frame that ends the subscription: the same parameters as ``subscribeRequest``.
    var unsubscribeRequest: String { request("unsub") }

    /// The channel of MEXC's acknowledgement of ``subscribeRequest``.
    var acknowledgementChannel: String { "rs.sub.\(channel)" }

    private func request(_ verb: String) -> String {
        var parameters = parameters
        if let symbol { parameters["symbol"] = .string(symbol.rawValue) }
        let request = Request(method: "\(verb).\(channel)", param: parameters)
        // Encoding strings, integers and booleans can't fail.
        let data = try! JSONEncoder.requestBody.encode(request)
        return String(decoding: data, as: UTF8.self)
    }
}

extension StreamSubscription {
    /// Where a push goes: its channel, market and variant.
    struct Route: Hashable, Sendable {
        var channel: String
        /// Empty for a channel that covers every market, as in MEXC's pushes.
        var symbol: String
        var variant: String?
    }

    enum Parameter: Hashable, Sendable, Encodable {
        case string(String)
        case int(Int)
        case bool(Bool)

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value): try container.encode(value)
            case .int(let value): try container.encode(value)
            case .bool(let value): try container.encode(value)
            }
        }
    }

    private struct Request: Encodable {
        var method: String
        var param: [String: Parameter]
    }
}
