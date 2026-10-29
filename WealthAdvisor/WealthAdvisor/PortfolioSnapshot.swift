import Foundation
import SwiftData

@Model
final class PortfolioSnapshot {
    var id: UUID
    
    // The exact day the snapshot was taken
    var date: Date
    
    // Your total net worth on that day
    var totalValue: Double
    
    // How much you had actually invested out of pocket (useful to compare against value)
    var totalInvested: Double

    init(date: Date = Date(), totalValue: Double, totalInvested: Double) {
        self.id = UUID()
        // We zero out the time component so we only save one snapshot per day
        self.date = Calendar.current.startOfDay(for: date)
        self.totalValue = totalValue
        self.totalInvested = totalInvested
    }
}
