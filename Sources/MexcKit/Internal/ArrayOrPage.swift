/// A list MEXC documents both as a bare array and as a page: its documentation lists page fields, and
/// its example is an array. Either decodes to the items.
struct ArrayOrPage<Element: Decodable & Sendable>: Decodable, Sendable {
    let items: [Element]

    init(from decoder: any Decoder) throws {
        if (try? decoder.unkeyedContainer()) != nil {
            items = try [Element](from: decoder)
        } else {
            items = try MexcFutures.Page<Element>(from: decoder).items
        }
    }
}
