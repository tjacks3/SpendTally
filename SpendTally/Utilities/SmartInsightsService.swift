// ============================================================
// FILE:   SmartInsightsService.swift
// LOCATION: SpendTally/Utilities/SmartInsightsService.swift
//
// ACTION: NEW FILE
//   1. Right-click the "Utilities" folder in the Xcode Project Navigator.
//   2. New File from Template → Swift File
//   3. Name it "SmartInsightsService"
//   4. Paste this entire file, replacing the generated stub.
//
// PURPOSE:
//   Generates plain-English behavioural insights from a Budget's
//   completed cycle history. No ML, no third-party libraries —
//   every insight is derived from simple arithmetic and counting
//   on data already in memory.
//
// WHAT IT GENERATES (up to three insights per budget):
//   1. Under-budget streak  — "You stayed under budget 4 cycles in a row"
//   2. End-of-cycle pattern — "You tend to overspend near the end of cycles"
//   3. Average vs budget    — "Your average spend is 18% below budget"
//
// HOW TO USE:
//   Call SmartInsightsService.generate(from: budget.sortedCycles)
//   and bind the returned [SmartInsight] to any view.
//
//   Example in a View:
//
//       private var insights: [SmartInsight] {
//           SmartInsightsService.generate(from: budget.sortedCycles)
//       }
//
//   Then iterate with ForEach(insights) { insight in ... }
//
// MINIMUM DATA REQUIREMENTS:
//   • Streak insight        — ≥ 2 completed cycles
//   • End-of-cycle pattern  — ≥ 3 completed cycles that contain expenses
//   • Average vs budget     — ≥ 1 completed cycle
//
// RELATIONSHIP TO InsightCalculator:
//   InsightCalculator (InsightCalculator.swift) produces *aggregate
//   statistics* (averageSpend, underCount, bestCycle …) for the
//   History screen's summary tile.
//   SmartInsightsService produces *human-readable sentences* that
//   describe the user's behavioural patterns.
//   Both are stateless enums. Neither owns UI. They can be used
//   independently or alongside each other.
//
// PERFORMANCE:
//   All data is already in memory as part of the Budget relationship
//   graph. The most expensive operation is iterating each cycle's
//   expenses array for the end-of-cycle check — O(n × m) where
//   n ≤ 10 cycles and m is the expense count per cycle (typically < 50).
//   Safe to call as a computed property directly in a SwiftUI View body.
// ============================================================

import Foundation

// MARK: - InsightTone

/// Controls how a SmartInsight is rendered in the UI.
///
/// The View should map these to colors:
///   .positive → green (tint)
///   .warning  → orange (tint)
///   .neutral  → .secondary (tint)
enum InsightTone {
    case positive   // user is doing well — green
    case warning    // user may want to adjust — orange
    case neutral    // informational only — secondary grey
}

// MARK: - SmartInsight

/// A single human-readable observation about spending behaviour.
///
/// Identifiable so it can be used directly in ForEach without a
/// key-path — each call to generate() produces fresh UUIDs, which
/// is correct because insights are recomputed, not persisted.
struct SmartInsight: Identifiable {
    let id      = UUID()
    let icon    : String        // SF Symbol name — display with Image(systemName:)
    let message : String        // Full sentence, e.g. "You stayed under budget 4 cycles in a row"
    let tone    : InsightTone   // Drives tint colour in the receiving view
}

// MARK: - SmartInsightsService

/// Stateless service — all methods are static.
///
/// Follows the same design pattern as InsightCalculator:
/// pure inputs → pure outputs, no SwiftData writes, no @State,
/// no async, no side effects.
enum SmartInsightsService {

    // =========================================================================
    // MARK: - Public API
    // =========================================================================

    /// Generate all applicable insights for a budget's cycle history.
    ///
    /// - Parameter cycles: All cycles for the budget (sorted or unsorted —
    ///   this method sorts internally and caps at the 10 most recent).
    /// - Returns: Up to three SmartInsight values in priority order.
    ///   Returns an empty array when there is insufficient history.
    ///
    /// ORDER OF RESULTS:
    ///   1. Streak (most motivating — shown first)
    ///   2. End-of-cycle pattern (actionable warning)
    ///   3. Average vs budget (summary context)
    static func generate(from cycles: [BudgetCycle]) -> [SmartInsight] {

        // ── Prepare the analysis window ──────────────────────────────────────
        // Only completed (non-active) cycles are meaningful here.
        // The in-progress cycle's spend is still growing, so including it
        // would produce unstable or misleading insights.
        //
        // Sort newest-first so prefix(10) gives the *most recent* 10 cycles,
        // matching the same window used by InsightCalculator.
        let window = Array(
            cycles
                .filter { !$0.isActive }
                .sorted { $0.startDate > $1.startDate }
                .prefix(10)
        )

        guard !window.isEmpty else { return [] }

        // Collect whichever insights have enough data to fire.
        return [
            underBudgetStreakInsight(from: window),
            endOfCycleSpendInsight(from: window),
            averageSpendInsight(from: window),
        ].compactMap { $0 }
    }

    // =========================================================================
    // MARK: - Insight #1 — Under-budget streak
    // =========================================================================
    //
    // QUESTION:  Has the user been consistently under budget recently?
    //
    // ALGORITHM:
    //   Walk the analysis window newest-first (window[0] = most recent cycle).
    //   Count consecutive cycles where isOver == false.
    //   Stop counting the moment an over-budget cycle is encountered.
    //
    //   WHY consecutive and not total?
    //   A streak communicates momentum. "4 months in a row" is more
    //   motivating and honest than "4 out of 10 months (but not recently)".
    //
    // THRESHOLD: streak ≥ 2
    //   A single under-budget cycle is not a pattern — it's just one data
    //   point. We wait for two or more consecutive successes before
    //   acknowledging the trend.
    //
    // EXAMPLE OUTPUT:
    //   streak = 4 → "You stayed under budget 4 cycles in a row"  (positive)
    //   streak = 2 → "You stayed under budget 2 cycles in a row"  (positive)
    //   streak = 1 → nil (not enough to call a streak)

    private static func underBudgetStreakInsight(
        from window: [BudgetCycle]
    ) -> SmartInsight? {
        var streak = 0
        for cycle in window {
            // window is newest-first; we walk forward and stop at the
            // first over-budget cycle, so only the *current* run counts.
            if !cycle.isOver {
                streak += 1
            } else {
                break
            }
        }

        guard streak >= 2 else { return nil }

        let cycleWord = streak == 1 ? "cycle" : "cycles"
        return SmartInsight(
            icon:    "flame.fill",
            message: "You stayed under budget \(streak) \(cycleWord) in a row",
            tone:    .positive
        )
    }

    // =========================================================================
    // MARK: - Insight #2 — End-of-cycle overspend pattern
    // =========================================================================
    //
    // QUESTION:  Does the user consistently spend more in the second half
    //            of their budget cycles than the first?
    //
    // ALGORITHM:
    //   For each completed cycle that has at least one expense:
    //
    //     1. Calculate the midpoint of the cycle's time window:
    //          midpoint = startDate + (endDate - startDate) / 2
    //
    //     2. Split the cycle's expenses into two groups:
    //          firstHalf  = expenses with date < midpoint
    //          secondHalf = expenses with date ≥ midpoint
    //
    //     3. Sum each group. If secondHalf ≥ 65% of totalSpent,
    //        the cycle is classified as "back-loaded".
    //
    //   After checking all cycles, calculate:
    //     backLoadedRatio = backLoadedCount / cyclesWithExpenses.count
    //
    //   If backLoadedRatio ≥ 0.60, emit the insight.
    //
    // THRESHOLDS:
    //   65% (per cycle) — the second half must hold a clear majority of
    //   spending, not just a slight edge. Accounts for normal variance.
    //
    //   60% (across cycles) — the majority of analyzed cycles must show
    //   this pattern before we surface it. One or two back-loaded cycles
    //   could be coincidence (holiday, pay cycle, etc.).
    //
    //   Minimum 3 cycles with expenses — ensures we have enough data
    //   to call something a pattern.
    //
    // EXAMPLE OUTPUT:
    //   7 of 10 cycles are back-loaded → "You tend to overspend near the
    //                                     end of cycles"  (warning)
    //   2 of 5 cycles are back-loaded  → nil (not enough signal)

    private static func endOfCycleSpendInsight(
        from window: [BudgetCycle]
    ) -> SmartInsight? {
        let cyclesWithExpenses = window.filter { !$0.expenses.isEmpty }
        guard cyclesWithExpenses.count >= 3 else { return nil }

        let backLoadedCount = cyclesWithExpenses.filter { isBackLoaded($0) }.count

        let ratio = Double(backLoadedCount) / Double(cyclesWithExpenses.count)
        guard ratio >= 0.60 else { return nil }

        return SmartInsight(
            icon:    "clock.badge.exclamationmark.fill",
            message: "You tend to overspend near the end of cycles",
            tone:    .warning
        )
    }

    /// Returns true when ≥ 65% of a cycle's total spend falls in the
    /// second half of its time window.
    ///
    /// Uses wall-clock midpoint (not transaction count midpoint) because
    /// the design principle is time-based: "near the end of the cycle"
    /// means a time position, not a transaction rank.
    private static func isBackLoaded(_ cycle: BudgetCycle) -> Bool {
        guard cycle.totalSpent > 0 else { return false }

        let cycleDuration = cycle.endDate.timeIntervalSince(cycle.startDate)
        let midpoint      = cycle.startDate.addingTimeInterval(cycleDuration / 2)

        let secondHalfSpend = cycle.expenses
            .filter  { $0.date >= midpoint }
            .reduce(0.0) { $0 + $1.amount }

        return (secondHalfSpend / cycle.totalSpent) >= 0.65
    }

    // =========================================================================
    // MARK: - Insight #3 — Average spend vs budget
    // =========================================================================
    //
    // QUESTION:  Is the user habitually under or over their budget limit
    //            on average, and by how much?
    //
    // ALGORITHM:
    //   1. Sum totalSpent across all cycles in the window.
    //   2. Sum totalAmount across all cycles in the window.
    //      (Using the per-cycle snapshotted amount — not the current
    //      Budget.totalAmount — so a budget that was raised mid-year
    //      is still evaluated correctly against its historical limits.)
    //   3. ratio = totalSpent / totalBudget
    //   4. percentage = |1 - ratio| * 100, rounded to nearest integer.
    //
    //   ratio < 0.90  → user is at least 10% below on average → positive
    //   ratio > 1.05  → user is at least 5% above on average  → warning
    //   0.90–1.05     → within a "normal" band, no insight emitted
    //
    // WHY A BAND INSTEAD OF ANY DIFFERENCE:
    //   Small differences (e.g. 3% below) are noise — they might just mean
    //   the user rounded down when setting the budget. We only surface this
    //   insight when the gap is meaningful enough to act on.
    //
    //   The warning band (> 1.05) is intentionally narrower than the
    //   positive band (< 0.90) — we want to gently surface overspend
    //   sooner than we celebrate savings.
    //
    // EXAMPLE OUTPUT:
    //   ratio = 0.78 → "Your average spend is 22% below budget"  (positive)
    //   ratio = 1.14 → "Your average spend is 14% above budget"  (warning)
    //   ratio = 0.96 → nil (within normal band)

    private static func averageSpendInsight(
        from window: [BudgetCycle]
    ) -> SmartInsight? {
        guard !window.isEmpty else { return nil }

        let totalSpent  = window.reduce(0.0) { $0 + $1.totalSpent  }
        let totalBudget = window.reduce(0.0) { $0 + $1.totalAmount }
        guard totalBudget > 0 else { return nil }

        let ratio      = totalSpent / totalBudget
        let percentage = Int((abs(1.0 - ratio) * 100).rounded())

        if ratio < 0.90 {
            return SmartInsight(
                icon:    "chart.line.downtrend.xyaxis",
                message: "Your average spend is \(percentage)% below budget",
                tone:    .positive
            )
        } else if ratio > 1.05 {
            return SmartInsight(
                icon:    "chart.line.uptrend.xyaxis",
                message: "Your average spend is \(percentage)% above budget",
                tone:    .warning
            )
        }

        // Within the 90–105% band: not worth surfacing.
        return nil
    }
}

// ============================================================
// HOW TO DISPLAY — paste into BudgetHistoryView.swift (or any
// view that has access to a Budget):
//
//   private var insights: [SmartInsight] {
//       SmartInsightsService.generate(from: budget.sortedCycles)
//   }
//
//   // Then inside your body:
//   if !insights.isEmpty {
//       VStack(alignment: .leading, spacing: 12) {
//           Text("Insights")
//               .font(.headline)
//           ForEach(insights) { insight in
//               SmartInsightRow(insight: insight)
//           }
//       }
//       .padding(.horizontal, 20)
//   }
//
// HOW TO COLOR BY TONE (in your row view):
//
//   private var toneColor: Color {
//       switch insight.tone {
//       case .positive: return .green
//       case .warning:  return .orange
//       case .neutral:  return .secondary
//       }
//   }
// ============================================================
