import SwiftData
import Foundation

/// A single expense added to a budget.
@Model
final class Expense {
    
    var amount: Double
    var note: String           // e.g. "Whole Foods run"
    var date: Date
    
    // Receipt image stored as raw bytes.
    // We use Data? (optional) because not every expense has a receipt.
    var receiptImageData: Data?
    
    // The inverse relationship back to the budget this expense belongs to.
    var budget: Budget?
    
    init(amount: Double, note: String, date: Date = .now) {
        self.amount = amount
        self.note = note
        self.date = date
    }
}
