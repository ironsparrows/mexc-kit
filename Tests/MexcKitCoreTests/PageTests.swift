import Foundation
import MexcKitCore
import Testing

extension MexcKitCoreTests {
    @Suite("Page")
    struct PageTests {
        private struct Row: Decodable, Equatable {
            let symbol: String
            let snapshotTime: Int64
        }

        // The `data` of a recorded `GET /api/v1/contract/risk_reverse/history` response.
        private let recorded = #"""
            {"pageSize":2,"totalCount":42,"totalPage":21,"currentPage":1,"resultList":[{"symbol":"BTC_USDT","currency":"USDT","available":119929106.917446236948109081058817604149,"snapshotTime":1795492800000},{"symbol":"BTC_USDT","currency":"USDT","available":119912845.317814385909292576929694889568,"snapshotTime":1795478400000}]}
            """#

        @Test func `a page decodes from a recorded MEXC response`() throws {
            let page = try JSONDecoder().decode(MexcFutures.Page<Row>.self, from: Data(recorded.utf8))
            #expect(
                page
                    == MexcFutures.Page(
                        items: [
                            Row(symbol: "BTC_USDT", snapshotTime: 1_795_492_800_000),
                            Row(symbol: "BTC_USDT", snapshotTime: 1_795_478_400_000),
                        ],
                        currentPage: 1, pageSize: 2, totalCount: 42, totalPages: 21
                    )
            )
        }
    }
}
