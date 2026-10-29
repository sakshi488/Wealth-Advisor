import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Query(sort: \PortfolioSnapshot.date) private var snapshots: [PortfolioSnapshot]
    
    // ADD THIS MISSING LINE RIGHT HERE:
    @Query private var scheduledSIPs: [SIP]
    @State private var performanceAssetToView: Asset?
    @State private var showingAddAsset = false
    @State private var showingAdvisor = false
    // ... rest of the code continues normally
    @State private var isRefreshing = false
    @State private var showingSIPManager = false
    @State private var selectedFilter: String = "All"
    @State private var assetToEdit: Asset?
    // Tracks the current sorting rule (Defaults to sorting by Name A-Z)
    @State private var sortOrder = [KeyPathComparator(\Asset.name)]
    
    @MainActor
        var filteredAssets: [Asset] {
            let activeAssets = assets.filter { !$0.isDeleted }
            
            let result: [Asset]
            if selectedFilter == "Deleted" {
                result = assets.filter { $0.isDeleted }
            } else if selectedFilter == "All" {
                result = activeAssets
            } else {
                result = activeAssets.filter { $0.assetType == selectedFilter }
            }
            
            return result.sorted(using: sortOrder)
        }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // --- NEW TOP SECTION: SIDE-BY-SIDE CHARTS ---
                HStack(spacing: 0) {
                    // Left Side: The existing Donut Chart & Summaries
                    DashboardView(assets: assets.filter { !$0.isDeleted })
                        .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    // Right Side: The NEW Historical Line Chart
                    PerformanceChartView(snapshots: snapshots)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                // --- MIDDLE SECTION: FILTERS ---
                Picker("Filter", selection: $selectedFilter) {
                    Text("All").tag("All")
                    Text("Stocks").tag("Stock")
                    Text("Mutual Funds").tag("Mutual Fund")
                    Text("Deleted").tag("Deleted")
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                
                // --- BOTTOM SECTION: THE TABLE ---
                Table(filteredAssets, sortOrder: $sortOrder) {
                    TableColumn("Name", value: \.name)
                    TableColumn("Ticker", value: \.ticker)
                    
                    TableColumn("Quantity") { asset in Text(asset.quantity, format: .number) }
                    TableColumn("Avg Price") { asset in Text(asset.averagePurchasePrice, format: .currency(code: "INR")) }
                    TableColumn("Live Price") { asset in Text(asset.currentMarketPrice, format: .currency(code: "INR")) }
                    TableColumn("Market Value") { asset in Text(asset.currentMarketValue, format: .currency(code: "INR")) }
                    
                    TableColumn("P/L (%)") { asset in
                        Text("\(asset.profitLossPercentage, specifier: "%.2f")%")
                            .foregroundColor(asset.totalProfitLoss >= 0 ? .green : .red)
                    }
                    
                    TableColumn("Actions") { asset in
                        HStack(spacing: 12) {
                            if asset.isDeleted {
                                Button(action: { asset.isDeleted = false }) { Image(systemName: "arrow.uturn.backward").foregroundColor(.blue) }
                                    .buttonStyle(.borderless).help("Restore")
                                Button(action: { modelContext.delete(asset) }) { Image(systemName: "trash.fill").foregroundColor(.red) }
                                    .buttonStyle(.borderless).help("Permanently Delete")
                            } else {
                                // NEW: The Performance Chart Button
                                Button(action: { performanceAssetToView = asset }) { Image(systemName: "chart.bar.xaxis").foregroundColor(.green) }
                                    .buttonStyle(.borderless).help("View Performance Breakdown")
                                
                                Button(action: { assetToEdit = asset }) { Image(systemName: "pencil") }
                                    .buttonStyle(.borderless).help("Edit")
                                
                                Button(action: { asset.isDeleted = true }) { Image(systemName: "trash").foregroundColor(.red) }
                                    .buttonStyle(.borderless).help("Trash")
                            }
                        }
                    }
                    .width(90) // Slightly widened to fit the third button
                }
            }
            .navigationTitle("Wealth Tracker")
            // ... (Keep your existing .toolbar and .sheet modifiers here) ...
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    
                    // 1. AI Advisor Button
                    Button(action: { showingAdvisor = true }) {
                        Label("AI Advisor", systemImage: "sparkles")
                    }
                    
                    // 2. SIP Manager Button
                    Button(action: { showingSIPManager = true }) {
                        Label("Manage SIPs", systemImage: "calendar.badge.clock")
                    }
                    .help("Track recurring monthly investments")
                    
                    // 3. Refresh Button
                    Button(action: {
                        Task {
                            await processPendingSIPs()
                            await refreshStockPrices()
                        }
                    }) {
                        Label("Refresh", systemImage: isRefreshing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath.circle")
                    }
                    .disabled(isRefreshing)
                    .help("Catch up SIPs & Refresh Live Prices")
                    
                    // 4. Add Asset Button
                    Button(action: { showingAddAsset = true }) {
                        Label("Add Asset", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAsset) { AddAssetView() }
            .sheet(isPresented: $showingAdvisor) { AdvisorView() }
            .sheet(isPresented: $showingSIPManager) {
                SIPManagerView()
            }.sheet(item: $assetToEdit) { asset in EditAssetView(asset: asset) }
            // ADD THIS NEW LINE RIGHT HERE:
                .sheet(item: $performanceAssetToView) { asset in AssetPerformanceView(asset: asset) }
                .onAppear {Task { await refreshStockPrices() } }
        }
    }
    
    private func refreshStockPrices() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        for asset in assets where !asset.isDeleted { // Only refresh active assets
            guard !asset.ticker.isEmpty else { continue }
            do {
                let latestPrice = try await StockPriceService.shared.fetchCurrentPrice(for: asset.ticker)
                asset.currentMarketPrice = latestPrice
            } catch {
                print("Failed to fetch price for \(asset.ticker): \(error)")
            }
        }
        // Call the snapshot recorder right before we finish refreshing!
        recordSnapshot()
        isRefreshing = false
    }
    
    // MARK: - Historical Tracking
    private func recordSnapshot() {
        let activeAssets = assets.filter { !$0.isDeleted }
        guard !activeAssets.isEmpty else { return }
        
        let currentTotalValue = activeAssets.reduce(0) { $0 + $1.currentMarketValue }
        let currentTotalInvested = activeAssets.reduce(0) { $0 + $1.totalInvestmentValue }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        // Check if we already recorded a snapshot today to prevent duplicates
        if let existingSnapshot = snapshots.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            // Update today's snapshot with the latest market fluctuations
            existingSnapshot.totalValue = currentTotalValue
            existingSnapshot.totalInvested = currentTotalInvested
        } else {
            // Create a brand new snapshot for today
            let newSnapshot = PortfolioSnapshot(date: today, totalValue: currentTotalValue, totalInvested: currentTotalInvested)
            modelContext.insert(newSnapshot)
        }
    }
    // MARK: - Debuggable Catch-Up Engine
    private func processPendingSIPs() async {
        let today = Date()
        print("🚀 Starting Catch-up Engine...")
        
        for sip in scheduledSIPs where sip.isActive {
            print("🔍 Checking SIP: \(sip.ticker). Last Executed: \(String(describing: sip.lastExecutedDate))")
            
            // Loop through missed months
            while sip.nextDeductionDate <= today {
                let executionDate = sip.nextDeductionDate
                print("📅 Attempting to process month: \(executionDate)")
                
                if let asset = assets.first(where: { $0.ticker == sip.ticker && !$0.isDeleted }) {
                    do {
                        let fetchedNAV = try await StockPriceService.fetchHistoricalPrice(for: sip.ticker, on: executionDate)
                        
                        let unitsBought = sip.monthlyAmount / fetchedNAV
                        let oldTotalValue = asset.quantity * asset.averagePurchasePrice
                        let newTotalValue = oldTotalValue + sip.monthlyAmount
                        
                        asset.quantity += unitsBought
                        asset.averagePurchasePrice = newTotalValue / asset.quantity
                        
                        print("✅ Success: Added \(String(format: "%.4f", unitsBought)) units for \(sip.ticker)")
                        
                    } catch {
                        print("❌ Failed historical fetch for \(executionDate). Skipping...")
                    }
                }
                
                // Update and Save (Crucial: This MUST persist to the database)
                sip.lastExecutedDate = executionDate
                do {
                    try modelContext.save()
                    print("💾 Database Saved successfully for \(executionDate)")
                } catch {
                    print("🚨 Database Save Failed: \(error)")
                }
                
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        print("🏁 Engine Finished.")
    }
}
