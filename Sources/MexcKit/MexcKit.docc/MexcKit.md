# ``MexcKit``

Trade MEXC futures from Swift: market data, the account, orders and live streams.

## Overview

MexcKit calls MEXC's futures REST API and its WebSocket streams. One ``MexcFutures/Client`` holds
every capability, grouped by domain: `client.market`, `client.account`, `client.order`,
`client.stream` and more. Each domain is a protocol, so a test can replace one with a mock.

```swift
import MexcKit

let client = MexcFutures.Client()
let ticker = try await client.market.ticker("BTC_USDT")
```

Prices, volumes and rates are `Decimal`, read exactly as MEXC sends them. Volumes are in contracts.
Every call that needs MEXC's answer is `async`. It throws ``MexcError`` when MEXC refuses it, and
``MexcFutures/ClientError`` when the client couldn't complete it; besides those, cancelling throws
`CancellationError`, and a response the client can't read throws `DecodingError`.

## Topics

### Essentials

- <doc:GettingStarted>
- ``MexcFutures/Client``
- ``MexcCredentials``
- ``MexcFutures/API``

### Market data

- ``MexcFutures/MarketAPI``
- ``MexcFutures/Symbol``
- ``MexcFutures/Contract``
- ``MexcFutures/Ticker``
- ``MexcFutures/TickerSummary``
- ``MexcFutures/OrderBook``
- ``MexcFutures/Candle``
- ``MexcFutures/CandlePrice``
- ``MexcFutures/Deal``
- ``MexcFutures/FundingRate``
- ``MexcFutures/PriceSnapshot``
- ``MexcFutures/InsuranceFund``

### Account

- ``MexcFutures/AccountAPI``
- ``MexcFutures/Balance``
- ``MexcFutures/Transfer``
- ``MexcFutures/TransferState``
- ``MexcFutures/TransferDirection``
- ``MexcFutures/ProfitRate``
- ``MexcFutures/ProfitRatePeriod``
- ``MexcFutures/PositionRiskLimit``
- ``MexcFutures/LeverageMode``

### Fees

- ``MexcFutures/FeeRates``
- ``MexcFutures/FeeTotals``
- ``MexcFutures/DiscountUsage``
- ``MexcFutures/FeeDeductionAsset``
- ``MexcFutures/FeeDiscount``
- ``MexcFutures/FeeDeduction``

### Positions

- ``MexcFutures/PositionAPI``
- ``MexcFutures/Position``
- ``MexcFutures/PositionID``
- ``MexcFutures/PositionSide``
- ``MexcFutures/PositionState``
- ``MexcFutures/PositionMode``
- ``MexcFutures/MarginMode``
- ``MexcFutures/FundingPayment``
- ``MexcFutures/LeverageSetting``

### Orders

- ``MexcFutures/OrderAPI``
- ``MexcFutures/OrderRequest``
- ``MexcFutures/PlacedOrder``
- ``MexcFutures/Order``
- ``MexcFutures/OrderID``
- ``MexcFutures/ExternalOrderID``
- ``MexcFutures/OrderSide``
- ``MexcFutures/OrderType``
- ``MexcFutures/OrderState``
- ``MexcFutures/OrderCategory``
- ``MexcFutures/OrderErrorCode``
- ``MexcFutures/BestPrice``
- ``MexcFutures/AttachedStop``
- ``MexcFutures/Fill``
- ``MexcFutures/FillID``
- ``MexcFutures/BatchResult``
- ``MexcFutures/PendingOrderCounts``

### Conditional orders

- ``MexcFutures/Trigger``
- ``MexcFutures/TriggerCondition``
- ``MexcFutures/PriceSource``
- ``MexcFutures/PlanOrderAPI``
- ``MexcFutures/PlanOrderRequest``
- ``MexcFutures/PlanOrder``
- ``MexcFutures/PlanOrderID``
- ``MexcFutures/PlanOrderState``
- ``MexcFutures/StopOrderAPI``
- ``MexcFutures/StopOrderRequest``
- ``MexcFutures/StopOrder``
- ``MexcFutures/StopOrderID``
- ``MexcFutures/TrailingOrderAPI``
- ``MexcFutures/TrailingOrderRequest``
- ``MexcFutures/TrailingOrder``
- ``MexcFutures/TrailingOrderID``
- ``MexcFutures/TrailingOrderState``

### Self-trade prevention

- ``MexcFutures/SelfTradePreventionAPI``
- ``MexcFutures/SelfTradePreventionGroup``
- ``MexcFutures/SelfTradePreventionMode``

### Streams

- ``MexcFutures/StreamAPI``
- ``MexcFutures/BalanceUpdate``
- ``MexcFutures/AttachedStopsUpdate``
- ``MexcFutures/LiquidationRisk``
- ``MexcFutures/LiquidationNotice``
- ``MexcFutures/ChaseFailure``
- ``MexcFutures/TrialBonusUpdate``

### The local order book

- ``MexcFutures/OrderBookSync``

### Errors

- ``MexcError``
- ``MexcFutures/ClientError``

### Paging

- ``MexcFutures/Page``
- ``MexcFutures/PageRequest``

### Namespace

- ``MexcFutures``
