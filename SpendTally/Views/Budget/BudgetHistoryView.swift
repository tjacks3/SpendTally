// ============================================================
// FILE:   BudgetHistoryView.swift
// LOCATION: SpendTally/Views/Budget/BudgetHistoryView.swift
//
// ACTION: REPLACE EXISTING FILE — full replacement.
//
// WHAT CHANGED vs. the previous version:
//
//   REMOVED — inline computed stats that lived directly on this View:
//     • completedCycles   (now handled by InsightCalculator)
//     • underCount        (now inside CycleInsights)
//     • overCount         (now inside CycleInsights)
//     • totalSaved        (replaced by averageSpend + best/worst)
//
//   REMOVED — the old summaryHeader computed view.
//     The three-tile card ("Under / Over / Saved") has been replaced
//     by InsightSummaryView, which shows a richer 5-stat panel.
//
//   ADDED — InsightCalculator usage:
//     A single computed property `insights` calls
//     InsightCalculator.calculate(from: budget.sortedCycles).
//     InsightCalculator owns all the math; this view only passes
//     cycles in and renders what comes back.
//
//   ADDED — InsightSummaryView:
//     Replaces the old summaryHeader. Self-contained; pass `insights`
//     and it handles its own empty-state guard internally.
//
// EVERYTHING ELSE IS UNCHANGED:
//   • historyList layout
//   • "All Cycles" section header with total count
//   • ForEach → CycleRowView rendering
//   • emptyState for brand-new budgets
//   • @Preview with seeded in-memory data
//
// WHY THE STATS WERE MOVED OUT OF THIS FILE:
//   Keeping calculations in the view makes them hard to test and
//   hard to reuse. InsightCalculator is a pure function — it can be
//   unit-tested independently. BudgetHistoryView becomes a thin
//   layout shell: query data, pass to sub-views, done.
//
// WIRING IT UP (DashboardView.swift):
//   Inside the DashboardView toolbar, add a ToolbarItem that
//   navigates here:
//
//       ToolbarItem(placement: .topBarLeading) {
//           NavigationLink(destination: BudgetHistoryView(budget: budget)) {
//               Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
//                   .labelStyle(.iconOnly)
//           }
//       }
//
// ============================================================

import SwiftUI
import SwiftData

struct BudgetHistoryView: View {

    // The budget whose cycle history we're displaying.
    // @Bindable lets SwiftUI react to changes on the @Model object.
    @Bindable var budget: Budget

    // MARK: - Computed Helpers

    /// All cycles for this budget, newest first.
    ///
    /// Uses Budget.sortedCycles (defined in Budget.swift) which sorts
    /// by startDate descending. This is an in-memory sort on the
    /// relationship array — no SwiftData query needed.
    private var sortedCycles: [BudgetCycle] {
        budget.sortedCycles
    }

    /// Summary statistics derived from the last 10 completed cycles.
    ///
    /// InsightCalculator.calculate() is an O(n ≤ 10) in-memory operation.
    /// Safe to call as a plain computed property — no async, no disk access.
    ///
    /// If no completed cycles exist yet, insights.isEmpty == true and
    /// InsightSummaryView renders nothing.
    private var insights: CycleInsights {
        InsightCalculator.calculate(from: sortedCycles)
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

                // ── Insight summary ─────────────────────────────────────
                // Renders the 5-stat panel (under/over counts, average,
                // best cycle, worst cycle) from the last 10 completed cycles.
                //
                // InsightSummaryView handles its own empty-state guard —
                // it shows nothing when insights.isEmpty is true. That means
                // if every cycle in sortedCycles is still "In Progress"
                // (i.e. there's only one cycle and it's the current one),
                // the panel is quietly hidden without any extra logic here.
                InsightSummaryView(insights: insights)

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

    // MARK: - Empty State

    /// Shown when no cycles exist yet (brand-new budget with zero history).
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

    // Seed cycles with varying spending to exercise all insight paths:
    //   month 3 → under   (current month — still In Progress)
    //   month 2 → over    (worst)
    //   month 1 → under   (best, lowest spend)
    let cycleData: [(month: Int, spent: Double)] = [
        (month: 3, spent: 310),
        (month: 2, spent: 455),
        (month: 1, spent: 285),
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
