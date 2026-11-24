// MARK: - Model

extension MexcFutures {
    /// One page of a list MEXC returns in pages.
    public struct Page<Element> {
        public let items: [Element]
        /// The page number, starting at 1.
        public let currentPage: Int
        public let pageSize: Int
        /// The number of items on all pages together.
        public let totalCount: Int
        public let totalPages: Int

        public init(items: [Element], currentPage: Int, pageSize: Int, totalCount: Int, totalPages: Int) {
            self.items = items
            self.currentPage = currentPage
            self.pageSize = pageSize
            self.totalCount = totalCount
            self.totalPages = totalPages
        }
    }
}

extension MexcFutures.Page: Sendable where Element: Sendable {}
extension MexcFutures.Page: Equatable where Element: Equatable {}
extension MexcFutures.Page: Hashable where Element: Hashable {}

// MARK: - Requests

extension MexcFutures {
    /// Which page of a list to fetch.
    ///
    /// The SDK sends the size as given. Each method's documentation states the largest size MEXC
    /// accepts; MEXC rejects a larger one.
    public struct PageRequest: Hashable, Sendable {
        /// The page number, starting at 1.
        public var number: Int
        public var size: Int

        public init(number: Int, size: Int) {
            self.number = number
            self.size = size
        }

        /// The first page at MEXC's default size of 20.
        public static let first = Self(number: 1, size: 20)
    }
}

// MARK: - Wire

extension MexcFutures.Page: Decodable where Element: Decodable {
    private enum CodingKeys: String, CodingKey {
        case items = "resultList"
        case currentPage
        case pageSize
        case totalCount
        case totalPages = "totalPage"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([Element].self, forKey: .items)
        currentPage = try container.decode(Int.self, forKey: .currentPage)
        pageSize = try container.decode(Int.self, forKey: .pageSize)
        totalCount = try container.decode(Int.self, forKey: .totalCount)
        totalPages = try container.decode(Int.self, forKey: .totalPages)
    }
}
