import Foundation
import GoogleGenerativeAI

struct AIAdvisorService {
    // ⚠️ Keep your actual API key here!
    static let apiKey = "AQ.Ab8RN6KD3EJimCML2ammjyFtWtx8TqbhxFMoubiIo6IPnFK7Jg"
    
    // Using the current 2.5 Flash model
    static let model = GenerativeModel(name: "gemini-2.5-flash", apiKey: apiKey)
    
    /// Generates the hidden background text that tells Gemini what your portfolio looks like
    static func buildPortfolioContext(from assets: [Asset]) -> String {
        var summary = "CONTEXT - Here is the user's current Indian stock market portfolio:\n"
        var totalValue: Double = 0
        
        for asset in assets where !asset.isDeleted {
            summary += "- \(asset.name) (\(asset.ticker)): \(asset.quantity) shares. "
            summary += "Bought at ₹\(asset.averagePurchasePrice), currently trading at ₹\(asset.currentMarketPrice). "
            summary += "Profit/loss: \(String(format: "%.2f", asset.profitLossPercentage))%.\n"
            totalValue += asset.currentMarketValue
        }
        summary += "\nTotal Portfolio Value: ₹\(totalValue)\n"
        summary += "You are an expert financial advisor. Use this context to answer the user's questions. Be concise and actionable."
        
        return summary
    }
}
