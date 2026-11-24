extension MexcError.Code {
    /// MEXC's documented text for one futures error code.
    struct Documentation {
        /// The short message, which can hold placeholders such as `{count}` that MEXC fills in its
        /// responses.
        let message: String
        /// What the code means and what to check before retrying.
        let details: String

        /// ``message`` with each run of placeholders replaced by an ellipsis, for showing when MEXC's
        /// response has no message of its own.
        var readableMessage: String {
            message.replacing(/(\{[^}]*\})+/, with: "…")
        }
    }

    /// MEXC's documented text for this code as a futures error code, or `nil` for a code the futures
    /// documentation doesn't list.
    var futuresDocumentation: Documentation? { Self.futuresDocumentation[rawValue] }

    // Every futures error code on https://www.mexc.com/api-docs/futures/error-code as read on
    // 2026-11-24, sorted by code. "Code" column: the code and `message`; "Description": `details`.
    private static let futuresDocumentation: [Int: Documentation] = [
        401: Documentation(
            message: "Not logged in or login has expired",
            details: "The session is not authenticated or has expired. Check whether the API key, signature, and timestamp are valid, and re-authenticate before retrying."
        ),
        402: Documentation(
            message: "API Key expired, please apply again",
            details: "The API key has expired. Create a new API key in your MEXC account and update the client configuration."
        ),
        406: Documentation(
            message: "Accessing IP is not in the whitelist",
            details: "The request IP is not on the API key whitelist. Check the configured whitelist and the actual outbound IP of your server or application."
        ),
        500: Documentation(
            message: "Internal error. Please try again.",
            details: "An internal server error occurred. Retry later after querying whether the operation already completed. Contact MEXC customer service or API support if the issue persists."
        ),
        501: Documentation(
            message: "System busy, try again later",
            details: "The system is busy. Reduce request frequency and retry later."
        ),
        506: Documentation(
            message: "Unknown source of request",
            details: "The request source could not be identified. Check request headers, client configuration, and whether the endpoint is called from an allowed environment."
        ),
        510: Documentation(
            message: "Requests are too frequent, please try again later",
            details: "The request frequency may have exceeded the rate limit. Reduce the request rate and retry later. Check the rate-limit rules for this Futures endpoint."
        ),
        511: Documentation(
            message: "You do not have access to the interface",
            details: "The API key may not have permission to access this endpoint. Check API key permissions, account type, and whether the interface is available to your account."
        ),
        513: Documentation(
            message: "Invalid request, please try again later",
            details: "The request is invalid. Check request parameters, HTTP method, endpoint path, and signature. Retry later if the failure may be temporary."
        ),
        600: Documentation(
            message: "Parameter error",
            details: "One or more request parameters are invalid. Check parameter names, types, formats, required fields, and value ranges against the API documentation."
        ),
        601: Documentation(
            message: "Data parsing error",
            details: "Request data could not be parsed. Check JSON or form body format, encoding, and whether the payload matches the expected schema."
        ),
        602: Documentation(
            message: "Confirming signature failed",
            details: "Signature verification failed. Check the API secret, signature algorithm, parameter ordering, encoding, and whether signed parameters match those sent in the request."
        ),
        603: Documentation(
            message: "Repeated request",
            details: "A duplicate request was detected. Avoid resubmitting the same request with identical parameters in a short period. Query order or operation status before retrying."
        ),
        604: Documentation(
            message: "Sorry, this feature is under maintenance",
            details: "This feature is under maintenance. Retry later and check official announcements for availability."
        ),
        701: Documentation(
            message: "Please enable API Key read access",
            details: "API key read access is required for this endpoint. Enable read permission for the API key in account settings."
        ),
        702: Documentation(
            message: "Please enable API Key write access",
            details: "API key write access is required for this endpoint. Enable write permission for the API key in account settings."
        ),
        703: Documentation(
            message: "Trading information read access is required",
            details: "Trading information read access is required. Enable the corresponding API key permission before calling this endpoint."
        ),
        704: Documentation(
            message: "Please enable API Key trading information write access",
            details: "Trading information write access is required. Enable the corresponding API key permission before calling this endpoint."
        ),
        801: Documentation(
            message: "System under maintenance",
            details: "The Futures system is under maintenance. Retry later and check official maintenance notices."
        ),
        1000: Documentation(
            message: "Account does not exist",
            details: "The account could not be found. Check whether the API key belongs to the correct account and whether the Futures account is activated."
        ),
        1001: Documentation(
            message: "Contract does not exist",
            details: "The specified contract does not exist. Check the symbol name, format, and whether the contract is listed and supported by the endpoint."
        ),
        1002: Documentation(
            message: "Contract not activated",
            details: "The contract is not activated or not yet available for trading. Check contract status and platform announcements."
        ),
        1003: Documentation(
            message: "Risk limit level error, please try again after adjustment",
            details: "The risk limit level is invalid. Adjust the risk limit according to contract rules and your position size, then retry."
        ),
        1004: Documentation(
            message: "Amount error",
            details: "The amount or quantity value is invalid. Check format, precision, minimum/maximum limits, and symbol rules."
        ),
        2001: Documentation(
            message: "Order direction error",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2002: Documentation(
            message: "Position type error",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2003: Documentation(
            message: "Exceeded the maximum buying price {amount}{currency}, please fill in again",
            details: "The price or quantity does not meet contract rules. Check tick size, lot size, min/max order size, and price limits in contract information."
        ),
        2004: Documentation(
            message: "Selling price is lower than the minimum price {amount}{currency}, please fill in again",
            details: "The price or quantity does not meet contract rules. Check tick size, lot size, min/max order size, and price limits in contract information."
        ),
        2005: Documentation(
            message: "Balance insufficient",
            details: "Insufficient available balance or margin. Check wallet balance, open orders, and locked margin before retrying."
        ),
        2006: Documentation(
            message: "Leverage multiplier must be within the upper limit {max} and lower limit {min}",
            details: "The leverage value is invalid or conflicts with open orders or positions. Check allowed leverage range, open orders, and position leverage before adjusting."
        ),
        2007: Documentation(
            message: "Order price error",
            details: "The price or quantity does not meet contract rules. Check tick size, lot size, min/max order size, and price limits in contract information."
        ),
        2008: Documentation(
            message: "Insufficient number of positions can be closed",
            details: "The position does not exist or has already been closed. Query open positions before placing close or reduce-only orders."
        ),
        2009: Documentation(
            message: "Position is nonexistent or closed",
            details: "The position does not exist or has already been closed. Query open positions before placing close or reduce-only orders."
        ),
        2011: Documentation(
            message: "Order quantity error",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2013: Documentation(
            message: "Number of cancelled orders exceeds {count}",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2014: Documentation(
            message: "Orders in batches shall not be greater than {count}",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2015: Documentation(
            message: "Price or quantity precision error, please enter again",
            details: "The price or quantity does not meet contract rules. Check tick size, lot size, min/max order size, and price limits in contract information."
        ),
        2016: Documentation(
            message: "Trigger order exceeds the max. number of {count}",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2018: Documentation(
            message: "Cannot exceed the maximum reducible margin {vol}",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2019: Documentation(
            message: "Leverage adjustment unavailable while orders are open",
            details: "The leverage value is invalid or conflicts with open orders or positions. Check allowed leverage range, open orders, and position leverage before adjusting."
        ),
        2021: Documentation(
            message: "Order leverage is inconsistent with the existing position leverage",
            details: "The leverage value is invalid or conflicts with open orders or positions. Check allowed leverage range, open orders, and position leverage before adjusting."
        ),
        2022: Documentation(
            message: "Position type error",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2023: Documentation(
            message: "Risk limit cannot be modified at the moment due to leverage of existing open positions",
            details: "The leverage value is invalid or conflicts with open orders or positions. Check allowed leverage range, open orders, and position leverage before adjusting."
        ),
        2024: Documentation(
            message: "There's order with leverage greater than the maximum leverage of the new order, so modifying the risk limit is unavailable at the moment",
            details: "The leverage value is invalid or conflicts with open orders or positions. Check allowed leverage range, open orders, and position leverage before adjusting."
        ),
        2025: Documentation(
            message: "Your current position amount is greater than the allowable amount of the new order. Please modify the risk limit and place the order again",
            details: "The risk limit cannot be changed under current conditions. Check open positions, leverage, and risk limit tiers, then adjust according to contract rules."
        ),
        2026: Documentation(
            message: "Leverage adjustment is unavailable for cross margin",
            details: "The leverage value is invalid or conflicts with open orders or positions. Check allowed leverage range, open orders, and position leverage before adjusting."
        ),
        2027: Documentation(
            message: "Cross and isolated position of the same direction are alternative.",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2028: Documentation(
            message: "Maximum order quantity of {count} exceeded",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2029: Documentation(
            message: "Order type error",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2030: Documentation(
            message: "External order ID too long (max. 32 digit)",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2031: Documentation(
            message: "Current risk limit and maximum allowable number of positions exceeded, please adjust the risk limit",
            details: "The risk limit cannot be changed under current conditions. Check open positions, leverage, and risk limit tiers, then adjust according to contract rules."
        ),
        2032: Documentation(
            message: "Order price is lower than the liquidation price of the position",
            details: "The price or quantity does not meet contract rules. Check tick size, lot size, min/max order size, and price limits in contract information."
        ),
        2033: Documentation(
            message: "Order price is higher than the liquidation price of the position",
            details: "The price or quantity does not meet contract rules. Check tick size, lot size, min/max order size, and price limits in contract information."
        ),
        2034: Documentation(
            message: "Batch query quantity exceeds the limit of {count}",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2035: Documentation(
            message: "Market order level not supported",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2036: Documentation(
            message: "You've reached today's order limit",
            details: "You have reached the daily order limit. Reduce order frequency and retry after the limit resets. Check the corresponding rate-limit or daily order-count rules for this endpoint."
        ),
        2037: Documentation(
            message: "Trading too frequent, please try again later",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2038: Documentation(
            message: "Position limit reached for your current leverage tier. See Risk Limits for the maximum position size for each tier.",
            details: "The position size exceeds the limit for your current leverage tier. Review Risk Limits for the maximum position size at each tier, then reduce leverage or position size."
        ),
        2039: Documentation(
            message: "Counterparty's order amount shall not be greater than that of the best bid or best ask. Please select more orders in the orderbook or reduce the order amount before placing the order",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2040: Documentation(
            message: "Order does not exist",
            details: "The specified order was not found. Check order ID, symbol, and whether the order was filled or canceled."
        ),
        2041: Documentation(
            message: "Current order status does not allow cancelation",
            details: "The current order cannot be canceled. Please check the order status."
        ),
        2042: Documentation(
            message: "Duplicate order ID",
            details: "The external order ID is duplicated. Use a unique externalOid for each new order."
        ),
        2043: Documentation(
            message: "The order does not match the position",
            details: "The order side or parameters do not match the existing position. Check position direction, margin mode, and order side before placing the order."
        ),
        2044: Documentation(
            message: "Insufficient margin to adjust leverage",
            details: "The leverage value is invalid or conflicts with open orders or positions. Check allowed leverage range, open orders, and position leverage before adjusting."
        ),
        2045: Documentation(
            message: "Minimum ratio allowed is {number}",
            details: "The ratio or variance parameter is outside the allowed range. Check the minimum and maximum values indicated by the API and adjust accordingly."
        ),
        2046: Documentation(
            message: "Maximum ratio allowed is {number}",
            details: "The ratio or variance parameter is outside the allowed range. Check the minimum and maximum values indicated by the API and adjust accordingly."
        ),
        2047: Documentation(
            message: "Minimum variance allowed is {number}",
            details: "The ratio or variance parameter is outside the allowed range. Check the minimum and maximum values indicated by the API and adjust accordingly."
        ),
        2048: Documentation(
            message: "Maximum variance allowed is {number}",
            details: "The ratio or variance parameter is outside the allowed range. Check the minimum and maximum values indicated by the API and adjust accordingly."
        ),
        2049: Documentation(
            message: "Liquidation may occur after the order is filled at the specified price. Please update the price before placing the order.",
            details: "The price or quantity does not meet contract rules. Check tick size, lot size, min/max order size, and price limits in contract information."
        ),
        2051: Documentation(
            message: "Exceeds the maximum order amount allowed for a single order",
            details: "The order amount does not meet the minimum or maximum single-order amount requirement. Check contract rules and adjust order size."
        ),
        2052: Documentation(
            message: "Partially filled orders do not support price or quantity editing",
            details: "The order cannot be edited under the current order status or order type. Check whether the order is partially filled and whether limit order editing is supported."
        ),
        2053: Documentation(
            message: "One-way mode does not support limit order editing currently",
            details: "The request conflicts with the current position mode (Hedge Mode or One-way Mode). Check position mode settings and endpoint requirements."
        ),
        2054: Documentation(
            message: "Unable to place a new order as the system has not found any successfully canceled orders. Please try editing the order again later or place a new order.",
            details: "The order cannot be edited under the current order status or order type. Check whether the order is partially filled and whether limit order editing is supported."
        ),
        2055: Documentation(
            message: "System does not support limit order editing currently",
            details: "The order cannot be edited under the current order status or order type. Check whether the order is partially filled and whether limit order editing is supported."
        ),
        2056: Documentation(
            message: "Market close order is in progress due to market volatility. Please try again later. We apologize for any inconvenience caused.",
            details: "A market close order is already being processed due to market volatility. Wait and retry later rather than submitting duplicate close requests."
        ),
        2057: Documentation(
            message: "Not meeting the minimum order amount required for a single order",
            details: "The order amount does not meet the minimum or maximum single-order amount requirement. Check contract rules and adjust order size."
        ),
        2058: Documentation(
            message: "Chase Order Failed: The system does not currently support chase orders",
            details: "The chase order request failed. Check order type support, position mode, price rules, available margin, and whether an existing chase order already exists for this contract."
        ),
        2059: Documentation(
            message: "Chase Order Failed: Your order has been filled or canceled",
            details: "The chase order request failed. Check order type support, position mode, price rules, available margin, and whether an existing chase order already exists for this contract."
        ),
        2060: Documentation(
            message: "Chase Order Failed: TP price must be higher than the best bid price",
            details: "The chase order request failed. Check order type support, position mode, price rules, available margin, and whether an existing chase order already exists for this contract."
        ),
        2061: Documentation(
            message: "Chase Order Failed: SL price must be lower than the best bid price",
            details: "The chase order request failed. Check order type support, position mode, price rules, available margin, and whether an existing chase order already exists for this contract."
        ),
        2062: Documentation(
            message: "Chase Order Failed: TP price must be lower than the best ask price",
            details: "The chase order request failed. Check order type support, position mode, price rules, available margin, and whether an existing chase order already exists for this contract."
        ),
        2063: Documentation(
            message: "Chase Order Failed: SL price must be higher than the best ask price",
            details: "The chase order request failed. Check order type support, position mode, price rules, available margin, and whether an existing chase order already exists for this contract."
        ),
        2064: Documentation(
            message: "Unable to place chase orders in one-way position mode",
            details: "The request conflicts with the current position mode (Hedge Mode or One-way Mode). Check position mode settings and endpoint requirements."
        ),
        2065: Documentation(
            message: "Chase Order Failed: Insufficient assets",
            details: "Insufficient available balance or margin. Check wallet balance, open orders, and locked margin before retrying."
        ),
        2066: Documentation(
            message: "Chase Order Failed: This action will result in liquidation",
            details: "The chase order request failed. Check order type support, position mode, price rules, available margin, and whether an existing chase order already exists for this contract."
        ),
        2068: Documentation(
            message: "MEXC has disabled certain SMS services",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2069: Documentation(
            message: "Your current Cross Margin position is showing a loss. Please close the position before claiming the reward again.",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2070: Documentation(
            message: "Price distance cannot exceed 5% of the current bid1/ask1",
            details: "The price or quantity does not meet contract rules. Check tick size, lot size, min/max order size, and price limits in contract information."
        ),
        2071: Documentation(
            message: "Max. chase distance cannot exceed 10%",
            details: "The order or trading request could not be processed. Check symbol, order type, side, price, quantity, leverage, margin mode, position mode, and account status against the API documentation."
        ),
        2072: Documentation(
            message: "You can have up to {count} active chase limit orders per account at a time",
            details: "The chase order request failed. Check order type support, position mode, price rules, available margin, and whether an existing chase order already exists for this contract."
        ),
        2073: Documentation(
            message: "A chase limit order already exists for this Futures pair",
            details: "The chase order request failed. Check order type support, position mode, price rules, available margin, and whether an existing chase order already exists for this contract."
        ),
        2074: Documentation(
            message: "Chase limit orders cannot be edited",
            details: "The chase order request failed. Check order type support, position mode, price rules, available margin, and whether an existing chase order already exists for this contract."
        ),
        2075: Documentation(
            message: "This is not a chase limit order",
            details: "The chase order request failed. Check order type support, position mode, price rules, available margin, and whether an existing chase order already exists for this contract."
        ),
        2076: Documentation(
            message: "This order is a chase limit order",
            details: "The chase order request failed. Check order type support, position mode, price rules, available margin, and whether an existing chase order already exists for this contract."
        ),
        2077: Documentation(
            message: "Long: Fill price is below the liquidation price. Use a limit order instead.",
            details: "The price or quantity does not meet contract rules. Check tick size, lot size, min/max order size, and price limits in contract information."
        ),
        2078: Documentation(
            message: "Short: Fill price exceeds the liquidation price. Use a limit order instead.",
            details: "The price or quantity does not meet contract rules. Check tick size, lot size, min/max order size, and price limits in contract information."
        ),
        2079: Documentation(
            message: "Loss Coverage does not exist",
            details: "The Loss Coverage feature is unavailable, already used, expired, or does not exist. Check eligibility and status before retrying."
        ),
        2080: Documentation(
            message: "Loss Coverage used",
            details: "The Loss Coverage feature is unavailable, already used, expired, or does not exist. Check eligibility and status before retrying."
        ),
        2081: Documentation(
            message: "Loss Coverage expired",
            details: "The Loss Coverage feature is unavailable, already used, expired, or does not exist. Check eligibility and status before retrying."
        ),
        2082: Documentation(
            message: "Loss Coverage unavailable",
            details: "The Loss Coverage feature is unavailable, already used, expired, or does not exist. Check eligibility and status before retrying."
        ),
        3001: Documentation(
            message: "Trigger order price type error",
            details: "The trigger, take-profit, or stop-loss price does not meet contract rules for the order side and type. Check trigger price type, order direction, and price relationships in the documentation."
        ),
        3002: Documentation(
            message: "Trigger order type error",
            details: "The trigger, take-profit, or stop-loss price does not meet contract rules for the order side and type. Check trigger price type, order direction, and price relationships in the documentation."
        ),
        3003: Documentation(
            message: "Execution cycle error",
            details: "The plan or trigger order parameters are invalid. Check trigger price type, order type, execution cycle, and whether the order has already been triggered."
        ),
        3004: Documentation(
            message: "Trigger price error",
            details: "The trigger, take-profit, or stop-loss price does not meet contract rules for the order side and type. Check trigger price type, order direction, and price relationships in the documentation."
        ),
        3006: Documentation(
            message: "Order prices can only be edited for orders that have not been triggered yet",
            details: "The trigger, take-profit, or stop-loss price does not meet contract rules for the order side and type. Check trigger price type, order direction, and price relationships in the documentation."
        ),
        3007: Documentation(
            message: "Take-profit price of a trigger-market long order should be higher than the trigger price",
            details: "The trigger, take-profit, or stop-loss price does not meet contract rules for the order side and type. Check trigger price type, order direction, and price relationships in the documentation."
        ),
        3008: Documentation(
            message: "Take-profit price of a trigger-limit long order should be higher than the order price",
            details: "The trigger, take-profit, or stop-loss price does not meet contract rules for the order side and type. Check trigger price type, order direction, and price relationships in the documentation."
        ),
        3009: Documentation(
            message: "Stop-loss price of a trigger-market long order should be lower than the trigger price",
            details: "The trigger, take-profit, or stop-loss price does not meet contract rules for the order side and type. Check trigger price type, order direction, and price relationships in the documentation."
        ),
        3010: Documentation(
            message: "Stop-loss price of a trigger-limit long order should be lower than the order price",
            details: "The trigger, take-profit, or stop-loss price does not meet contract rules for the order side and type. Check trigger price type, order direction, and price relationships in the documentation."
        ),
        3011: Documentation(
            message: "Take-profit price of a trigger-market short order should be lower than the trigger price",
            details: "The trigger, take-profit, or stop-loss price does not meet contract rules for the order side and type. Check trigger price type, order direction, and price relationships in the documentation."
        ),
        3012: Documentation(
            message: "Take-profit price of a trigger-limit short order should be lower than the order price",
            details: "The trigger, take-profit, or stop-loss price does not meet contract rules for the order side and type. Check trigger price type, order direction, and price relationships in the documentation."
        ),
        3013: Documentation(
            message: "Stop-loss price of a short position trigger-market order should be higher than the trigger price",
            details: "The trigger, take-profit, or stop-loss price does not meet contract rules for the order side and type. Check trigger price type, order direction, and price relationships in the documentation."
        ),
        3014: Documentation(
            message: "Stop-loss price of a short position trigger-limit order should be higher than the order price",
            details: "The trigger, take-profit, or stop-loss price does not meet contract rules for the order side and type. Check trigger price type, order direction, and price relationships in the documentation."
        ),
        3015: Documentation(
            message: "Pre-set TP/SL prices can only be edited for orders that have not been triggered yet",
            details: "The trigger, take-profit, or stop-loss price does not meet contract rules for the order side and type. Check trigger price type, order direction, and price relationships in the documentation."
        ),
        3016: Documentation(
            message: "{symbol} order timed out",
            details: "The order operation timed out. Query order or plan order status before retrying to avoid duplicate submissions."
        ),
        3017: Documentation(
            message: "{symbol} trigger order timed out",
            details: "The order operation timed out. Query order or plan order status before retrying to avoid duplicate submissions."
        ),
        3018: Documentation(
            message: "{symbol} trailing stop order timed out",
            details: "The order operation timed out. Query order or plan order status before retrying to avoid duplicate submissions."
        ),
        3019: Documentation(
            message: "{symbol} chase limit order timed out",
            details: "The order operation timed out. Query order or plan order status before retrying to avoid duplicate submissions."
        ),
        4001: Documentation(
            message: "Unsupported cryptocurrency",
            details: "The request could not be completed. Check request parameters, account status, contract rules, and API key permissions. Contact MEXC customer service or API support if the issue persists."
        ),
        5001: Documentation(
            message: "Stop profit price and stop loss price cannot both be empty",
            details: "The stop-profit/stop-loss order parameters are invalid or conflict with the position. Check TP/SL prices, closable position size, existing TP/SL orders, and margin mode consistency."
        ),
        5002: Documentation(
            message: "Stop-limit order is nonexistent or closed",
            details: "The stop-profit/stop-loss order parameters are invalid or conflict with the position. Check TP/SL prices, closable position size, existing TP/SL orders, and margin mode consistency."
        ),
        5003: Documentation(
            message: "The price of stop-limit order error",
            details: "The stop-profit/stop-loss order parameters are invalid or conflict with the position. Check TP/SL prices, closable position size, existing TP/SL orders, and margin mode consistency."
        ),
        5004: Documentation(
            message: "Total amount of the stop-limit order is greater than the closable amount of the position",
            details: "The stop-profit/stop-loss order parameters are invalid or conflict with the position. Check TP/SL prices, closable position size, existing TP/SL orders, and margin mode consistency."
        ),
        5005: Documentation(
            message: "Order failed as there is already a position TP/SL order.",
            details: "The stop-profit/stop-loss order parameters are invalid or conflict with the position. Check TP/SL prices, closable position size, existing TP/SL orders, and margin mode consistency."
        ),
        5006: Documentation(
            message: "You currently have maker orders or positions in the opposite direction under a different margin mode",
            details: "The stop-profit/stop-loss order parameters are invalid or conflict with the position. Check TP/SL prices, closable position size, existing TP/SL orders, and margin mode consistency."
        ),
        6001: Documentation(
            message: "Trading is forbidden",
            details: "Trading or position opening may be restricted for this account or symbol. Check platform announcements, risk controls, and account status. Contact MEXC customer service or API support if needed."
        ),
        6002: Documentation(
            message: "Position opening is forbidden. Please contact Customer Service",
            details: "Trading or position opening may be restricted for this account or symbol. Check platform announcements, risk controls, and account status. Contact MEXC customer service or API support if needed."
        ),
        6003: Documentation(
            message: "Incorrect time range, you can select up to 90 days only",
            details: "The query time range is invalid. Check start/end time parameters and the maximum allowed range for this endpoint."
        ),
        6004: Documentation(
            message: "The trading pair and status should be filled in",
            details: "The request conflicts with current trading mode, account status, or platform rules. Check margin mode, account restrictions, and endpoint documentation."
        ),
        6005: Documentation(
            message: "The trading pair is not available",
            details: "The request conflicts with current trading mode, account status, or platform rules. Check margin mode, account restrictions, and endpoint documentation."
        ),
        6006: Documentation(
            message: "The current version does not support Cross Margin function, please use the Web version",
            details: "The request conflicts with current trading mode, account status, or platform rules. Check margin mode, account restrictions, and endpoint documentation."
        ),
        6007: Documentation(
            message: "Switching from Cross Margin mode to Isolated Margin Mode is not supported",
            details: "The request conflicts with current trading mode, account status, or platform rules. Check margin mode, account restrictions, and endpoint documentation."
        ),
        6008: Documentation(
            message: "Order placed successfully (The estimated liquidation price may not show accurately on the current version, kindly update to the latest version.)",
            details: "The order may have been placed successfully, but the estimated liquidation price shown on older clients may be inaccurate. Update to the latest client or verify liquidation price on the web platform."
        ),
        6009: Documentation(
            message: "Position opening is currently unavailable for your account. Please go to Help Center to submit information for risk control removal.",
            details: "Account verification or risk control may block this action. Check KYC status, help center requirements, and platform notices."
        ),
        6010: Documentation(
            message: "Multi-asset mode isn't available for your account",
            details: "Multi-Asset mode is not available for this account. Check whether your account type and status support Multi-Asset mode. Contact MEXC customer service or API support if needed."
        ),
        6011: Documentation(
            message: "Unable to switch to Multi-Asset mode as there are currently active orders or positions. Please cancel the orders or close the positions first.",
            details: "Multi-Asset mode restrictions apply. Check account type, open orders, positions, liabilities, and whether your account is eligible for Multi-Asset mode."
        ),
        6012: Documentation(
            message: "Sub-accounts cannot use Multi-Asset mode",
            details: "Multi-Asset mode restrictions apply. Check account type, open orders, positions, liabilities, and whether your account is eligible for Multi-Asset mode."
        ),
        6013: Documentation(
            message: "Traders in Copy Trade cannot use Multi-Asset mode",
            details: "Multi-Asset mode restrictions apply. Check account type, open orders, positions, liabilities, and whether your account is eligible for Multi-Asset mode."
        ),
        6014: Documentation(
            message: "Your account has liabilities and cannot switch to Multi-Asset mode",
            details: "Multi-Asset mode restrictions apply. Check account type, open orders, positions, liabilities, and whether your account is eligible for Multi-Asset mode."
        ),
        6015: Documentation(
            message: "The account has liabilities and cannot switch to Single-Asset mode. Please clear the liabilities first.",
            details: "The request conflicts with current trading mode, account status, or platform rules. Check margin mode, account restrictions, and endpoint documentation."
        ),
        6016: Documentation(
            message: "Unable to switch to Single-Asset mode as there are currently active orders or positions. Please cancel the orders or close the positions first.",
            details: "The request conflicts with current trading mode, account status, or platform rules. Check margin mode, account restrictions, and endpoint documentation."
        ),
        6017: Documentation(
            message: "The current price has expired. Please request the price again.",
            details: "The request conflicts with current trading mode, account status, or platform rules. Check margin mode, account restrictions, and endpoint documentation."
        ),
        6018: Documentation(
            message: "The current exchange rate is unfavorable, and this action may put your account at risk. Please request a new price",
            details: "The request conflicts with current trading mode, account status, or platform rules. Check margin mode, account restrictions, and endpoint documentation."
        ),
        6019: Documentation(
            message: "Coin-margined trading is not supported in Multi-Asset mode",
            details: "Multi-Asset mode restrictions apply. Check account type, open orders, positions, liabilities, and whether your account is eligible for Multi-Asset mode."
        ),
        6020: Documentation(
            message: "Only cross margin is allowed in Multi-Asset mode",
            details: "Multi-Asset mode restrictions apply. Check account type, open orders, positions, liabilities, and whether your account is eligible for Multi-Asset mode."
        ),
        6021: Documentation(
            message: "There is an issue with the liability crypto. Please try again later.",
            details: "The request conflicts with current trading mode, account status, or platform rules. Check margin mode, account restrictions, and endpoint documentation."
        ),
        6022: Documentation(
            message: "Trading error. Please try again later.",
            details: "The request conflicts with current trading mode, account status, or platform rules. Check margin mode, account restrictions, and endpoint documentation."
        ),
        6023: Documentation(
            message: "Market maker accounts cannot use Multi-Asset mode",
            details: "Multi-Asset mode restrictions apply. Check account type, open orders, positions, liabilities, and whether your account is eligible for Multi-Asset mode."
        ),
        6024: Documentation(
            message: "Event Futures trading is not available in Multi-Asset mode",
            details: "Multi-Asset mode restrictions apply. Check account type, open orders, positions, liabilities, and whether your account is eligible for Multi-Asset mode."
        ),
        6025: Documentation(
            message: "Position airdrops are not available in Multi-Asset mode",
            details: "Multi-Asset mode restrictions apply. Check account type, open orders, positions, liabilities, and whether your account is eligible for Multi-Asset mode."
        ),
        6026: Documentation(
            message: "Position opening is unavailable until risk control verification is completed.",
            details: "Account verification or risk control may block this action. Check KYC status, help center requirements, and platform notices."
        ),
        6027: Documentation(
            message: "Due to risk controls, opening new positions for this pair is temporarily disabled. Only closing is allowed.",
            details: "Trading or position opening may be restricted for this account or symbol. Check platform announcements, risk controls, and account status. Contact MEXC customer service or API support if needed."
        ),
        6028: Documentation(
            message: "After the platform's risk review, you are no longer allowed to open Futures positions.",
            details: "The request conflicts with current trading mode, account status, or platform rules. Check margin mode, account restrictions, and endpoint documentation."
        ),
        6029: Documentation(
            message: "Bonuses cannot be used to open Prediction Futures positions at this time. Please adjust the amount and try again.",
            details: "The request conflicts with current trading mode, account status, or platform rules. Check margin mode, account restrictions, and endpoint documentation."
        ),
        6030: Documentation(
            message: "Position opening is unavailable until risk control verification is completed.",
            details: "Account verification or risk control may block this action. Check KYC status, help center requirements, and platform notices."
        ),
        7001: Documentation(
            message: "Please cancel active orders or close positions before modifying position mode",
            details: "Cancel active orders and close or finish positions before changing position mode."
        ),
        7002: Documentation(
            message: "Position mode mismatch, please switch position mode",
            details: "The order position mode does not match the account setting. Switch to Hedge Mode or One-way Mode as required, or align the positionMode parameter with the account."
        ),
        7003: Documentation(
            message: "The new order type must be consistent with the existing order or the opening type of position",
            details: "The request conflicts with open orders, positions, leverage, or margin requirements. Check position mode, open type, leverage consistency, and minimum order amount."
        ),
        7004: Documentation(
            message: "The new order leverage must be consistent with the existing order or the leverage of the position",
            details: "The request conflicts with open orders, positions, leverage, or margin requirements. Check position mode, open type, leverage consistency, and minimum order amount."
        ),
        7005: Documentation(
            message: "The position amount for closing is insufficient, please check the position or the pending order",
            details: "The request conflicts with open orders, positions, leverage, or margin requirements. Check position mode, open type, leverage consistency, and minimum order amount."
        ),
        7008: Documentation(
            message: "Cannot be less than the minimum order amount {value} USDT",
            details: "The request conflicts with open orders, positions, leverage, or margin requirements. Check position mode, open type, leverage consistency, and minimum order amount."
        ),
        7009: Documentation(
            message: "Your leverage ratio (position value/wallet balance) is too high. Please close positions, make a transfer, or deposit funds first.",
            details: "The request conflicts with open orders, positions, leverage, or margin requirements. Check position mode, open type, leverage consistency, and minimum order amount."
        ),
        8002: Documentation(
            message: "Invalid state",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8003: Documentation(
            message: "User mismatch",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8004: Documentation(
            message: "No rewards to claim",
            details: "The reward cannot be claimed under current conditions. Check eligibility, whether rewards were already claimed, expiration, and activity rules."
        ),
        8005: Documentation(
            message: "Activity does not exist",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8006: Documentation(
            message: "Event rewards has been received",
            details: "The reward cannot be claimed under current conditions. Check eligibility, whether rewards were already claimed, expiration, and activity rules."
        ),
        8007: Documentation(
            message: "The event has concluded",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8008: Documentation(
            message: "Not participating in event",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8009: Documentation(
            message: "The tournament does not exist",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8010: Documentation(
            message: "Exceeded the registration time for the tournament",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8011: Documentation(
            message: "Multiple registrations are not supported",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8012: Documentation(
            message: "Insufficient available margin",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8016: Documentation(
            message: "Activity in preparation. Please try again later",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8017: Documentation(
            message: "Activity has ended.",
            details: "The event or campaign is not in a valid registration or participation window. Check event status and timing."
        ),
        8019: Documentation(
            message: "You are not entitled to participate in this activity. Please contact customer service for more details.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8020: Documentation(
            message: "The sub-account cannot participate in this activity.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8021: Documentation(
            message: "Claim failed. Please contact customer service.",
            details: "The reward cannot be claimed under current conditions. Check eligibility, whether rewards were already claimed, expiration, and activity rules."
        ),
        8022: Documentation(
            message: "The rewards of this activity have been claimed. Please come back next time. Thank you for your support.",
            details: "The reward cannot be claimed under current conditions. Check eligibility, whether rewards were already claimed, expiration, and activity rules."
        ),
        8023: Documentation(
            message: "Today's activity reward has been claimed. Please come back tomorrow. Thank you for your support.",
            details: "The reward cannot be claimed under current conditions. Check eligibility, whether rewards were already claimed, expiration, and activity rules."
        ),
        8024: Documentation(
            message: "You are not a new user and cannot participate in this activity.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8025: Documentation(
            message: "This activity is not available in your country or region.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8026: Documentation(
            message: "This rule already exists.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8027: Documentation(
            message: "You've created the maximum number of rules.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8028: Documentation(
            message: "Insufficient deposit. Failed to claim reward.",
            details: "The reward cannot be claimed under current conditions. Check eligibility, whether rewards were already claimed, expiration, and activity rules."
        ),
        8029: Documentation(
            message: "Registration is unavailable for the country you're located",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8030: Documentation(
            message: "Event has not started",
            details: "The event or campaign is not in a valid registration or participation window. Check event status and timing."
        ),
        8031: Documentation(
            message: "Event has ended",
            details: "The event or campaign is not in a valid registration or participation window. Check event status and timing."
        ),
        8032: Documentation(
            message: "Lucky draw has not been enabled",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8033: Documentation(
            message: "Registration unsuccessful",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8034: Documentation(
            message: "Daily trading limit has not met the requirement",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8035: Documentation(
            message: "Prize pool has been fully redeemed",
            details: "The reward cannot be claimed under current conditions. Check eligibility, whether rewards were already claimed, expiration, and activity rules."
        ),
        8036: Documentation(
            message: "Lucky Spin chances are used up",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8037: Documentation(
            message: "Cannot participate in multiple competitions at the same time",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8038: Documentation(
            message: "The match has started",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8040: Documentation(
            message: "Reward can't be claimed as it has expired",
            details: "The event or campaign is not in a valid registration or participation window. Check event status and timing."
        ),
        8041: Documentation(
            message: "You've successfully redeemed the reward, which will be distributed within 24 hours after the daily event ends. If the reward isn't credited to your account within 24 hours, it might have triggered the risk control system.",
            details: "The reward cannot be claimed under current conditions. Check eligibility, whether rewards were already claimed, expiration, and activity rules."
        ),
        8043: Documentation(
            message: "We're sorry, you haven't reached the minimum trading volume.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8044: Documentation(
            message: "We're sorry, but the reward has been claimed. Please stay tuned for upcoming rewards.",
            details: "The reward cannot be claimed under current conditions. Check eligibility, whether rewards were already claimed, expiration, and activity rules."
        ),
        8045: Documentation(
            message: "We are excited to see you complete the tasks and receive your rewards",
            details: "The reward cannot be claimed under current conditions. Check eligibility, whether rewards were already claimed, expiration, and activity rules."
        ),
        8046: Documentation(
            message: "There's no check-in event on the day",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8047: Documentation(
            message: "We're sorry, you haven't reached the minimum trading volume of this checkpoint.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8048: Documentation(
            message: "Exceeded the maximum number of {count} trading pairs for price alerts!",
            details: "The price or indicator alert limit was exceeded. Reduce the number of alerts or remove existing ones before adding new alerts."
        ),
        8049: Documentation(
            message: "Exceeded the maximum number of {count} price alerts supported for a single futures!",
            details: "The price or indicator alert limit was exceeded. Reduce the number of alerts or remove existing ones before adding new alerts."
        ),
        8050: Documentation(
            message: "The maximum number of indicator alerts is {count}",
            details: "The price or indicator alert limit was exceeded. Reduce the number of alerts or remove existing ones before adding new alerts."
        ),
        8051: Documentation(
            message: "Team does not exist",
            details: "The team operation failed. Check team code, membership status, timing rules, and team leader permissions."
        ),
        8052: Documentation(
            message: "Min. team member requirement not met",
            details: "The team operation failed. Check team code, membership status, timing rules, and team leader permissions."
        ),
        8053: Documentation(
            message: "Not within the allowed time frame",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8054: Documentation(
            message: "Incorrect team code",
            details: "The team operation failed. Check team code, membership status, timing rules, and team leader permissions."
        ),
        8055: Documentation(
            message: "Application already exists",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8056: Documentation(
            message: "You have already joined a team",
            details: "The team operation failed. Check team code, membership status, timing rules, and team leader permissions."
        ),
        8057: Documentation(
            message: "Unable to leave after the team is formed",
            details: "The team operation failed. Check team code, membership status, timing rules, and team leader permissions."
        ),
        8058: Documentation(
            message: "Unable to leave as the event is about to start",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8059: Documentation(
            message: "No team creation request to cancel",
            details: "The team operation failed. Check team code, membership status, timing rules, and team leader permissions."
        ),
        8060: Documentation(
            message: "Status changed. Please refresh and try again.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8061: Documentation(
            message: "Record does not exist",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8062: Documentation(
            message: "Team leader cannot leave the team",
            details: "The team operation failed. Check team code, membership status, timing rules, and team leader permissions."
        ),
        8063: Documentation(
            message: "Team Leader cannot transfer to themselves",
            details: "The team operation failed. Check team code, membership status, timing rules, and team leader permissions."
        ),
        8064: Documentation(
            message: "Withdrawal limit exceeded",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8065: Documentation(
            message: "Action limit exceeded",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8066: Documentation(
            message: "Not part of the team",
            details: "The team operation failed. Check team code, membership status, timing rules, and team leader permissions."
        ),
        8067: Documentation(
            message: "Members who are removed from a team will need to wait 24 hours before joining a new team",
            details: "The team operation failed. Check team code, membership status, timing rules, and team leader permissions."
        ),
        8068: Documentation(
            message: "Withdrawal period has ended. Unable to leave team.",
            details: "The event or campaign is not in a valid registration or participation window. Check event status and timing."
        ),
        8069: Documentation(
            message: "Minimum headcount reached. You can leave once a new member joins.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8098: Documentation(
            message: "You can't take part in this event at the moment. For more details, please contact Customer Service.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8099: Documentation(
            message: "You can't take part in this event at the moment. For more details, please contact Customer Service.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8100: Documentation(
            message: "Insufficient Points",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8101: Documentation(
            message: "No draws available. Please try again later.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8102: Documentation(
            message: "Insufficient Picks",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8201: Documentation(
            message: "Today's Prize Pool Fully Claimed",
            details: "The reward cannot be claimed under current conditions. Check eligibility, whether rewards were already claimed, expiration, and activity rules."
        ),
        8202: Documentation(
            message: "Recommended",
            details: "The event or campaign is not in a valid registration or participation window. Check event status and timing."
        ),
        8815: Documentation(
            message: "Current positions exceeded the maximum number of positions {amount}{currency} that can be held at the target leverage",
            details: "The leverage exceeds allowed limits for your region or current position. Reduce leverage or adjust position size according to contract and account rules."
        ),
        8816: Documentation(
            message: "Exceeded the maximum number of positions {amount}{currency} that can be held at this leverage",
            details: "The leverage exceeds allowed limits for your region or current position. Reduce leverage or adjust position size according to contract and account rules."
        ),
        8817: Documentation(
            message: "Risk limiting mechanism has been upgraded. Please check the website for more information.",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8818: Documentation(
            message: "Current positions exceeded the maximum number of contracts {amount} that can be held at the target leverage",
            details: "The leverage exceeds allowed limits for your region or current position. Reduce leverage or adjust position size according to contract and account rules."
        ),
        8819: Documentation(
            message: "Exceeded the maximum number of contracts {amount} that can be held at this leverage",
            details: "The leverage exceeds allowed limits for your region or current position. Reduce leverage or adjust position size according to contract and account rules."
        ),
        8820: Documentation(
            message: "Due to risk control measures, your account has reached the maximum position limit and cannot open additional positions",
            details: "Risk controls may restrict opening or closing for this symbol or account. Check platform notices and symbol trading status."
        ),
        8821: Documentation(
            message: "The current position quantity exceeds the maximum position quantity allowed for the target leverage. The current maximum leverage that can be set is {leverage}.",
            details: "The leverage exceeds allowed limits for your region or current position. Reduce leverage or adjust position size according to contract and account rules."
        ),
        8823: Documentation(
            message: "This Futures pair will be delisted. New positions cannot be opened. Existing positions remain unaffected. Please close them positions before settlement to avoid potential losses.",
            details: "The contract may be delisted or not yet listed. Check contract status; new positions may be disabled while existing positions may still be managed according to platform rules."
        ),
        8900: Documentation(
            message: "You need to complete the advanced KYC to participate in the event",
            details: "Advanced KYC may be required to participate. Check verification status and complete KYC if needed."
        ),
        8901: Documentation(
            message: "Registered already!",
            details: "The event or campaign is not in a valid registration or participation window. Check event status and timing."
        ),
        8902: Documentation(
            message: "The event has expired!",
            details: "The event or campaign is not in a valid registration or participation window. Check event status and timing."
        ),
        8903: Documentation(
            message: "The event hasn't started yet!",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8904: Documentation(
            message: "The event has ended!",
            details: "The event or campaign is not in a valid registration or participation window. Check event status and timing."
        ),
        8905: Documentation(
            message: "Sorry, you're not eligible for the event!",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8906: Documentation(
            message: "Unable to access your info!",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8907: Documentation(
            message: "Unable to access your asset info!",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8908: Documentation(
            message: "You haven't activated the Futures account yet!",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8909: Documentation(
            message: "To take part in the event, your USDT-M Futures account equity shall be greater than {minEquity} USDT, please try again after making transfer!",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8910: Documentation(
            message: "Unable to access your country code!",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8911: Documentation(
            message: "Unable to access your Futures settings info!",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8912: Documentation(
            message: "Automatically cancelled as position has been closed",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8913: Documentation(
            message: "Manually cancelled by user",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8915: Documentation(
            message: "Leverage mode cannot be changed as there is an active order or position. Please cancel the order or close the position first.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8916: Documentation(
            message: "The file size exceeds the limit and cannot be generated, or has not been generated yet. Please download it from the web version or try again later.",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8917: Documentation(
            message: "The reduce-only order would lead to insufficient position margin for existing orders",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8918: Documentation(
            message: "Queries for market makers or particular users are not currently supported",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8919: Documentation(
            message: "Exceeds the maximum value limit for position and open order values across all trading pairs for a single user",
            details: "The activity or campaign request could not be completed. Check eligibility, account type, event status, and required conditions. Contact MEXC customer service or API support if the issue persists."
        ),
        8920: Documentation(
            message: "Due to market risk controls, only closing positions is allowed for this pair",
            details: "Market risk controls currently allow only closing positions for this pair. Manage existing positions accordingly; opening new positions may be temporarily disabled."
        ),
        8921: Documentation(
            message: "Due to market risk controls, only opening positions is allowed for this pair",
            details: "Market risk controls currently allow only opening positions for this pair. Check platform notices before placing orders."
        ),
        8922: Documentation(
            message: "Trading for this pair is suspended. Wait for trading to resume.",
            details: "Trading for this pair is suspended. Wait for trading to resume and check platform announcements."
        ),
        8925: Documentation(
            message: "Unable to export further as the remaining export quota for this month is 0!",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8926: Documentation(
            message: "There is no data available for export in this time period. Please select a different time range for export.",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8927: Documentation(
            message: "The number of data entries exported this time is too high. Please try reducing the export time range and exporting the data in batches.",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8928: Documentation(
            message: "Single file download limit exceeded. Please apply to export reward history again.",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8929: Documentation(
            message: "An export task is already in progress",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8930: Documentation(
            message: "Not yet listed, unable to place an order",
            details: "The contract may be delisted or not yet listed. Check contract status; new positions may be disabled while existing positions may still be managed according to platform rules."
        ),
        8931: Documentation(
            message: "Your leverage exceeds the maximum limit of {max}x in your country/region. Please adjust your leverage and try again.",
            details: "The leverage exceeds allowed limits for your region or current position. Reduce leverage or adjust position size according to contract and account rules."
        ),
        8932: Documentation(
            message: "Due to risk controls, opening new positions for this pair is temporarily disabled. Only closing is allowed.",
            details: "Risk controls may restrict opening or closing for this symbol or account. Check platform notices and symbol trading status."
        ),
        8933: Documentation(
            message: "This event futures is currently unavailable for trading",
            details: "Event Futures parameters or limits were exceeded. Check quantity range, daily limits, payout rate, time unit, and trading hours."
        ),
        8934: Documentation(
            message: "Position opening is prohibited",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8935: Documentation(
            message: "Number of open positions for event futures exceeds the limit {limit}",
            details: "Event Futures parameters or limits were exceeded. Check quantity range, daily limits, payout rate, time unit, and trading hours."
        ),
        8936: Documentation(
            message: "Quantity must be between {min} and {max} {settleCoin}",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8937: Documentation(
            message: "Today's loss exceeds the limit: {loseLimit} {settleCoin}",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8938: Documentation(
            message: "Payout has changed. Please refresh the page and try again.",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8939: Documentation(
            message: "Time unit has changed. Please refresh the page and try again.",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8940: Documentation(
            message: "Invalid direction selection",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8941: Documentation(
            message: "This event futures does not exist",
            details: "Event Futures parameters or limits were exceeded. Check quantity range, daily limits, payout rate, time unit, and trading hours."
        ),
        8942: Documentation(
            message: "Invalid payout rate",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8943: Documentation(
            message: "Invalid time unit",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8944: Documentation(
            message: "Invalid quantity precision",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8945: Documentation(
            message: "Daily profit has exceeded the maximum threshold of {dailyProfitUpperLimit} USDT.",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8946: Documentation(
            message: "The number of open positions for Event Futures has exceeded the daily limit of {dailyOpenPositionUpperLimit}.",
            details: "Event Futures parameters or limits were exceeded. Check quantity range, daily limits, payout rate, time unit, and trading hours."
        ),
        8948: Documentation(
            message: "Trading for this pair is about to close for the selected time period. Placing orders will be disabled during this period.",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8949: Documentation(
            message: "This trading pair is outside trading hours. Placing orders is disabled.",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        8950: Documentation(
            message: "For risk management reasons, opening positions for this trading pair is unavailable in your country or region. You may only close existing positions.",
            details: "Position or risk limits were exceeded. Check leverage, risk limit tier, maximum position size, and account exposure."
        ),
        9065: Documentation(
            message: "Transfer failed due to risk control. Please contact Customer Service.",
            details: "The transfer could not be completed. Check balance, risk controls, and transfer parameters. Query transfer history before retrying."
        ),
        9066: Documentation(
            message: "Transfer failed. Insufficient balance.",
            details: "The transfer could not be completed. Check balance, risk controls, and transfer parameters. Query transfer history before retrying."
        ),
        9067: Documentation(
            message: "Transfer failed",
            details: "The transfer could not be completed. Check balance, risk controls, and transfer parameters. Query transfer history before retrying."
        ),
        9068: Documentation(
            message: "Trading unavailable due to market closure. Only order cancellations are allowed; new orders cannot be placed.",
            details: "Trading may be suspended during market closure. Check market hours; only certain operations such as cancel may be allowed."
        ),
        9069: Documentation(
            message: "This trading pair only supports TP/SL triggered by fair price.",
            details: "The request conflicts with market status, margin mode, or trigger price rules. Check contract settings and platform trading hours."
        ),
        9070: Documentation(
            message: "This pair supports Isolated Margin mode only",
            details: "The symbol supports only the specified margin mode (Isolated or Cross). Align openType with contract and account settings."
        ),
        9071: Documentation(
            message: "This pair supports Cross Margin mode only",
            details: "The symbol supports only the specified margin mode (Isolated or Cross). Align openType with contract and account settings."
        ),
        9073: Documentation(
            message: "Stock Futures trading is suspended during market closure. You can view positions but cannot open or close them. Check the page for market hours.",
            details: "Trading may be suspended during market closure. Check market hours; only certain operations such as cancel may be allowed."
        ),
        9074: Documentation(
            message: "Guaranteed Stop-Loss is currently unavailable",
            details: "The request conflicts with market status, margin mode, or trigger price rules. Check contract settings and platform trading hours."
        ),
        9075: Documentation(
            message: "Stop-Loss trigger price can only be set to the last price",
            details: "The request conflicts with market status, margin mode, or trigger price rules. Check contract settings and platform trading hours."
        ),
        9501: Documentation(
            message: "Unable to create bot due to risk control reasons. Please contact Customer Service.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9502: Documentation(
            message: "Grid count must not exceed {MaxGridQty}.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9503: Documentation(
            message: "Grid count too high. Unable to create bot.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9504: Documentation(
            message: "Price range below limit: {DownPriceLimit}.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9505: Documentation(
            message: "Price range exceeds limit: {UperPriceLimit}.",
            details: "The grid bot price range exceeds the allowed upper limit. Check the upper price limit parameter returned by the API and adjust the price range accordingly."
        ),
        9506: Documentation(
            message: "Investment must exceed {MinInvestment} {currency}.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9507: Documentation(
            message: "Sub-account retrieval failed. Cannot create grid.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9508: Documentation(
            message: "A maximum of {NoOfBots} bots can run simultaneously.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9509: Documentation(
            message: "Rejected: Bot already running.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9510: Documentation(
            message: "Rejected: Bot already stopped.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9511: Documentation(
            message: "Rejected: Withdrawable amount exceeds {MaxWithdrawable} {currency}.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9512: Documentation(
            message: "Rejected: Invalid stop price.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9513: Documentation(
            message: "Bot trading is not currently supported in sub-accounts.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9514: Documentation(
            message: "The TP amount is invalid and will cause the bot to stop immediately",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9515: Documentation(
            message: "The SL amount is invalid and will cause the bot to stop immediately",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9516: Documentation(
            message: "The bot is not running and cannot be modified",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9517: Documentation(
            message: "The TP PNL rate is invalid and will cause the bot to stop immediately",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9518: Documentation(
            message: "The SL PNL rate is invalid and will cause the bot to stop immediately",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9530: Documentation(
            message: "Market closed. Failed to activate bot.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9531: Documentation(
            message: "Market closed. Activation price cannot be modified.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9532: Documentation(
            message: "Stock Futures grid bot creation unavailable yet",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9533: Documentation(
            message: "Trading is currently closed for this pair. Claim another trading pair.",
            details: "The grid bot request could not be completed. Check grid count, price range, investment amount, bot limits, sub-account restrictions, TP/SL settings, and whether the market is open for the symbol."
        ),
        9901: Documentation(
            message: "Spot & Earn asset processing timed out. Please check your assets and wait for updates.",
            details: "An operation involving Spot or Earn assets failed or timed out. Check Spot/Earn balance, Multi-Asset mode restrictions, and order or margin status before retrying to avoid duplicate actions."
        ),
        9902: Documentation(
            message: "Trading with Spot and Earn assets is not supported",
            details: "An operation involving Spot or Earn assets failed or timed out. Check Spot/Earn balance, Multi-Asset mode restrictions, and order or margin status before retrying to avoid duplicate actions."
        ),
        9903: Documentation(
            message: "Spot or Earn assets cannot be used to open positions under Multi-Assets Mode",
            details: "An operation involving Spot or Earn assets failed or timed out. Check Spot/Earn balance, Multi-Asset mode restrictions, and order or margin status before retrying to avoid duplicate actions."
        ),
        9904: Documentation(
            message: "Open Position With Earn & Spot Assets",
            details: "An operation involving Spot or Earn assets failed or timed out. Check Spot/Earn balance, Multi-Asset mode restrictions, and order or margin status before retrying to avoid duplicate actions."
        ),
        9905: Documentation(
            message: "Earn Redemption Failed",
            details: "An operation involving Spot or Earn assets failed or timed out. Check Spot/Earn balance, Multi-Asset mode restrictions, and order or margin status before retrying to avoid duplicate actions."
        ),
        9906: Documentation(
            message: "{side} {symbol} order failed while using Earn & Spot assets",
            details: "An operation involving Spot or Earn assets failed or timed out. Check Spot/Earn balance, Multi-Asset mode restrictions, and order or margin status before retrying to avoid duplicate actions."
        ),
        9907: Documentation(
            message: "Spot Transfer Failed",
            details: "An operation involving Spot or Earn assets failed or timed out. Check Spot/Earn balance, Multi-Asset mode restrictions, and order or margin status before retrying to avoid duplicate actions."
        ),
        9908: Documentation(
            message: "Successfully opened a position using Earn & Spot assets",
            details: "The operation may have completed successfully. Verify position, order, or margin status in the account before retrying any related action."
        ),
        9909: Documentation(
            message: "{side} {symbol} order placed successfully using Earn & Spot assets",
            details: "The operation may have completed successfully. Verify position, order, or margin status in the account before retrying any related action."
        ),
        9910: Documentation(
            message: "Spot Transfer Timeout",
            details: "An operation involving Spot or Earn assets failed or timed out. Check Spot/Earn balance, Multi-Asset mode restrictions, and order or margin status before retrying to avoid duplicate actions."
        ),
        9911: Documentation(
            message: "{side} {symbol} order failed while using Earn & Spot assets. Please check your assets and try again.",
            details: "An operation involving Spot or Earn assets failed or timed out. Check Spot/Earn balance, Multi-Asset mode restrictions, and order or margin status before retrying to avoid duplicate actions."
        ),
        9912: Documentation(
            message: "Order Failed",
            details: "An operation involving Spot or Earn assets failed or timed out. Check Spot/Earn balance, Multi-Asset mode restrictions, and order or margin status before retrying to avoid duplicate actions."
        ),
        9913: Documentation(
            message: "Add Margin with Earn & Spot (Isolated)",
            details: "An operation involving Spot or Earn assets failed or timed out. Check Spot/Earn balance, Multi-Asset mode restrictions, and order or margin status before retrying to avoid duplicate actions."
        ),
        9914: Documentation(
            message: "Failed to add margin in Isolated mode using Earn & Spot assets for {symbol} {side}",
            details: "An operation involving Spot or Earn assets failed or timed out. Check Spot/Earn balance, Multi-Asset mode restrictions, and order or margin status before retrying to avoid duplicate actions."
        ),
        9915: Documentation(
            message: "Added Margin with Earn & Spot (Isolated)",
            details: "The operation may have completed successfully. Verify position, order, or margin status in the account before retrying any related action."
        ),
        9916: Documentation(
            message: "Successfully added margin in Isolated mode using Earn & Spot assets for {symbol} {side}",
            details: "The operation may have completed successfully. Verify position, order, or margin status in the account before retrying any related action."
        ),
        9917: Documentation(
            message: "Failed to add margin in Isolated mode using Earn & Spot assets for {symbol} {side}",
            details: "An operation involving Spot or Earn assets failed or timed out. Check Spot/Earn balance, Multi-Asset mode restrictions, and order or margin status before retrying to avoid duplicate actions."
        ),
        9918: Documentation(
            message: "Failed to Add Isolated Margin",
            details: "An operation involving Spot or Earn assets failed or timed out. Check Spot/Earn balance, Multi-Asset mode restrictions, and order or margin status before retrying to avoid duplicate actions."
        ),
        9998: Documentation(
            message: "Only position closing is supported, as the platform does not support other operations in your current country/region",
            details: "Only position closing may be supported in your country or region. Check regional restrictions and platform announcements."
        ),
        9999: Documentation(
            message: "Network error. Please try again.",
            details: "A network error occurred. Retry later and check connectivity. Query operation result before resubmitting."
        ),
        11444: Documentation(
            message: "This feature is temporarily unavailable. For details, please refer to our official announcement. Thank you for your understanding and cooperation.",
            details: "This feature is temporarily unavailable. Check official MEXC announcements and retry later. Contact MEXC customer service or API support if you need further clarification."
        ),
        200005: Documentation(
            message: "To further enhance the security of user accounts and assets, and better protect the rights and interests of our users, please complete KYC verification before proceeding with futures trading. Thank you for your understanding and support!",
            details: "KYC verification may be required before using this Futures feature. Check KYC status in your account and complete verification if needed. Contact MEXC customer service or API support if verification is already completed."
        ),
        200006: Documentation(
            message: "Please complete KYC verification to access platform services and features and enhance your account security.",
            details: "KYC verification may be required before using this Futures feature. Check KYC status in your account and complete verification if needed. Contact MEXC customer service or API support if verification is already completed."
        ),
        300000: Documentation(
            message: "Please complete KYC verification to access platform services and features and enhance your account security.",
            details: "KYC verification may be required before using this Futures feature. Check KYC status in your account and complete verification if needed. Contact MEXC customer service or API support if verification is already completed."
        ),
        300001: Documentation(
            message: "To further enhance the security of user accounts and assets, and better protect the rights and interests of our users, please complete KYC verification before participating. Thank you for your understanding and support!",
            details: "KYC verification may be required before using this Futures feature. Check KYC status in your account and complete verification if needed. Contact MEXC customer service or API support if verification is already completed."
        ),
        300002: Documentation(
            message: "Due to the relevant regulations, this service is not supported in your region",
            details: "This service may not be available in your region due to regulatory restrictions. Check account region settings and platform announcements."
        ),
    ]
}
