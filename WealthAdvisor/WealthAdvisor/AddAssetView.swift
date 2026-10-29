import SwiftUI
import SwiftData

struct AddAssetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Search and Form states
    @State private var searchQuery = ""
    @State private var searchResults: [TickerSearchResult] = []
    @State private var isSearching = false
    
    @State private var selectedName = ""
    @State private var selectedTicker = ""
    @State private var assetType = "Stock"
    @State private var quantity: Double?
    @State private var averagePurchasePrice: Double?

    var body: some View {
        VStack(spacing: 0) {
            // Section 1: Search Component
            VStack(alignment: .leading, spacing: 8) {
                Text("Search Asset")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Type company name or ticker (e.g., Reliance, TCS)", text: $searchQuery)
                        .textFieldStyle(.plain)
                    
                    if isSearching {
                        ProgressView().controlSize(.small)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .padding()

            // Section 2: Results Dropdown List
            if !searchResults.isEmpty {
                List(searchResults) { result in
                    Button(action: {
                        selectAsset(result)
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(result.name)
                                    .fontWeight(.medium)
                                Text(result.symbol)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(result.exchange)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(NSColor.windowBackgroundColor))
                                .cornerRadius(4)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 150)
                .transition(.opacity)
            }

            Divider()

            // Section 3: Details & Confirmation Form
            Form {
                Section(header: Text("Asset Investment Details").font(.subheadline).bold()) {
                    LabeledContent("Selected Asset", value: selectedName.isEmpty ? "None" : "\(selectedName) (\(selectedTicker))")
                    
                    Picker("Asset Type", selection: $assetType) {
                        Text("Stock").tag("Stock")
                        Text("Mutual Fund").tag("Mutual Fund")
                        Text("Crypto").tag("Crypto")
                    }
                    
                    TextField("Quantity", value: $quantity, format: .number)
                    TextField("Average Purchase Price (₹)", value: $averagePurchasePrice, format: .number)
                }
                .padding(.top, 8)

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    Spacer()
                    Button("Save Asset") {
                        saveAsset()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedTicker.isEmpty || quantity == nil || averagePurchasePrice == nil)
                }
                .padding(.vertical)
            }
            .padding()
        }
        // Run search task automatically whenever the user types
        .task(id: searchQuery) {
            await performSearch()
        }
        .frame(width: 450, height: searchResults.isEmpty ? 320 : 470)
        .animation(.default, value: searchResults.isEmpty)
    }

    // MARK: - Helper Functions
    
    private func performSearch() async {
        guard searchQuery.count > 1 else {
            searchResults = []
            return
        }
        
        isSearching = true
        // Short artificial delay to prevent hitting the API on every single keystroke (debouncing)
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        let results = await TickerSearchService.search(query: searchQuery)
        // Ensure UI updates happen on the main thread
        await MainActor.run {
            self.searchResults = results
            self.isSearching = false
        }
    }

    private func selectAsset(_ result: TickerSearchResult) {
        selectedName = result.name
        selectedTicker = result.symbol
        
        // Auto-detect asset type tentatively
        if result.symbol.contains(".NS") || result.symbol.contains(".BO") {
            assetType = "Stock"
        }
        
        // Clear search results to collapse the dropdown
        searchResults = []
        searchQuery = ""
    }

    private func saveAsset() {
        guard let qty = quantity, let price = averagePurchasePrice, !selectedTicker.isEmpty else { return }
        
        let newAsset = Asset(
            name: selectedName,
            assetType: assetType,
            ticker: selectedTicker,
            quantity: qty,
            averagePurchasePrice: price,
            currentMarketPrice: price
        )
        
        modelContext.insert(newAsset)
        dismiss()
    }
}
