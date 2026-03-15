
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
    var receiptImage: UIImage?            // The photo the user took or picked
    var isShowingScanner: Bool = false    // Controls camera sheet presentation
    var isProcessingOCR: Bool = false     // Shows a loading spinner while OCR runs
    var ocrErrorMessage: String?          // Shows if OCR fails to find a total
    
    // MARK: - Validation
    var isFormValid: Bool {
        Double(amount) != nil && Double(amount)! > 0
    }
    
    // MARK: - Actions
    
    /// Saves the expense to the budget and clears the form.
    func addExpense(to budget: Budget, context: ModelContext) {
        guard isFormValid, let amountDouble = Double(amount) else { return }
        
        let expense = Expense(amount: amountDouble, note: note, date: date)
        
        // Convert UIImage to Data for storage in SwiftData.
        // jpegData(compressionQuality: 0.6) shrinks the image to save space.
        if let image = receiptImage {
            expense.receiptImageData = image.jpegData(compressionQuality: 0.6)
        }
        
        // Link the expense to its budget.
        expense.budget = budget
        budget.expenses.append(expense)
        
        context.insert(expense)
        reset()
    }
    
    /// Called when the user selects or photographs a receipt.
    /// This triggers OCR asynchronously so the UI stays responsive.
    func handleReceiptImage(_ image: UIImage) {
        receiptImage = image
        ocrErrorMessage = nil
        
        Task {
            await runOCR(on: image)
        }
    }
    
    // MARK: - Private
    
    /// Runs OCR on the receipt image and populates the amount field.
    @MainActor
    private func runOCR(on image: UIImage) async {
        isProcessingOCR = true
        
        if let detected = await OCRManager.extractTotal(from: image) {
            // Format to 2 decimal places, e.g. "24.99"
            amount = String(format: "%.2f", detected)
            ocrErrorMessage = nil
        } else {
            ocrErrorMessage = "Couldn't detect a total. Please enter the amount manually."
        }
        
        isProcessingOCR = false
    }
    
    private func reset() {
        amount = ""
        note = ""
        date = .now
        receiptImage = nil
        isShowingScanner = false
        isProcessingOCR = false
        ocrErrorMessage = nil
    }
}
