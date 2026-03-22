// ============================================================
// FILE:   BudgetHistoryView.swift
// LOCATION: SpendTally/Views/Budget/BudgetHistoryView.swift
//
// ACTION: REPLACE EXISTING FILE — full replacement.
//
// WHAT CHANGED vs. the previous version:
//
//   ADDED — smartInsights computed property:
//     Calls SmartInsightsService.generate(from: sortedCycles).
//     Returns [SmartInsight] — up to three plain-English sentences
//     about the user's spending behaviour.
//
//   ADDED — smartInsightsSection computed view:
//     Renders each SmartInsight as a SmartInsightRow card.
//     Placed between InsightSummaryView (aggregate stats) and the
//     "All Cycles" list header. Hidden automatically when the array
//     is empty (new budgets with no completed cycles).
//
//   ADDED — SmartInsightRow (private struct, bottom of this file):
//     A self-contained row that receives one SmartInsight and renders:
//       • SF Symbol icon, tinted by InsightTone
//       • Plain-English message string
//     Matches the card visual style used throughout the History screen.
//
// EVERYTHING ELSE IS UNCHANGED:
//   • @Bindable budget property
//   • sortedCycles computed helper
//   • insights (CycleInsights) computed property via InsightCalculator
//   • InsightSummaryView placement and behaviour
//   • historyList ScrollView structure
//   • "All Cycles" section header with total count
//   • ForEach → CycleRowView
//   • emptyState view
//   • #Preview with seeded in-memory data
//
// LAYOUT AFTER THIS CHANGE (top → bottom inside historyList):
//   1. InsightSummaryView     — aggregate stats (under/over/avg/best/worst)
//   2. smartInsightsSection   — behavioural sentences from SmartInsightsService  ← NEW
//   3. "All Cycles" header    — cycle count label
//   4. CycleRowView × N       — one row per cycle
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
    /// by startDate descending. In-memory sort — no SwiftData query needed.
    private var sortedCycles: [BudgetCycle] {
        budget.sortedCycles
    }

    /// Aggregate statistics from the last 10 completed cycles.
    ///
    /// InsightCalculator is O(n ≤ 10) — safe as a computed property in body.
    /// When no completed cycles exist, insights.isEmpty == true and
    /// InsightSummaryView renders nothing.
    private var insights: CycleInsights {
        InsightCalculator.calculate(from: sortedCycles)
    }

    /// Behavioural pattern insights from SmartInsightsService.
    ///
    /// Returns up to three SmartInsight values:
    ///   1. Under-budget streak  (if ≥ 2 consecutive under-budget cycles)
    ///   2. End-of-cycle pattern (if ≥ 60% of cycles are back-loaded)
    ///   3. Average vs budget    (if avg spend is > 10% below or > 5% above)
    ///
    /// Returns [] when there is insufficient history — the section is
    /// hidden automatically, no guard needed at the call site.
    private var smartInsights: [SmartInsight] {
        SmartInsightsService.generate(from: sortedCycles)
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

                // ── 1. Aggregate stats panel ────────────────────────────
                // Under/Over counts, average spend, best and worst cycle.
                // InsightSummaryView guards internally — shows nothing when
                // insights.isEmpty is true.
                InsightSummaryView(insights: insights)

                // ── 2. Behavioural pattern insights ─────────────────────
                // Plain-English sentences from SmartInsightsService.
                // Hidden automatically when smartInsights is empty.
                smartInsightsSection

                // ── 3. Section header ───────────────────────────────────
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

                // ── 4. Cycle rows ───────────────────────────────────────
                // sortedCycles is already newest-first.
                ForEach(sortedCycles) { cycle in
                    CycleRowView(cycle: cycle)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Smart Insights Section

    /// Renders the SmartInsight cards between the aggregate stats panel
    /// and the cycle list.
    ///
    /// WHY @ViewBuilder instead of a plain computed View:
    ///   The guard (smartInsights.isEmpty) needs to return EmptyView.
    ///   @ViewBuilder lets us write that guard/else branch naturally
    ///   without wrapping in AnyView.
    @ViewBuilder
    private var smartInsightsSection: some View {
        if !smartInsights.isEmpty {
            VStack(alignment: .leading, spacing: 8) {

                // Section label — consistent with InsightSummaryView's
                // "Insights" header style.
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Patterns")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                .padding(.horizontal, 2)

                // One card per insight.
                // SmartInsight is Identifiable via its UUID, so ForEach
                // needs no explicit id parameter.
                ForEach(smartInsights) { insight in
                    SmartInsightRow(insight: insight)
                }
            }
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

// MARK: - SmartInsightRow

/// A single insight card rendered inside the "Patterns" section.
///
/// Layout:
///   [ tinted icon ] [ message text ]
///
/// Tone → colour mapping:
///   .positive → green    (streak, under-budget average)
///   .warning  → orange   (end-of-cycle pattern, over-budget average)
///   .neutral  → secondary grey (informational)
///
/// This struct is private to this file — SmartInsightRow is an
/// implementation detail of BudgetHistoryView, not a reusable component.
private struct SmartInsightRow: View {

    let insight: SmartInsight

    var body: some View {
        HStack(spacing: 14) {

            // Tinted icon in a pill background
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(toneColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: insight.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(toneColor)
            }

            // Message — allow two lines for longer sentences
            Text(insight.message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Maps InsightTone to a SwiftUI Color.
    ///
    /// .neutral uses Color.secondary rather than a literal grey so it
    /// automatically adapts between light and dark mode.
    private var toneColor: Color {
        switch insight.tone {
        case .positive: return .green
        case .warning:  return .orange
        case .neutral:  return Color(.secondaryLabel)
        }
    }
}

// MARK: - Preview

#Preview("Full History — with SmartInsights") {
    // In-memory store with enough cycles to fire all three smart insights:
    //
    //   Streak insight       — months 1–4 all under budget (streak = 4)
    //   End-of-cycle pattern — months 1–5 back-loaded (≥ 60%)
    //   Average insight      — total spend ~78% of budget → "22% below"
    //
    // Month 3 is the active cycle (startDate = Mar 1, endDate = Mar 31 2026).
    // The other five are completed.

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Budget.self, BudgetCycle.self, Expense.self,
        configurations: config
    )

    let budget = Budget(name: "Groceries", totalAmount: 400)
    container.mainContext.insert(budget)

    let cal = Calendar.current

    // Each tuple: (year, month, earlySpend, lateSpend)
    //   earlySpend = expense logged on day 5 (first-half)
    //   lateSpend  = expense logged on day 25 (second-half)
    // Back-loaded = lateSpend / total ≥ 65%
    let cycleData: [(year: Int, month: Int, earlySpend: Double, lateSpend: Double)] = [
        (2025, 10, 40,  275),   // back-loaded, under budget
        (2025, 11, 50,  255),   // back-loaded, under budget
        (2025, 12, 35,  230),   // back-loaded, under budget
        (2026,  1, 45,  265),   // back-loaded, under budget (streak starts)
        (2026,  2, 60,  270),   // back-loaded, under budget (streak continues)
        (2026,  3, 80,    0),   // ACTIVE cycle — excluded from analysis
    ]

    for item in cycleData {
        let start = cal.date(from: DateComponents(
            year: item.year, month: item.month, day: 1
        ))!
        let lastDay = cal.range(of: .day, in: .month, for: start)!.upperBound - 1
        let end = cal.date(from: DateComponents(
            year: item.year, month: item.month, day: lastDay,
            hour: 23, minute: 59, second: 59
        ))!

        let cycle = BudgetCycle(budget: budget, startDate: start, endDate: end)
        container.mainContext.insert(cycle)

        // Early expense — day 5
        if item.earlySpend > 0 {
            let earlyDate = cal.date(from: DateComponents(
                year: item.year, month: item.month, day: 5
            ))!
            let early = Expense(amount: item.earlySpend, note: "Early shop", date: earlyDate)
            early.budgetCycle = cycle
            container.mainContext.insert(early)
        }

        // Late expense — day 25 (second half of month)
        if item.lateSpend > 0 {
            let lateDate = cal.date(from: DateComponents(
                year: item.year, month: item.month, day: 25
            ))!
            let late = Expense(amount: item.lateSpend, note: "Big shop", date: lateDate)
            late.budgetCycle = cycle
            container.mainContext.insert(late)
        }
    }

    return NavigationStack {
        BudgetHistoryView(budget: budget)
    }
    .modelContainer(container)
}

#Preview("Empty — no history") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Budget.self, BudgetCycle.self, Expense.self,
        configurations: config
    )
    let budget = Budget(name: "Groceries", totalAmount: 400)
    container.mainContext.insert(budget)

    return NavigationStack {
        BudgetHistoryView(budget: budget)
    }
    .modelContainer(container)
}
