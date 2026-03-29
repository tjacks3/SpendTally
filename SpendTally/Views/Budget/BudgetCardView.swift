// ============================================================
// FILE:   BudgetCardView.swift
// LOCATION: SpendTally/Views/Budget/BudgetCardView.swift
//
// ACTION: NEW FILE
//   1. Right-click the "Budget" folder inside "Views" in the
//      Xcode Project Navigator.
//   2. New File from Template → Swift File
//   3. Name it "BudgetCardView"
//   4. Paste this entire file, replacing the generated stub.
//
// PURPOSE:
//   A reusable budget summary card used in BudgetListView.
//   Replaces BudgetRowView with a cleaner, typography-first design.
//
// DESIGN:
//   • Rounded card with soft border, generous padding, white base
//   • ZStack layering: base background → subtle gradient → content
//   • Gradient: soft green (on/under budget) or red (over budget),
//     rising from the bottom — very subtle, not distracting
//   • Top row: Budget Name (left) + Cycle label (right, muted)
//   • Large bold total-budget amount, left-aligned
//   • Progress text "$X of $Y" in secondary colour beneath the amount
//   • NO progress bar
// ============================================================

import SwiftUI
import SwiftData

// MARK: - BudgetCardView

struct BudgetCardView: View {

    let budget: Budget

    // MARK: - Derived values

    private var cycle: BudgetCycle? { budget.currentCycle }

    /// The display amount is the current cycle's budget snapshot,
    /// falling back to the template amount if no cycle exists yet.
    private var totalAmount: Double {
        cycle?.totalAmount ?? budget.totalAmount
    }

    private var spentAmount: Double {
        cycle?.totalSpent ?? 0
    }

    private var isOver: Bool {
        cycle?.isOver ?? false
    }

    /// Cycle type label shown top-right (e.g. "Weekly", "Monthly")
    private var cycleLabel: String {
        budget.cycleType.displayName
    }

    // MARK: - Gradient colour

    /// Very soft, low-opacity gradient colour anchored at the bottom of the card.
    /// Green when on/under budget, red when over.
    private var gradientColor: Color {
        isOver ? Color.red : Color.green
    }

    // MARK: - Helpers

    /// Splits a Double into integer and 2-digit decimal strings.
    /// Matches the same helper used in DashboardView / BudgetDetailView.
    private func splitAmount(_ value: Double) -> (integer: String, decimal: String) {
        let formatted = String(format: "%.2f", value)
        let parts     = formatted.split(separator: ".")
        return (
            integer: String(parts.first ?? "0"),
            decimal: String(parts.dropFirst().first ?? "00")
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Layer 1: Base card background ────────────────────────────
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))

            // ── Layer 2: Subtle bottom-up gradient overlay ───────────────
            // Starts at the bottom edge (low opacity) and fades to
            // completely transparent before reaching the top half.
            // Opacity is kept very low so it never masks text.
            LinearGradient(
                stops: [
                    .init(color: gradientColor.opacity(0.18), location: 0.0),
                    .init(color: gradientColor.opacity(0.06), location: 0.45),
                    .init(color: .clear,                      location: 1.0),
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .animation(.easeInOut(duration: 0.4), value: isOver)

            // ── Layer 3: Card content ────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {

                // Top row: budget name (left) + cycle label (right)
                HStack(alignment: .firstTextBaseline) {
                    Text(budget.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)

                    Spacer()

                    Text(cycleLabel)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(.label))
                }

                // Breathing room between name and the primary amount
                Spacer().frame(height: 8)

                // Primary display — mirrors DashboardView's remainingCard:
                // "$" prefix (light) + integer (thin) + ".decimal" (light, offset)
                // All use design: .rounded for consistent style with the detail screen.
                let parts = splitAmount(totalAmount)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("$")
                        .font(.system(size: 28, weight: .light, design: .rounded))
                        .foregroundStyle(Color(.label))
                    Text(parts.integer)
                        .font(.system(size: 52, weight: .thin, design: .rounded))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(".\(parts.decimal)")
                        .font(.system(size: 28, weight: .light, design: .rounded))
                        .foregroundStyle(Color(.label))
                        .baselineOffset(3)
                }

                // Supporting text: "$spent of $total"
                Spacer().frame(height: 1)

                progressText
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        // Soft border that feels lightweight against the white base
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Progress Text

    @ViewBuilder
    private var progressText: some View {
        if let cycle {
            Text("\(cycle.totalSpent, format: .currency(code: "USD")) of \(cycle.totalAmount, format: .currency(code: "USD"))")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(.label))
        } else {
            Text("No activity yet")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(.label).opacity(0.35))
        }
    }
}

// MARK: - Previews

#Preview("On Budget — green gradient") {
    let config    = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Budget.self, BudgetCycle.self, Expense.self,
        configurations: config
    )

    let budget = Budget(name: "Groceries", totalAmount: 1500, cycleType: .monthly)
    container.mainContext.insert(budget)

    // Create an active cycle with some spending (under budget)
    let cal   = Calendar.current
    let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
    let end   = cal.date(from: DateComponents(year: 2026, month: 3, day: 31,
                                              hour: 23, minute: 59, second: 59))!
    let cycle = BudgetCycle(budget: budget, startDate: start, endDate: end)
    container.mainContext.insert(cycle)

    let expense = Expense(amount: 40, note: "Trader Joe's")
    expense.budgetCycle = cycle
    container.mainContext.insert(expense)

    return BudgetCardView(budget: budget)
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}

#Preview("Over Budget — red gradient") {
    let config    = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Budget.self, BudgetCycle.self, Expense.self,
        configurations: config
    )

    let budget = Budget(name: "Dining Out", totalAmount: 200, cycleType: .weekly)
    container.mainContext.insert(budget)

    // Create a cycle where spending exceeds the limit
    let cal   = Calendar.current
    let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 22))!
    let end   = cal.date(from: DateComponents(year: 2026, month: 3, day: 28,
                                              hour: 23, minute: 59, second: 59))!
    let cycle = BudgetCycle(budget: budget, startDate: start, endDate: end)
    container.mainContext.insert(cycle)

    let expense = Expense(amount: 260, note: "Restaurant row")
    expense.budgetCycle = cycle
    container.mainContext.insert(expense)

    return BudgetCardView(budget: budget)
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}
