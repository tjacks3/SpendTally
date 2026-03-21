// ============================================================
// FILE:   InsightSummaryView.swift
// LOCATION: SpendTally/Views/Budget/InsightSummaryView.swift
//
// ACTION: NEW FILE
//   1. Right-click the "Budget" folder inside "Views" in the
//      Xcode Project Navigator.
//   2. New File from Template → Swift File
//   3. Name it "InsightSummaryView"
//   4. Paste this entire file, replacing the generated stub.
//
// PURPOSE:
//   Displays the calculated CycleInsights at the top of the
//   Budget History screen. This file owns ALL the UI for the
//   summary panel — nothing insight-related lives in BudgetHistoryView.
//
// COMPONENT HIERARCHY:
//
//   InsightSummaryView          ← the public entry point; receives CycleInsights
//     ├─ insightHeader          ← "Insights · Based on X cycles" label
//     ├─ countsRow              ← Under / Over tiles side by side
//     │    └─ InsightCountTile  ← reusable count tile (label + big number)
//     ├─ averageSpendRow        ← full-width average spend tile
//     │    └─ InsightValueTile  ← reusable value tile (icon + label + value)
//     └─ extremesRow            ← Best cycle / Worst cycle side by side
//          └─ InsightCycleTile  ← cycle card showing date range + spend
//
// DESIGN PRINCIPLES:
//   • Matches the existing card style in BudgetHistoryView
//     (systemBackground fill, cornerRadius 16, grouped padding).
//   • No direct access to BudgetCycle properties inside this file —
//     everything is read from CycleInsights (passed in from the parent).
//   • The two BudgetCycle extremes (bestCycle / worstCycle) are accessed
//     only for their `totalSpent` and `startDate`. No relationship
//     traversal happens here.
//   • All sub-components are private structs inside this file so the
//     public API surface is just InsightSummaryView(insights:).
// ============================================================

import SwiftUI

// MARK: - InsightSummaryView (public entry point)

/// Drop-in summary panel for the top of BudgetHistoryView.
///
/// Usage:
///     InsightSummaryView(insights: insights)
///
/// The view renders nothing (EmptyView) when insights.isEmpty is true,
/// so the caller does not need a separate guard.
struct InsightSummaryView: View {

    let insights: CycleInsights

    var body: some View {

        // Guard: nothing to show for a brand-new budget with no history.
        if insights.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 14) {

                // ── Header label ──────────────────────────────────────────
                insightHeader

                // ── Row 1: Under / Over counts ────────────────────────────
                countsRow

                // ── Row 2: Average spend (full width) ─────────────────────
                averageSpendRow

                // ── Row 3: Best / Worst cycle extremes ────────────────────
                extremesRow
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        )
    }

    // MARK: - Header

    /// "Insights  ·  Based on X cycles"
    ///
    /// The count label tells the user exactly how many cycles the
    /// numbers are derived from. Especially important when fewer than
    /// 10 completed cycles exist (new budgets).
    private var insightHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Insights")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("·")
                .foregroundStyle(.tertiary)

            // Dynamic label: "Based on 1 cycle" vs "Based on 10 cycles"
            Text("Based on \(insights.analyzedCount) \(insights.analyzedCount == 1 ? "cycle" : "cycles")")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Counts Row

    /// Under-budget and over-budget cycle counts side by side.
    ///
    /// Each tile shows a large coloured number with a small label above
    /// and a caption below. Green = good (under), red = bad (over).
    private var countsRow: some View {
        HStack(spacing: 10) {

            InsightCountTile(
                label:    "Under Budget",
                count:    insights.underCount,
                caption:  insights.underCount == 1 ? "cycle" : "cycles",
                color:    .green,
                icon:     "checkmark.circle.fill"
            )

            InsightCountTile(
                label:    "Over Budget",
                count:    insights.overCount,
                caption:  insights.overCount == 1 ? "cycle" : "cycles",
                // Grey when zero — no bad cycles is a good thing, not alarming.
                color:    insights.overCount > 0 ? .red : .secondary,
                icon:     insights.overCount > 0 ? "exclamationmark.circle.fill" : "checkmark.circle"
            )
        }
    }

    // MARK: - Average Spend Row

    /// Full-width tile showing the mean spend across the analysed window.
    ///
    /// Average is calculated as: sum(totalSpent) / analyzedCount.
    /// Displayed in the system currency format (e.g. "$312.50").
    private var averageSpendRow: some View {
        InsightValueTile(
            icon:    "equal.circle.fill",
            label:   "Average Spend",
            value:   insights.averageSpend.formatted(.currency(code: "USD")),
            color:   .blue
        )
    }

    // MARK: - Extremes Row

    /// Best (lowest spend) and worst (highest spend) cycles.
    ///
    /// Each tile shows:
    ///   • A coloured icon (green crown vs red flame)
    ///   • A label ("Best" / "Worst")
    ///   • The cycle's totalSpent formatted as currency
    ///   • The cycle's month label (e.g. "Jan 2026")
    ///
    /// Both optionals are already guarded by isEmpty at the top of body,
    /// so `!` force-unwraps here are safe — InsightCalculator guarantees
    /// bestCycle and worstCycle are non-nil when analyzedCount > 0.
    private var extremesRow: some View {
        HStack(spacing: 10) {

            // Best = lowest totalSpent
            if let best = insights.bestCycle {
                InsightCycleTile(
                    label:       "Best Cycle",
                    cycle:       best,
                    color:       .green,
                    icon:        "crown.fill",
                    valuePrefix: ""
                )
            }

            // Worst = highest totalSpent
            if let worst = insights.worstCycle {
                InsightCycleTile(
                    label:       "Worst Cycle",
                    cycle:       worst,
                    color:       .red,
                    icon:        "flame.fill",
                    valuePrefix: ""
                )
            }
        }
    }
}

// MARK: - InsightCountTile (private)

/// A small card showing a count with a label, colour-coded icon, and caption.
///
/// Used for Under Budget / Over Budget counts.
private struct InsightCountTile: View {

    let label:   String
    let count:   Int
    let caption: String
    let color:   Color
    let icon:    String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            // Icon + label row
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Large count number
            Text("\(count)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            // Caption underneath the number
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - InsightValueTile (private)

/// A full-width tile displaying a single formatted value (e.g. average spend).
///
/// Used for the Average Spend row.
private struct InsightValueTile: View {

    let icon:  String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {

            // Coloured icon in a rounded square
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Label + value stacked vertically
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - InsightCycleTile (private)

/// A card for a specific cycle extreme (best or worst).
///
/// Shows: icon, label, the cycle's totalSpent, and the cycle's month label.
/// `cycle` is a BudgetCycle — we read only `totalSpent` and `startDate`.
private struct InsightCycleTile: View {

    let label:       String        // "Best Cycle" / "Worst Cycle"
    let cycle:       BudgetCycle
    let color:       Color
    let icon:        String
    let valuePrefix: String        // reserved for future prefix (e.g. "−")

    /// e.g. "Jan 2026" — uses DateFormatter for consistent formatting.
    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: cycle.startDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            // Icon + label row
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Spend amount — the key number
            Text(
                "\(valuePrefix)\(cycle.totalSpent.formatted(.currency(code: "USD")))"
            )
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            // Month label underneath
            Text(monthLabel)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview("Insight Summary — full data") {
    // Build in-memory cycles to drive the preview.
    // No ModelContainer needed here since InsightCalculator works on
    // plain BudgetCycle objects — we use lightweight fakes.

    let budget = Budget(name: "Groceries", totalAmount: 400)

    let cal = Calendar.current

    func makeCycle(month: Int, spent: Double) -> BudgetCycle {
        let start = cal.date(from: DateComponents(year: 2026, month: month, day: 1))!
        let end   = cal.date(from: DateComponents(year: 2026, month: month, day: 28,
                                                   hour: 23, minute: 59, second: 59))!
        let cycle = BudgetCycle(budget: budget, startDate: start, endDate: end)
        // Inject a single expense to set totalSpent indirectly — but since
        // the preview has no ModelContext, we rely on the relationship array.
        // For display purposes, we verify the layout without live SwiftData.
        return cycle
    }

    // For a clean preview without SwiftData, we construct a mock CycleInsights
    // directly — this is only for the Preview canvas.
    // In production, InsightCalculator.calculate(from:) is always used.
    let mockBest  = makeCycle(month: 1, spent: 220)
    let mockWorst = makeCycle(month: 2, spent: 490)

    let mockInsights = CycleInsights(
        analyzedCount: 7,
        underCount:    5,
        overCount:     2,
        averageSpend:  318.40,
        bestCycle:     mockBest,
        worstCycle:    mockWorst
    )

    return ScrollView {
        InsightSummaryView(insights: mockInsights)
            .padding(20)
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Insight Summary — empty") {
    InsightSummaryView(insights: CycleInsights(
        analyzedCount: 0,
        underCount:    0,
        overCount:     0,
        averageSpend:  0,
        bestCycle:     nil,
        worstCycle:    nil
    ))
    .padding(20)
    .background(Color(.systemGroupedBackground))
}
