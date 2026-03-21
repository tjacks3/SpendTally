import SwiftUI

struct BudgetRowView: View {

    let budget: Budget

    var body: some View {
        // Use the current cycle for all display values
        let cycle = budget.currentCycle

        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Text(budget.name).font(.headline)
                Spacer()
                Text(cycle?.remainingAmount ?? budget.totalAmount,
                     format: .currency(code: "USD"))
                    .font(.headline)
                    .foregroundStyle((cycle?.isOver ?? false) ? .red : .green)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill((cycle?.isOver ?? false) ? Color.red : Color.accentColor)
                        .frame(width: geo.size.width * (cycle?.progress ?? 0), height: 8)
                        .animation(.easeOut, value: cycle?.progress)
                }
            }
            .frame(height: 8)

            HStack {
                // Show cycle type label
                Label(budget.periodLabel, systemImage: budget.cycleType.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let cycle {
                    Text("\(cycle.totalSpent, format: .currency(code: "USD")) of \(cycle.totalAmount, format: .currency(code: "USD"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No activity yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
