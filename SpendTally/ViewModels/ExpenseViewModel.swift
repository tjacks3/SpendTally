// ============================================================
// FILE:   ExpenseViewModel.swift
// ADD TO: SpendTally/ViewModels/ExpenseViewModel.swift
//
// ACTION: REPLACE EXISTING FILE — this is a full replacement
//         of the ExpenseViewModel.swift already in your project:
//   1. Open SpendTally/ViewModels/ExpenseViewModel.swift
//      in Xcode
//   2. Select all (Cmd+A) and delete
//   3. Paste this entire file in
//
// WHAT CHANGED vs. the original:
//   • Uses ReceiptOCRService instead of OCRManager
//   • Exposes ocrResult, ocrStatusMessage, ocrStatusColor
//     (drives the confidence badge in AddExpenseView)
//   • Exposes alternativeAmounts (drives the chip row)
//   • Added selectAlternativeAmount(_:) action
// ============================================================

import SwiftData
import SwiftUI
import Observation

/// Manages the state for adding an expense (including OCR receipt scanning).
@Observable
final class ExpenseViewModel {
    
    // MARK: - Form State
    var amount: String = ""
    var note: String = ""
    var date: Date = .now
    
    // MARK: - Receipt / OCR State
    var receiptImage: UIImage?
    var isProcessingOCR: Bool = false
    
    /// The full OCR result — lets the UI show confidence detail.
    var ocrResult: OCRResult?
    
    /// Set when the user can choose from several detected amounts.
    var alternativeAmounts: [Double] = []
    
    /// True once OCR has run at least once for the current image.
    var ocrDidRun: Bool = false
    
    // MARK: - Validation
    
    var isFormValid: Bool {
        guard let v = Double(amount) else { return false }
        return v > 0
    }
    
    /// User-facing status message shown below the amount field.
    var ocrStatusMessage: String? {
        guard ocrDidRun else { return nil }
        guard let result = ocrResult else { return nil }
        
        switch result.strategy {
        case .notFound:
            return "Couldn't detect a total — please enter the amount manually."
        case .largestAmount:
            return "No \"total\" label found — using the largest amount detected."
        case .totalKeyword:
            // Only show the friendly label; don't clutter on success.
            return result.strategyDescription
        }
    }
    
    /// Color for the status message.
    var ocrStatusColor: Color {
        guard let result = ocrResult else { return .secondary }
        switch result.strategy {
        case .notFound:    return .orange
        case .largestAmount: return .yellow
        case .totalKeyword:  return .green
        }
    }
    
    // MARK: - Actions
    
    /// Saves the expense to the budget and clears the form.
    func addExpense(to cycle: BudgetCycle, context: ModelContext) {
        guard isFormValid, let amountDouble = Double(amount) else { return }

        let expense = Expense(amount: amountDouble, note: note, date: date)

        if let image = receiptImage {
            expense.receiptImageData = image.jpegData(compressionQuality: 0.6)
        }

        // Attach to the cycle, not the budget
        expense.budgetCycle = cycle
        cycle.expenses.append(expense)
        context.insert(expense)
        reset()
    }
    
    /// Called when the user selects or photographs a receipt.
    func handleReceiptImage(_ image: UIImage) {
        receiptImage = image
        ocrResult = nil
        ocrDidRun = false
        alternativeAmounts = []
        
        Task {
            await runOCR(on: image)
        }
    }
    
    /// Lets the user pick one of the other amounts Vision detected.
    func selectAlternativeAmount(_ value: Double) {
        amount = formatted(value)
    }
    
    // MARK: - Private
    
    @MainActor
    private func runOCR(on image: UIImage) async {
        isProcessingOCR = true
        
        let result = await ReceiptOCRService.recognise(image: image)
        ocrResult = result
        ocrDidRun = true
        
        if let detected = result.amount {
            amount = formatted(detected)
        }
        
        // Offer alternatives (other amounts found on the receipt), excluding
        // the primary detection so the list isn't repetitive.
        alternativeAmounts = result.allAmounts.filter {
            $0 != result.amount && $0 > 0
        }
        
        isProcessingOCR = false
    }
    
    private func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
    
    private func reset() {
        amount = ""
        note = ""
        date = .now
        receiptImage = nil
        ocrResult = nil
        ocrDidRun = false
        alternativeAmounts = []
        isProcessingOCR = false
    }
}
