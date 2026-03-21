// ============================================================
// FILE:   CycleRowView.swift
// LOCATION: SpendTally/Views/Budget/CycleRowView.swift
//
// ACTION: NEW FILE
//   1. Right-click the "Budget" folder inside "Views" in the
//      Xcode Project Navigator.
//   2. New File from Template → Swift File
//   3. Name it "CycleRowView"
//   4. Paste this entire file, replacing the generated stub.
//
// PURPOSE:
//   A single row in the Budget History list.
//   Each row is a "report card" for one completed budget cycle.
//   It shows:
//     • Date range  (e.g. "Mar 1 – Mar 31")
//     • Total spent vs. the budget limit
//     • A status badge: "Under Budget" (green) or "Over Budget" (red)
//     • A left-edge colour strip as a quick visual indicator
//
// DESIGN NOTES:
//   • Self-contained: receives one BudgetCycle and derives everything.
//   • No ViewModel needed — all values come from BudgetCycle's existing
//     computed properties (totalSpent, remainingAmount, status, isActive).
//   • Active cycles (the current period) are rendered with a muted
//     "In Progress" badge so the history list never feels confusing.
// ============================================================

import SwiftUI
import SwiftData

struct CycleRowView: View {

    // The cycle this row represents.
    // @Model objects are reference types — SwiftUI observes them automatically.
    let cycle: BudgetCycle

    // MARK: - Derived display values

    /// True when this cycle is the one currently in progress.
    private var isActive: Bool { cycle.isActive }

    /// "Mar 1 – Mar 31" style string.
    private var dateRange: String {
        CycleRowDateHelper.rangeLabel(from: cycle.startDate, to: cycle.endDate)
    }

    /// How many days this cycle spanned (e.g. "31-day cycle").
    private var cycleLengthLabel: String {
        let days = Calendar.current
            .dateComponents([.day], from: cycle.startDate, to: cycle.endDate)
            .day ?? 0
        let count = days + 1  // inclusive
        return "\(count)-day cycle"
    }

    /// The colour that tints the left-edge strip and the status badge.
    private var statusColor: Color {
        if isActive  { return .blue }
        if cycle.isOver { return .red }
        return .green
    }

    /// Short label for the status badge.
    private var statusLabel: String {
        if isActive       { return "In Progress" }
        if cycle.isOver   { return "Over Budget" }
        return "Under Budget"
    }

    /// SF Symbol for the status badge.
    private var statusIcon: String {
        if isActive       { return "clock.fill" }
        if cycle.isOver   { return "xmark.circle.fill" }
        return "checkmark.circle.fill"
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {

            // ── Left colour strip ─────────────────────────────────────────
            // A 4-pt wide rectangle gives an instant visual cue:
            //   green  = ended under budget
            //   red    = ended over budget
            //   blue   = currently in progress
            Rectangle()
                .fill(statusColor)
                .frame(width: 4)
                .clipShape(
                    .rect(
                        topLeadingRadius: 12,
                        bottomLeadingRadius: 12
                    )
                )

            // ── Main content ──────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {

                // Row 1: date range + status badge
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateRange)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(cycleLengthLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Status badge (pill shape, colour-coded)
                    Label(statusLabel, systemImage: statusIcon)
                        .font(.caption.bold())
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                Divider()

                // Row 2: spent amount + budget limit
                HStack {
                    amountPair(
                        label: "Spent",
                        value: cycle.totalSpent,
                        valueColor: cycle.isOver ? .red : .primary
                    )

                    Spacer()

                    amountPair(
                        label: "Budget",
                        value: cycle.totalAmount,
                        valueColor: .secondary
                    )

                    Spacer()

                    amountPair(
                        label: cycle.isOver ? "Over by" : "Saved",
                        value: abs(cycle.remainingAmount),
                        valueColor: cycle.isOver ? .red : .green
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // Slightly dim active-cycle rows — they're not "final" yet.
        .opacity(isActive ? 0.75 : 1.0)
    }

    // MARK: - Sub-views

    /// A labelled amount pair used in the stats row.
    ///
    ///   Spent
    ///   $320.00
    ///
    private func amountPair(
        label: String,
        value: Double,
        valueColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value, format: .currency(code: "USD"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Date Helper

/// Lightweight formatter used only by CycleRowView.
///
/// WHY A SEPARATE TYPE:
///   BudgetCycleDateHelpers (in DashboardView.swift) is a private type
///   scoped to that file. Rather than making it internal and coupling
///   two unrelated screens, we keep a small focused helper here.
///   Both helpers are pure static functions — no duplication risk.
private enum CycleRowDateHelper {

    /// Returns "Mar 1 – Mar 31" if months match, or "Feb 28 – Mar 31" if not.
    static func rangeLabel(from start: Date, to end: Date) -> String {
        let startStr = formatted(start, format: "MMM d")
        let endStr   = formatted(end,   format: "MMM d")
        return "\(startStr) – \(endStr)"
    }

    private static func formatted(_ date: Date, format: String) -> String {
        let df = DateFormatter()
        df.dateFormat = format
        return df.string(from: date)
    }
}

// MARK: - Preview

#Preview("Under Budget") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Budget.self, BudgetCycle.self, Expense.self,
        configurations: config
    )

    let budget = Budget(name: "Groceries", totalAmount: 500)
    container.mainContext.insert(budget)

    let cal   = Calendar.current
    let start = cal.date(from: DateComponents(year: 2026, month: 2, day: 1))!
    let end   = cal.date(from: DateComponents(year: 2026, month: 2, day: 28,
                                               hour: 23, minute: 59, second: 59))!
    let cycle = BudgetCycle(budget: budget, startDate: start, endDate: end)
    container.mainContext.insert(cycle)

    // Add a $320 expense (under $500 limit)
    let expense = Expense(amount: 320, note: "Weekly groceries")
    expense.budgetCycle = cycle
    container.mainContext.insert(expense)

    return CycleRowView(cycle: cycle)
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}

#Preview("Over Budget") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Budget.self, BudgetCycle.self, Expense.self,
        configurations: config
    )

    let budget = Budget(name: "Dining", totalAmount: 200)
    container.mainContext.insert(budget)

    let cal   = Calendar.current
    let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    let end   = cal.date(from: DateComponents(year: 2026, month: 1, day: 31,
                                               hour: 23, minute: 59, second: 59))!
    let cycle = BudgetCycle(budget: budget, startDate: start, endDate: end)
    container.mainContext.insert(cycle)

    let expense = Expense(amount: 247.50, note: "Restaurants")
    expense.budgetCycle = cycle
    container.mainContext.insert(expense)

    return CycleRowView(cycle: cycle)
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(container)
}
