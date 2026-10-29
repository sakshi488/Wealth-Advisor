import SwiftUI
import Charts
import SwiftData

struct PerformanceChartView: View {
    // We pass the historical snapshots into this view
    var snapshots: [PortfolioSnapshot]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Historical Performance")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // A line chart needs at least 2 points to draw a line!
            if snapshots.count < 2 {
                ContentUnavailableView(
                    "Collecting Data",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Your app is now recording your daily net worth. Check back tomorrow to see your trend line!")
                )
                .frame(height: 200)
            } else {
                Chart(snapshots) { snapshot in
                    // 1. The solid trend line
                    LineMark(
                        x: .value("Date", snapshot.date),
                        y: .value("Net Worth", snapshot.totalValue)
                    )
                    .interpolationMethod(.monotone) // Makes the line smoothly curve
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    // 2. The beautiful shaded area underneath the line
                    AreaMark(
                        x: .value("Date", snapshot.date),
                        y: .value("Net Worth", snapshot.totalValue)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        Gradient(colors: [.blue.opacity(0.3), .clear])
                    )
                }
                // Format the bottom axis to show dates cleanly
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
