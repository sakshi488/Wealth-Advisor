import Foundation
import SwiftData

@Model
final class SIP {
    var id: UUID
    var assetName: String
    var ticker: String
    var monthlyAmount: Double
    var deductionDay: Int
    var isActive: Bool
    
    // Automation & Historical fields
    var startDate: Date
    var lastExecutedDate: Date?

    init(assetName: String, ticker: String, monthlyAmount: Double, deductionDay: Int, startDate: Date = Date()) {
        self.id = UUID()
        self.assetName = assetName
        self.ticker = ticker.uppercased()
        self.monthlyAmount = monthlyAmount
        self.deductionDay = deductionDay
        self.isActive = true
        self.startDate = startDate
        self.lastExecutedDate = nil
    }
    
    // Calculates the theoretical next deduction date based purely on the LAST time it ran
    var nextDeductionDate: Date {
            let calendar = Calendar.current
            
            // 1. If we have never executed, the next run is the start date
            // 2. If we HAVE executed, the next run is exactly one month after the last execution
            let baseDate = lastExecutedDate ?? startDate
            
            // Add 1 month to the base date
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: baseDate) else { return baseDate }
            
            // Ensure it respects the specific day of the month (e.g., 5th, 15th)
            var components = calendar.dateComponents([.year, .month], from: nextMonth)
            components.day = deductionDay
            
            return calendar.date(from: components) ?? nextMonth
        }
}
