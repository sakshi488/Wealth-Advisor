import SwiftUI
import Charts // Apple's native charting framework

struct DashboardView: View {
    // We pass the assets from the main view into this component
    var assets: [Asset]
    
    // MARK: - Summary Calculations
    private var totalValue: Double {
        assets.reduce(0) { $0 + $1.currentMarketValue }
    }
    
    private var totalProfitLoss: Double {
        assets.reduce(0) { $0 + $1.totalProfitLoss }
    }
    
    private var profitLossPercentage: Double {
        let totalInvested = assets.reduce(0) { $0 + $1.totalInvestmentValue }
        guard totalInvested > 0 else { return 0 }
        return (totalProfitLoss / totalInvested) * 100
    }

    var body: some View {
        HStack(spacing: 30) {
            
            // Left Side: Summary Metrics Cards
            VStack(alignment: .leading, spacing: 20) {
                MetricCard(
                    title: "Net Worth",
                    value: totalValue,
                    isCurrency: true
                )
                
                MetricCard(
                    title: "Total Profit / Loss",
                    value: totalProfitLoss,
                    percentage: profitLossPercentage,
                    isCurrency: true,
                    showColor: true
                )
            }
            .frame(minWidth: 200)
            
            // Right Side: Interactive Donut Chart
            if !assets.isEmpty {
                VStack(alignment: .leading) {
                    Text("Asset Allocation")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Chart(assets) { asset in
                        SectorMark(
                            angle: .value("Market Value", asset.currentMarketValue),
                            innerRadius: .ratio(0.6), // This makes it a donut instead of a pie
                            angularInset: 2.0 // Adds a tiny gap between slices
                        )
                        .foregroundStyle(by: .value("Asset Name", asset.name))
                        .annotation(position: .overlay) {
                            // Only show text on the chart if the slice is large enough
                            if (asset.currentMarketValue / totalValue) > 0.05 {
                                Text(asset.ticker.prefix(4))
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(height: 180)
                    // Puts the legend on the right side
                    .chartLegend(position: .trailing, alignment: .center)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            } else {
                // Empty State
                ContentUnavailableView("No Assets", systemImage: "chart.pie", description: Text("Add assets to see your allocation chart."))
                    .frame(height: 180)
            }
        }
        .padding()
    }
}

// MARK: - Reusable UI Card Component
struct MetricCard: View {
    let title: String
    let value: Double
    var percentage: Double? = nil
    var isCurrency: Bool = false
    var showColor: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline) {
                // We split this into an if/else block to keep Swift's type checker happy!
                if isCurrency {
                    Text(value, format: .currency(code: "INR"))
                        .font(.title)
                        .bold()
                        .foregroundColor(showColor ? (value >= 0 ? .green : .red) : .primary)
                } else {
                    Text(value, format: .number)
                        .font(.title)
                        .bold()
                        .foregroundColor(showColor ? (value >= 0 ? .green : .red) : .primary)
                }
                
                if let percent = percentage {
                    Text("(\(percent >= 0 ? "+" : "")\(percent, specifier: "%.2f")%)")
                        .font(.callout)
                        .bold()
                        .foregroundColor(percent >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
