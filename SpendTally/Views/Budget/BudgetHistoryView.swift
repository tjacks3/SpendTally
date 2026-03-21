// ============================================================
// FILE:   BudgetHistoryView.swift
// LOCATION: SpendTally/Views/Budget/BudgetHistoryView.swift
//
// ACTION: NEW FILE
//   1. Right-click the "Budget" folder inside "Views" in the
//      Xcode Project Navigator.
//   2. New File from Template → Swift File
//   3. Name it "BudgetHistoryView"
//   4. Paste this entire file, replacing the generated stub.
//
// WIRING IT UP (DashboardView.swift):
//   Inside the DashboardView toolbar, add a second ToolbarItem
//   that navigates to this screen:
//
//       ToolbarItem(placement: .topBarLeading) {
//           NavigationLink(destination: BudgetHistoryView(budget: budget)) {
//               Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
//                   .labelStyle(.iconOnly)
//           }
//       }
//
// PURPOSE:
//   Shows all budget cycles for a given Budget, sorted newest-first.
//   Each cycle is rendered as a "report card" via CycleRowView.
//
//   Key design philosophy:
//     Time is invisible to the user. They never configure cycles —
//     they just appear here automatically. The history screen is purely
//     a read-only archive: no date pickers, no manual inputs.
//
// HOW CYCLES ARE QUERIED:
//   We do NOT use a @Query macro here. Instead we access the cycles
//   through the Budget relationship:
//
//       budget.sortedCycles   →   [BudgetCycle]   (newest first)
//
//   WHY:
//     @Query is for fetching top-level entities from the store.
//     BudgetCycle objects are already loaded into memory as part of
//     the Budget relationship graph when you navigate to this screen —
//     SwiftData handles that for you. Accessing them through
//     budget.sortedCycles is zero-cost: it's just sorting an array
//     that's already in memory.
//
//     Using @Query here would require a Predicate filter like
//     #Predicate<BudgetCycle> { $0.budget?.id == budget.id }, which
//     is both more complex and triggers an unnecessary extra database
//     round-trip.
//
// HOW SORTING WORKS:
//   budget.sortedCycles is defined on the Budget model as:
//
//       var sortedCycles: [BudgetCycle] {
//           cycles.sorted { $0.startDate > $1.startDate }
//       }
//
//   The `>` comparator makes startDate descend — newest cycle first.
//   We use this directly in the view. No extra sorting needed here.
//
// ACTIVE CYCLE HANDLING:
//   The currently active cycle is included in the list but visually
//   dimmed with an "In Progress" badge (see CycleRowView). This way
//   the history feels complete — users can see the current period
//   alongside all past ones without any extra configuration.
// ============================================================

import SwiftUI
import SwiftData

struct BudgetHistoryView: View {

    // The budget whose cycle history we're displaying.
    // @Bindable lets SwiftUI react to changes on the @Model object.
    @Bindable var budget: Budget

    // MARK: - Computed Helpers

    /// All cycles, newest first.
    ///
    /// Uses Budget.sortedCycles (defined in Budget.swift) which sorts
    /// by startDate descending. This is an in-memory sort on the
    /// relationship array — no SwiftData query needed.
    private var sortedCycles: [BudgetCycle] {
        budget.sortedCycles
    }

    /// Stats for the summary header.
    private var completedCycles: [BudgetCycle] {
        sortedCycles.filter { !$0.isActive }
    }

    private var underCount: Int {
        completedCycles.filter { !$0.isOver }.count
    }

    private var overCount: Int {
        completedCycles.filter { $0.isOver }.count
    }

    private var totalSaved: Double {
        completedCycles
            .filter { !$0.isOver }
            .reduce(0) { $0 + $1.remainingAmount }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if sortedCycles.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Main List

    private var historyList: some View {
        ScrollView {
            VStack(spacing: 12) {

                // ── Summary header ──────────────────────────────────────
                // Quick scorecard across all completed cycles.
                if !completedCycles.isEmpty {
                    summaryHeader
                }

                // ── Section header ──────────────────────────────────────
                HStack {
                    Text("All Cycles")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(sortedCycles.count) total")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)

                // ── Cycle rows ──────────────────────────────────────────
                // Each BudgetCycle maps 1-to-1 to a CycleRowView.
                // sortedCycles is already newest-first (Budget.sortedCycles
                // sorts by startDate descending).
                ForEach(sortedCycles) { cycle in
                    CycleRowView(cycle: cycle)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Summary Header

    /// A card showing aggregate stats across all completed cycles.
    ///
    /// Three tiles:
    ///   • Under budget  (green)
    ///   • Over budget   (red)
    ///   • Total saved   (green, or hidden if zero)
    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Summary")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                summaryTile(
                    label: "Under",
                    value: "\(underCount)",
                    subtitle: underCount == 1 ? "cycle" : "cycles",
                    color: .green
                )
                summaryTile(
                    label: "Over",
                    value: "\(overCount)",
                    subtitle: overCount == 1 ? "cycle" : "cycles",
                    color: overCount > 0 ? .red : .secondary
                )
                summaryTile(
                    label: "Saved",
                    value: totalSaved.formatted(.currency(code: "USD")),
                    subtitle: "total",
                    color: totalSaved > 0 ? .green : .secondary
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func summaryTile(
        label: String,
        value: String,
        subtitle: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State

    /// Shown when no cycles exist yet (brand-new budget).
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("No History Yet")
                .font(.title3.weight(.semibold))

            Text("Past budget cycles will appear here\nautomatically as each period ends.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Preview

#Preview {
    // Build an in-memory store with a budget that has several cycles.
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Budget.self, BudgetCycle.self, Expense.self,
        configurations: config
    )

    let budget = Budget(name: "Groceries", totalAmount: 400)
    container.mainContext.insert(budget)

    let cal = Calendar.current

    // Seed three past cycles with varying spending.
    let cycleData: [(month: Int, spent: Double)] = [
        (month: 3, spent: 310),   // under — current month
        (month: 2, spent: 455),   // over
        (month: 1, spent: 375),   // under
    ]

    for item in cycleData {
        let start = cal.date(from: DateComponents(year: 2026, month: item.month, day: 1))!
        let lastDay = cal.range(of: .day, in: .month, for: start)!.upperBound - 1
        let end = cal.date(from: DateComponents(
            year: 2026, month: item.month, day: lastDay,
            hour: 23, minute: 59, second: 59
        ))!

        let cycle = BudgetCycle(budget: budget, startDate: start, endDate: end)
        container.mainContext.insert(cycle)

        let expense = Expense(amount: item.spent, note: "Grocery run")
        expense.budgetCycle = cycle
        container.mainContext.insert(expense)
    }

    return NavigationStack {
        BudgetHistoryView(budget: budget)
    }
    .modelContainer(container)
}
