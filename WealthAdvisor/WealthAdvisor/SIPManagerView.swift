import SwiftUI
import SwiftData

// MARK: - Isolated Yahoo Finance Models for SIP Manager
struct SIPYahooSearchResponse: Codable {
    let quotes: [SIPYahooQuote]
}

struct SIPYahooQuote: Codable, Identifiable, Hashable {
    var id: String { symbol }
    let symbol: String
    let shortname: String?
    let longname: String?
    let exchDisp: String?
    let quoteType: String?
}

struct SIPManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \SIP.deductionDay) private var sips: [SIP]
    @Query(sort: \Asset.name) private var portfolioAssets: [Asset]
    
    // --- Live Search States ---
    @State private var searchText = ""
    @State private var searchResults: [SIPYahooQuote] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil
    
    // --- Mode & Date States ---
    @State private var inputMode: String = "Amount"
    @State private var inputValue: Double?
    @State private var sipStartDate: Date = Date()
    @State private var isFetchingNAV = false
    
    // --- Shared Form States ---
    @State private var selectedQuote: SIPYahooQuote?
    @State private var buyingPrice: Double?

    var totalMonthlySIP: Double {
        sips.filter { $0.isActive }.reduce(0) { $0 + $1.monthlyAmount }
    }

    var body: some View {
        VStack(spacing: 0) {
            // --- HEADER ---
            HStack {
                VStack(alignment: .leading) {
                    Text("SIP Scheduler & Manager").font(.title2).bold()
                    Text("Total Monthly Commitment: \(totalMonthlySIP, format: .currency(code: "INR"))")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding().background(Color(NSColor.windowBackgroundColor))
            Divider()
            
            // --- ACTIVE SIP CONFIGURATIONS ---
            if sips.isEmpty {
                ContentUnavailableView("No Configured Schedules", systemImage: "calendar.badge.clock", description: Text("Search a live asset below to establish a recurring monthly plan."))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(sips) { sip in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(sip.assetName).font(.headline)
                                Text("\(sip.ticker) • Day \(sip.deductionDay) monthly").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(sip.monthlyAmount, format: .currency(code: "INR")).bold()
                                Text("Next Run: \(sip.nextDeductionDate, format: .dateTime.day().month().year())")
                                    .font(.caption2).padding(4).background(Color.blue.opacity(0.15)).cornerRadius(4)
                            }
                            Button(action: { modelContext.delete(sip) }) { Image(systemName: "trash").foregroundColor(.red) }
                            .buttonStyle(.borderless).padding(.leading, 8)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            
            Divider()
            
            // --- INTELLIGENT INPUT PANEL ---
            VStack(alignment: .leading, spacing: 12) {
                Text("Configure New Systematic Investment Plan").font(.headline)
                
                // Live Market Directory Search View
                if let quote = selectedQuote {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(quote.longname ?? quote.shortname ?? quote.symbol).bold()
                            Text(quote.symbol).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Change Asset") { selectedQuote = nil; searchText = "" }.buttonStyle(.link)
                    }
                    .padding(10).background(Color(NSColor.windowBackgroundColor)).cornerRadius(8)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                            TextField("Search live market assets (e.g., Quant, HDFC)...", text: $searchText)
                                .textFieldStyle(.plain)
                                .onChange(of: searchText) { performSearch(query: searchText) }
                            if isSearching { ProgressView().controlSize(.small) }
                        }
                        .padding(10).background(Color(NSColor.windowBackgroundColor)).cornerRadius(searchResults.isEmpty ? 8 : 0)
                        
                        if !searchResults.isEmpty {
                            List(searchResults) { quote in
                                Button(action: {
                                    selectedQuote = quote
                                    searchResults = []
                                    // Auto-fetch price the moment an asset is clicked!
                                    Task { await autoFetchNAV() }
                                }) {
                                    HStack {
                                        Text(quote.longname ?? quote.shortname ?? quote.symbol).foregroundColor(.primary)
                                        Spacer()
                                        Text(quote.symbol).foregroundColor(.secondary).font(.caption)
                                    }
                                }.buttonStyle(.plain)
                            }
                            .frame(height: 130).border(Color.gray.opacity(0.15))
                        }
                    }
                }
                
                // Segmented Control Selector for Amount vs Units
                Picker("Investment Mode", selection: $inputMode) {
                    Text("Invest Fixed Amount (₹)").tag("Amount")
                    Text("Invest Fixed Units").tag("Units")
                }
                .pickerStyle(.segmented)
                
                // Form Fields Matrix
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text(inputMode == "Amount" ? "Monthly Amount:" : "Monthly Units:")
                            .font(.subheadline).foregroundColor(.secondary)
                        TextField(inputMode == "Amount" ? "e.g. 5000" : "e.g. 25.5", value: $inputValue, format: .number)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("NAV / Share Price:")
                            .font(.subheadline).foregroundColor(.secondary)
                        TextField("e.g. 142.30", value: $buyingPrice, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    GridRow {
                        Text("Plan Start Date:")
                            .font(.subheadline).foregroundColor(.secondary)
                        
                        HStack {
                            DatePicker("", selection: $sipStartDate, displayedComponents: .date)
                                .labelsHidden()
                                .onChange(of: sipStartDate) {
                                    // Re-fetch historical NAV when date changes!
                                    Task { await autoFetchNAV() }
                                }
                            
                            if isFetchingNAV {
                                ProgressView().controlSize(.small).padding(.leading, 4)
                            }
                        }
                        
                        // Empty cells to keep the grid aligned now that the day picker is gone
                        Text("")
                        Text("")
                    }
                }
                .padding(.vertical, 4)
                
                // Computation Preview Strip
                if let price = buyingPrice, let input = inputValue, price > 0 {
                    HStack {
                        Spacer()
                        if inputMode == "Amount" {
                            let computedUnits = input / price
                            let styledUnits = Text("\(String(format: "%.4f", computedUnits)) Units").bold().foregroundColor(.green)
                            Text("Execution Preview: Subscribing to \(styledUnits) at current pricing profiles.")
                        } else {
                            let computedCost = input * price
                            let styledCost = Text(computedCost, format: .currency(code: "INR")).bold().foregroundColor(.green)
                            Text("Execution Preview: Total Outflow will approximate \(styledCost)")
                        }
                        Spacer()
                    }
                    .font(.caption)
                    .padding(6)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(6)
                }
                
                // Submit Form Action
                Button(action: executeSIP) {
                    Text("Initialize Schedule & Log Baseline Units")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedQuote == nil || buyingPrice == nil || inputValue == nil || (buyingPrice ?? 0) <= 0 || (inputValue ?? 0) <= 0)
            }
            .padding().background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 680, height: 620)
    }
    
    // MARK: - Networking Search Engine
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        searchTask = Task {
            await MainActor.run { isSearching = true }
            
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                
                let safeQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
                let urlString = "https://query2.finance.yahoo.com/v1/finance/search?q=\(safeQuery)&quotesCount=15"
                guard let url = URL(string: urlString) else { return }
                
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoded = try JSONDecoder().decode(SIPYahooSearchResponse.self, from: data)
                
                let indians = decoded.quotes.filter {
                    $0.symbol.hasSuffix(".NS") ||
                    $0.symbol.hasSuffix(".BO") ||
                    $0.exchDisp == "NSE" ||
                    $0.exchDisp == "BSE"
                }
                
                await MainActor.run {
                    self.searchResults = indians.isEmpty ? decoded.quotes : indians
                    self.isSearching = false
                }
            } catch {
                await MainActor.run { self.isSearching = false }
            }
        }
    }
    
    // MARK: - Auto-NAV Fetcher
    private func autoFetchNAV() async {
        guard let quote = selectedQuote else { return }
        await MainActor.run { isFetchingNAV = true }
        
        do {
            let fetchedPrice: Double
            if Calendar.current.isDateInToday(sipStartDate) {
                fetchedPrice = try await StockPriceService.fetchCurrentPrice(for: quote.symbol)
            } else {
                fetchedPrice = try await StockPriceService.fetchHistoricalPrice(for: quote.symbol, on: sipStartDate)
            }
            await MainActor.run {
                self.buyingPrice = fetchedPrice
                self.isFetchingNAV = false
            }
        } catch {
            await MainActor.run { self.isFetchingNAV = false }
        }
    }
    
    // MARK: - Mathematical Computation & Execution Engine
    private func executeSIP() {
        guard let quote = selectedQuote, let price = buyingPrice, let input = inputValue else { return }
        let finalTicker = quote.symbol.uppercased()
        
        let totalAmt = inputMode == "Amount" ? input : (price * input)
        let calculatedQty = inputMode == "Amount" ? (input / price) : input
        let finalName = quote.longname ?? quote.shortname ?? quote.symbol
        
        let extractedDay = Calendar.current.component(.day, from: sipStartDate)
        
        // 1. Establish the schedule
        if !sips.contains(where: { $0.ticker == finalTicker }) {
            let newSIP = SIP(assetName: finalName, ticker: finalTicker, monthlyAmount: totalAmt, deductionDay: extractedDay, startDate: sipStartDate)
            newSIP.lastExecutedDate = sipStartDate
            modelContext.insert(newSIP)
        }
        
        // 2. Adjust Balance Ledger
        if let existing = portfolioAssets.first(where: { $0.ticker == finalTicker && !$0.isDeleted }) {
            let newTotalValue = (existing.quantity * existing.averagePurchasePrice) + totalAmt
            existing.quantity += calculatedQty
            existing.averagePurchasePrice = newTotalValue / existing.quantity
            existing.currentMarketPrice = price
        } else {
            let assetType = (quote.quoteType == "MUTUALFUND") ? "Mutual Fund" : "Stock"
            let newAsset = Asset(name: finalName, assetType: assetType, ticker: finalTicker, quantity: calculatedQty, averagePurchasePrice: price, currentMarketPrice: price)
            modelContext.insert(newAsset)
        }
        
        // 3. Reset UI (SAFELY INSIDE THE FUNCTION)
        selectedQuote = nil
        searchText = ""
        buyingPrice = nil
        inputValue = nil
    }
}
