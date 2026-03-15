import SwiftUI

struct BudgetRowView: View {
    
    let budget: Budget
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            HStack {
                Text(budget.name)
                    .font(.headline)
                Spacer()
                Text(budget.remaining, format: .currency(code: "USD"))
                    .font(.headline)
                    .foregroundStyle(budget.isOverBudget ? .red : .green)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(budget.isOverBudget ? Color.red : Color.accentColor)
                        .frame(width: geo.size.width * budget.progress, height: 8)
                        .animation(.easeOut, value: budget.progress)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("\(budget.periodLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(budget.totalSpent, format: .currency(code: "USD")) of \(budget.totalAmount, format: .currency(code: "USD"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
