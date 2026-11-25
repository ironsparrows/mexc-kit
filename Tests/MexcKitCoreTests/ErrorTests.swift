import Foundation
import Testing
@testable import MexcKitCore

extension MexcKitCoreTests {
    @Suite("Errors")
    struct ErrorTests {
        @Test func `a MEXC error describes its code, status and message but not its body`() {
            let error = MexcError(
                code: .contractNotFound, message: "Contract does not exist", httpStatus: 200,
                body: Data(#"{"available":1234.5}"#.utf8)
            )
            #expect(error.description == "MEXC error 1001 (HTTP 200): Contract does not exist")
        }

        @Test func `the localized description is MEXC's message when the response has one`() {
            let error: any Error = MexcError(code: .volumeTooLarge, message: "Maximum order quantity of 500 exceeded")
            #expect(error.localizedDescription == "Maximum order quantity of 500 exceeded")
        }

        @Test(arguments: [nil, ""])
        func `without a message the localized description falls back to the documented one`(message: String?) {
            let error = MexcError(code: .insufficientBalance, message: message)
            #expect((error as any Error).localizedDescription == "Balance insufficient")
            #expect(
                error.recoverySuggestion
                    == "Insufficient available balance or margin. Check wallet balance, open orders, and locked margin before retrying."
            )
        }

        @Test func `a documented code without a member is read through its raw value`() {
            let error = MexcError(code: .init(rawValue: 603))
            #expect(error.errorDescription == "Repeated request")
            #expect(error.recoverySuggestion?.hasPrefix("A duplicate request was detected.") == true)
        }

        @Test(arguments: [nil, ""])
        func `an undocumented code without a message is described by its code and status`(message: String?) {
            let error = MexcError(code: .init(rawValue: 404), message: message, httpStatus: 404)
            #expect(error.errorDescription == "MEXC error 404 (HTTP 404)")
            #expect(error.recoverySuggestion == nil)
        }

        @Test(arguments: [
            (MexcError.Code.tooManyCancellations, "Number of cancelled orders exceeds …"),
            (.sellPriceBelowMinimum, "Selling price is lower than the minimum price …, please fill in again"),
        ])
        func `a documented message's placeholders are shown as an ellipsis`(code: MexcError.Code, expected: String) {
            #expect(MexcError(code: code).errorDescription == expected)
        }

        // MEXC's documented message for each member, so a member with the wrong raw value fails here.
        @Test(arguments: [
            (MexcError.Code.notLoggedIn, "Not logged in or login has expired"),
            (.apiKeyExpired, "API Key expired, please apply again"),
            (.ipNotWhitelisted, "Accessing IP is not in the whitelist"),
            (.noPermission, "You do not have access to the interface"),
            (.signatureFailed, "Confirming signature failed"),
            (.readPermissionRequired, "Please enable API Key read access"),
            (.writePermissionRequired, "Please enable API Key write access"),
            (.tradingInfoReadPermissionRequired, "Trading information read access is required"),
            (.tradingInfoWritePermissionRequired, "Please enable API Key trading information write access"),
            (.tradingForbidden, "Trading is forbidden"),
            (.internalError, "Internal error. Please try again."),
            (.busy, "System busy, try again later"),
            (.tooFrequent, "Requests are too frequent, please try again later"),
            (.tradingTooFrequent, "Trading too frequent, please try again later"),
            (.dailyOrderLimitReached, "You've reached today's order limit"),
            (.invalidParameter, "Parameter error"),
            (.invalidAmount, "Amount error"),
            (.invalidTimeRange, "Incorrect time range, you can select up to 90 days only"),
            (.unsupportedCurrency, "Unsupported cryptocurrency"),
            (.contractNotFound, "Contract does not exist"),
            (.contractNotActivated, "Contract not activated"),
            (.contractUnavailable, "The trading pair is not available"),
            (.invalidOrderSide, "Order direction error"),
            (.invalidOrderType, "Order type error"),
            (.invalidPrice, "Order price error"),
            (.invalidVolume, "Order quantity error"),
            (.invalidPrecision, "Price or quantity precision error, please enter again"),
            (.sellPriceBelowMinimum, "Selling price is lower than the minimum price {amount}{currency}, please fill in again"),
            (.priceBelowLiquidationPrice, "Order price is lower than the liquidation price of the position"),
            (.priceAboveLiquidationPrice, "Order price is higher than the liquidation price of the position"),
            (.volumeTooLarge, "Maximum order quantity of {count} exceeded"),
            (.insufficientBalance, "Balance insufficient"),
            (.externalOrderIDTooLong, "External order ID too long (max. 32 digit)"),
            (.orderNotFound, "Order does not exist"),
            (.orderNotCancellable, "Current order status does not allow cancelation"),
            (.tooManyCancellations, "Number of cancelled orders exceeds {count}"),
            (.batchTooLarge, "Orders in batches shall not be greater than {count}"),
            (.batchQueryTooLarge, "Batch query quantity exceeds the limit of {count}"),
            (.positionNotFound, "Position is nonexistent or closed"),
            (.closeVolumeTooLarge, "Insufficient number of positions can be closed"),
            (.leverageOutOfRange, "Leverage multiplier must be within the upper limit {max} and lower limit {min}"),
            (.marginReductionTooLarge, "Cannot exceed the maximum reducible margin {vol}"),
            (.positionAboveRiskLimit, "Your current position amount is greater than the allowable amount of the new order. Please modify the risk limit and place the order again"),
            (.riskLimitExceeded, "Current risk limit and maximum allowable number of positions exceeded, please adjust the risk limit"),
            (.leverageTierLimitReached, "Position limit reached for your current leverage tier. See Risk Limits for the maximum position size for each tier."),
            (.invalidTriggerPriceSource, "Trigger order price type error"),
            (.invalidTriggerCondition, "Trigger order type error"),
            (.invalidTriggerPrice, "Trigger price error"),
            (.missingStopPrices, "Stop profit price and stop loss price cannot both be empty"),
            (.stopOrderNotFound, "Stop-limit order is nonexistent or closed"),
            (.invalidStopOrderPrice, "The price of stop-limit order error"),
            (.stopOrderVolumeTooLarge, "Total amount of the stop-limit order is greater than the closable amount of the position"),
        ])
        func `each named code has MEXC's documented message`(code: MexcError.Code, documented: String) {
            #expect(code.futuresDocumentation?.message == documented)
        }

        @Test func `a client error describes its reason and message`() {
            #expect(MexcFutures.ClientError(.missingCredentials).description == "MEXC client error: missingCredentials")
            #expect(
                MexcFutures.ClientError(.subscriptionRejected, message: "Contract [NOPE_USDT] not exists").description
                    == "MEXC client error: subscriptionRejected: Contract [NOPE_USDT] not exists"
            )
        }

        @Test func `a client error's localized description is a sentence about its reason`() {
            let bare: any Error = MexcFutures.ClientError(.loginRejected)
            let detailed: any Error = MexcFutures.ClientError(.subscriptionRejected, message: "Contract [NOPE_USDT] not exists")
            let empty: any Error = MexcFutures.ClientError(.loginRejected, message: "")
            #expect(bare.localizedDescription == "MEXC rejected the stream login")
            #expect(empty.localizedDescription == "MEXC rejected the stream login")
            #expect(
                detailed.localizedDescription == "MEXC rejected the stream subscription: Contract [NOPE_USDT] not exists"
            )
        }

        @Test func `a network failure keeps its underlying error out of the localized description`() {
            struct Offline: Error, CustomStringConvertible {
                var description: String { "Network is down" }
            }
            let error = MexcFutures.ClientError(.connectionFailed, underlyingError: Offline())
            #expect(error.description == "MEXC client error: connectionFailed (Network is down)")
            #expect((error as any Error).localizedDescription == "The connection to MEXC failed")
            #expect(error.underlyingError is Offline)
            #expect((MexcFutures.ClientError(.timedOut) as any Error).localizedDescription == "MEXC didn't answer in time")
        }
    }
}
