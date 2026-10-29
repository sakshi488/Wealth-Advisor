import Foundation
import SwiftData

@Model
final class Asset {
    var id: UUID
    var name: String
    
    // e.g., "Stock", "Mutual Fund", "Cash"
    var assetType: String
    
    // e.g., "RELIANCE.NS", "TCS.NS"
    var ticker: String
    
    // How many shares do you own?
    var quantity: Double
    
    // Average purchase price per share
    var averagePurchasePrice: Double
    
    // The live market price (we will fetch this from the internet later)
    var currentMarketPrice: Double
    var isDeleted: Bool
    
    init(name: String, assetType: String, ticker: String, quantity: Double, averagePurchasePrice: Double, currentMarketPrice: Double) {
        self.id = UUID()
        self.name = name
        self.assetType = assetType
        self.ticker = ticker.uppercased()
        self.quantity = quantity
        self.averagePurchasePrice = averagePurchasePrice
        self.currentMarketPrice = currentMarketPrice
        self.isDeleted = false
    }
    
    // MARK: - Computed Properties for Analysis
    
    // Total amount currently invested
    var totalInvestmentValue: Double {
        return quantity * averagePurchasePrice
    }
    
    // Current value based on the live market
    var currentMarketValue: Double {
        return quantity * currentMarketPrice
    }
    
    // Total profit or loss in Rupees
    var totalProfitLoss: Double {
        return currentMarketValue - totalInvestmentValue
    }
    
    // Profit or loss as a percentage
    var profitLossPercentage: Double {
        guard totalInvestmentValue > 0 else { return 0 }
        return (totalProfitLoss / totalInvestmentValue) * 100
    }
}
