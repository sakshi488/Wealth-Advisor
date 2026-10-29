import Foundation

struct TickerSearchResult: Identifiable, Codable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let exchange: String
}

// Internal structures to decode Yahoo's search payload
fileprivate struct YahooSearchResponse: Codable {
    let quotes: [YahooSearchQuote]
}

fileprivate struct YahooSearchQuote: Codable {
    let symbol: String
    let shortname: String?
    let longname: String?
    let exchDisp: String?
}

struct TickerSearchService {
    /// Queries Yahoo Finance autocomplete API for matching tickers
    static func search(query: String) async -> [TickerSearchResult] {
        guard !query.isEmpty,
              let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://query1.finance.yahoo.com/v1/finance/search?q=\(encodedQuery)") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }
            
            let decodedResponse = try JSONDecoder().decode(YahooSearchResponse.self, from: data)
            
            // Map the complex API response to our clean TickerSearchResult array
            return decodedResponse.quotes.compactMap { quote in
                guard let name = quote.longname ?? quote.shortname else { return nil }
                return TickerSearchResult(
                    symbol: quote.symbol,
                    name: name,
                    exchange: quote.exchDisp ?? "Unknown"
                )
            }
        } catch {
            print("Ticker search failed: \(error)")
            return []
        }
    }
}
