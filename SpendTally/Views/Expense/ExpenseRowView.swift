import SwiftUI

struct ExpenseRowView: View {
    
    let expense: Expense
    
    var body: some View {
        HStack(spacing: 12) {
            // Receipt thumbnail if available
            if let data = expense.receiptImageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "receipt")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.note.isEmpty ? "Expense" : expense.note)
                    .font(.subheadline)
                Text(expense.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(expense.amount, format: .currency(code: "USD"))
                .font(.subheadline.bold())
        }
        .padding(.vertical, 2)
    }
}
