import Foundation

public final class StockPriceService: Sendable {
    public static let shared = StockPriceService()
    
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Public API
    
    public static func fetchCurrentPrice(for symbol: String) async throws -> Double {
        return try await shared.fetchCurrentPrice(for: symbol)
    }
    
    public func fetchCurrentPrice(for symbol: String) async throws -> Double {
        let quote = try await fetchPrice(for: symbol)
        return quote.currentPrice
    }
    
    public func fetchPrice(for symbol: String) async throws -> StockQuote {
        let formattedSymbol = formatSymbol(symbol)
        
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(formattedSymbol)?interval=1d&range=1d") else {
            throw StockPriceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw StockPriceError.networkError
        }
        
        let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
        
        guard let result = decoded.chart.result?.first,
              let currentPrice = result.meta.regularMarketPrice else {
            throw StockPriceError.noDataAvailable
        }
        
        return StockQuote(
            symbol: result.meta.symbol ?? formattedSymbol,
            currentPrice: currentPrice,
            previousClose: result.meta.chartPreviousClose ?? result.meta.previousClose,
            currency: result.meta.currency ?? "INR"
        )
    }
    
    public static func fetchHistoricalPrice(for symbol: String, on date: Date) async throws -> Double {
        return try await shared.fetchHistoricalPrice(for: symbol, on: date)
    }
    
    public func fetchHistoricalPrice(for symbol: String, on date: Date) async throws -> Double {
        let formattedSymbol = formatSymbol(symbol)
        
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -3, to: date) ?? date
        let endDate = calendar.date(byAdding: .day, value: 4, to: date) ?? date
        
        let period1 = Int(startDate.timeIntervalSince1970)
        let period2 = Int(endDate.timeIntervalSince1970)
        
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(formattedSymbol)?period1=\(period1)&period2=\(period2)&interval=1d") else {
            throw StockPriceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw StockPriceError.networkError
        }
        
        let decoded = try JSONDecoder().decode(YahooHistoricalChartResponse.self, from: data)
        
        guard let result = decoded.chart.result?.first,
              let timestamps = result.timestamp,
              let closes = result.indicators.quote.first?.close,
              !timestamps.isEmpty else {
            throw StockPriceError.noDataAvailable
        }
        
        let targetTimestamp = date.timeIntervalSince1970
        var closestPrice: Double?
        var minDiff = Double.greatestFiniteMagnitude
        
        for (index, ts) in timestamps.enumerated() {
            guard index < closes.count, let price = closes[index] else { continue }
            let diff = abs(Double(ts) - targetTimestamp)
            if diff < minDiff {
                minDiff = diff
                closestPrice = price
            }
        }
        
        guard let finalPrice = closestPrice else {
            throw StockPriceError.noDataAvailable
        }
        
        return finalPrice
    }
    
    private func formatSymbol(_ symbol: String) -> String {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !trimmed.contains(".") && !["AAPL", "MSFT", "GOOG", "AMZN", "TSLA", "NVDA"].contains(trimmed) {
            return "\(trimmed).NS"
        }
        return trimmed
    }
}

// MARK: - Models & Errors

public struct StockQuote: Identifiable, Sendable {
    public var id: String { symbol }
    public let symbol: String
    public let currentPrice: Double
    public let previousClose: Double?
    public let currency: String
    
    public var priceChange: Double? {
        guard let previousClose else { return nil }
        return currentPrice - previousClose
    }
    
    public var percentChange: Double? {
        guard let previousClose, previousClose > 0 else { return nil }
        return ((currentPrice - previousClose) / previousClose) * 100
    }
}

public enum StockPriceError: LocalizedError, Sendable {
    case invalidURL
    case networkError
    case noDataAvailable
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "The stock symbol created an invalid URL."
        case .networkError: return "Failed to reach Yahoo Finance."
        case .noDataAvailable: return "No price data found for this ticker."
        }
    }
}

// MARK: - Yahoo API Decodable Responses (nonisolated, Sendable)

nonisolated struct YahooChartResponse: Decodable, Sendable {
    let chart: ChartResult
    
    struct ChartResult: Decodable, Sendable {
        let result: [QuoteData]?
        let error: YahooError?
    }
    
    struct QuoteData: Decodable, Sendable {
        let meta: Meta
    }
    
    struct Meta: Decodable, Sendable {
        let symbol: String?
        let currency: String?
        let regularMarketPrice: Double?
        let previousClose: Double?
        let chartPreviousClose: Double?
    }
    
    struct YahooError: Decodable, Sendable {
        let code: String
        let description: String
    }
}

nonisolated struct YahooHistoricalChartResponse: Decodable, Sendable {
    let chart: HistoricalChartResult
    
    struct HistoricalChartResult: Decodable, Sendable {
        let result: [HistoricalQuoteData]?
        let error: YahooHistoricalError?
    }
    
    struct HistoricalQuoteData: Decodable, Sendable {
        let timestamp: [Int]?
        let indicators: Indicators
    }
    
    struct Indicators: Decodable, Sendable {
        let quote: [HistoricalQuoteValues]
    }
    
    struct HistoricalQuoteValues: Decodable, Sendable {
        let close: [Double?]?
    }
    
    struct YahooHistoricalError: Decodable, Sendable {
        let code: String
        let description: String
    }
}
