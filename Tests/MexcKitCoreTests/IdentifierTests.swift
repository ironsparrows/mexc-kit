import Foundation
import MexcKitCore
import Testing

extension MexcKitCoreTests {
    @Suite("Identifiers")
    struct IdentifierTests {
        enum Identifier: CaseIterable, Sendable {
            case order, externalOrder, fill, position, planOrder, stopOrder, trailingOrder
        }

        @Test(arguments: Identifier.allCases)
        func `an ID decodes the same from a JSON number and a string and encodes as a string`(
            identifier: Identifier
        ) throws {
            let fromNumber = try roundTrip(identifier, #"[768116802038827520]"#)
            let fromString = try roundTrip(identifier, #"["768116802038827520"]"#)
            #expect(fromNumber == #"["768116802038827520"]"#)
            #expect(fromString == fromNumber)
        }

        @Test func `a symbol is written as a string literal and prints as its raw value`() throws {
            let symbol: MexcFutures.Symbol = "BTC_USDT"
            #expect(symbol == MexcFutures.Symbol(rawValue: "BTC_USDT"))
            #expect("\(symbol)" == "BTC_USDT")
            let data = try JSONEncoder().encode([symbol])
            #expect(try JSONDecoder().decode([MexcFutures.Symbol].self, from: data) == [symbol])
        }

        @Test func `an external order ID is written as a string literal`() {
            let id: MexcFutures.ExternalOrderID = "grid-7"
            #expect(id == MexcFutures.ExternalOrderID(rawValue: "grid-7"))
            #expect("\(id)" == "grid-7")
        }

        private func roundTrip(_ identifier: Identifier, _ json: String) throws -> String {
            switch identifier {
            case .order: try roundTrip(MexcFutures.OrderID.self, json)
            case .externalOrder: try roundTrip(MexcFutures.ExternalOrderID.self, json)
            case .fill: try roundTrip(MexcFutures.FillID.self, json)
            case .position: try roundTrip(MexcFutures.PositionID.self, json)
            case .planOrder: try roundTrip(MexcFutures.PlanOrderID.self, json)
            case .stopOrder: try roundTrip(MexcFutures.StopOrderID.self, json)
            case .trailingOrder: try roundTrip(MexcFutures.TrailingOrderID.self, json)
            }
        }

        private func roundTrip<Value: Codable>(_ type: Value.Type, _ json: String) throws -> String {
            let decoded = try JSONDecoder().decode([Value].self, from: Data(json.utf8))
            return String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self)
        }
    }
}
