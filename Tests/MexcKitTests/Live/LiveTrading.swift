import Testing

/// The live suites that place orders or change settings, run one at a time: they share the account's
/// BTC_USDT orders and positions, and one suite's cancel or close would otherwise reach another's.
@Suite("Live trading", .serialized)
struct LiveTrading {}
