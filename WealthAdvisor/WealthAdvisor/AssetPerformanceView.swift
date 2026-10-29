import SwiftUI
import SwiftData
import Charts

// 1. A simple structure to hold our timeline data
struct AssetTimelineData: Identifiable {
    let id = UUID()
    let date: Date
    let investedAmount: Double
}

struct AssetPerformanceView: View {
    let asset: Asset
    @Environment(\.dismiss) private var dismiss
    
    // 2. Query all SIPs to find the one that matches this asset
    @Query private var allSIPs: [SIP]
    
    var activeSIP: SIP? {
        allSIPs.first(where: { $0.ticker == asset.ticker })
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // --- HEADER ---
            HStack {
                VStack(alignment: .leading) {
                    Text(asset.name).font(.title2).bold()
                    Text("\(asset.ticker) • \(asset.assetType)").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
            }
            
            Divider()
            
            // --- BREAKDOWN METRICS ---
            HStack(spacing: 20) {
                PerformanceMetricCard(title: "Total Invested", value: asset.totalInvestmentValue, color: .blue)
                PerformanceMetricCard(title: asset.totalProfitLoss >= 0 ? "Wealth Gained" : "Wealth Lost", value: abs(asset.totalProfitLoss), color: asset.totalProfitLoss >= 0 ? .green : .red)
                PerformanceMetricCard(title: "Current Value", value: asset.currentMarketValue, color: .primary)
            }
            
            // --- NEW: INVESTMENT TIMELINE CHART ---
            VStack(alignment: .leading) {
                Text("SIP Investment Timeline").font(.headline)
                Text("The blue line tracks your monthly SIP installments. The dot represents current market value.")
                    .font(.caption).foregroundColor(.secondary)
                
                let timeline = generateTimeline()
                
                Chart {
                    // Draw the "Staircase" of your invested capital
                    ForEach(timeline) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Invested", point.investedAmount)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Invested", point.investedAmount)
                        )
                        .foregroundStyle(.blue.opacity(0.1))
                    }
                    
                    // Plot the Current Market Value at today's date
                    PointMark(
                        x: .value("Date", Date()),
                        y: .value("Market Value", asset.currentMarketValue)
                    )
                    .foregroundStyle(asset.totalProfitLoss >= 0 ? .green : .red)
                    .symbolSize(150)
                    .annotation(position: .top) {
                        Text(asset.currentMarketValue, format: .currency(code: "INR"))
                            .font(.caption).bold()
                            .foregroundColor(asset.totalProfitLoss >= 0 ? .green : .red)
                            .padding(4)
                            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                            .cornerRadius(4)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().year())
                    }
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            
            // --- UNIT BREAKDOWN ---
            HStack {
                Text("Holding: **\(asset.quantity, format: .number) Units**")
                Spacer()
                Text("Averaged at: **\(asset.averagePurchasePrice, format: .currency(code: "INR"))**")
            }
            .font(.caption)
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 600, height: 550) // Slightly taller to fit the beautiful chart
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Timeline Generator
    private func generateTimeline() -> [AssetTimelineData] {
        guard let sip = activeSIP else {
            // If it's just a normal stock with no SIP, show a flat line of the investment
            return [
                AssetTimelineData(date: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(), investedAmount: asset.totalInvestmentValue),
                AssetTimelineData(date: Date(), investedAmount: asset.totalInvestmentValue)
            ]
        }
        
        var timeline: [AssetTimelineData] = []
        var currentDate = sip.startDate
        var accumulated = 0.0
        let today = Date()
        
        // Loop from the start date to today, adding the monthly amount each step!
        while currentDate <= today {
            accumulated += sip.monthlyAmount
            timeline.append(AssetTimelineData(date: currentDate, investedAmount: accumulated))
            
            var components = DateComponents()
            components.month = 1
            currentDate = Calendar.current.date(byAdding: components, to: currentDate) ?? today
        }
        
        // Ensure the chart draws all the way to exactly right now
        if let last = timeline.last, last.date < today {
            timeline.append(AssetTimelineData(date: today, investedAmount: accumulated))
        }
        
        return timeline
    }
}

// Reusable mini-view for the three metric boxes
struct PerformanceMetricCard: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value, format: .currency(code: "INR"))
                .font(.title3)
                .bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
}
