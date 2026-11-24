public import Foundation

// MARK: - Model

extension MexcFutures {
    /// The futures account's holdings of one asset.
    ///
    /// The optional properties are in MEXC's documentation but not yet in a recorded response; `nil`
    /// means the response didn't include the field.
    public struct Balance: Hashable, Sendable {
        /// The asset, such as `"USDT"`.
        public let asset: String
        /// The balance free to use, in MEXC's words "currently available".
        public let available: Decimal
        /// The balance held by pending orders.
        public let frozen: Decimal
        /// The margin held by open positions.
        public let positionMargin: Decimal
        /// MEXC's cash balance, which it describes as the withdrawable balance.
        public let cash: Decimal
        /// MEXC's total equity.
        public let equity: Decimal
        /// The unrealized profit of open positions; negative for a loss.
        public let unrealizedProfit: Decimal
        /// The amount that can be transferred out of the futures account.
        public let transferable: Decimal?
        /// MEXC's "usable amount".
        public let availableToOpen: Decimal?
        /// MEXC's trial bonus.
        public let bonus: Decimal?
        /// When the trial bonus expires.
        public let bonusExpiresAt: Date?
        /// MEXC's "debt amount".
        public let debt: Decimal?
        /// MEXC's "contributed effective margin".
        public let contributedMargin: Decimal?

        public init(
            asset: String, available: Decimal, frozen: Decimal, positionMargin: Decimal, cash: Decimal,
            equity: Decimal, unrealizedProfit: Decimal, transferable: Decimal?, availableToOpen: Decimal?,
            bonus: Decimal?, bonusExpiresAt: Date?, debt: Decimal?, contributedMargin: Decimal?
        ) {
            self.asset = asset
            self.available = available
            self.frozen = frozen
            self.positionMargin = positionMargin
            self.cash = cash
            self.equity = equity
            self.unrealizedProfit = unrealizedProfit
            self.transferable = transferable
            self.availableToOpen = availableToOpen
            self.bonus = bonus
            self.bonusExpiresAt = bonusExpiresAt
            self.debt = debt
            self.contributedMargin = contributedMargin
        }
    }
}

// MARK: - Wire

extension MexcFutures.Balance: Decodable {
    private enum CodingKeys: String, CodingKey {
        case currency, availableBalance, frozenBalance, positionMargin, cashBalance, equity, unrealized
        case availableCash, availableOpen, bonus, bonusExpireTime, debtAmount, contributeMarginAmount
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        asset = try container.decode(String.self, forKey: .currency)
        available = try container.decimal(forKey: .availableBalance)
        frozen = try container.decimal(forKey: .frozenBalance)
        positionMargin = try container.decimal(forKey: .positionMargin)
        cash = try container.decimal(forKey: .cashBalance)
        equity = try container.decimal(forKey: .equity)
        unrealizedProfit = try container.decimal(forKey: .unrealized)
        transferable = try container.decimalIfPresent(forKey: .availableCash)
        availableToOpen = try container.decimalIfPresent(forKey: .availableOpen)
        bonus = try container.decimalIfPresent(forKey: .bonus)
        bonusExpiresAt = try container.millisecondDateIfPresent(forKey: .bonusExpireTime)
        debt = try container.decimalIfPresent(forKey: .debtAmount)
        contributedMargin = try container.decimalIfPresent(forKey: .contributeMarginAmount)
    }
}
