// ============================================================
// FILE:   InsightCalculator.swift
// LOCATION: SpendTally/Utilities/InsightCalculator.swift
//
// ACTION: NEW FILE
//   1. Right-click the "Utilities" folder in the Xcode Project Navigator.
//   2. New File from Template → Swift File
//   3. Name it "InsightCalculator"
//   4. Paste this entire file, replacing the generated stub.
//
// PURPOSE:
//   Pure calculation logic for the History screen's summary insights.
//   No UI, no SwiftData writes, no side effects — only inputs and outputs.
//
//   InsightCalculator takes an array of BudgetCycle objects and returns
//   a CycleInsights value type containing every stat the UI needs.
//
// WHAT IT CALCULATES (from the last 10 completed cycles only):
//   • analyzedCount   — how many cycles were included (1–10)
//   • underCount      — cycles where spending stayed within budget
//   • overCount       — cycles where spending exceeded the limit
//   • averageSpend    — mean totalSpent across the analyzed set
//   • bestCycle       — the cycle with the lowest totalSpent
//   • worstCycle      — the cycle with the highest totalSpent
//
// WHY "LAST 10" AS THE WINDOW:
//   • Gives a meaningful, bounded sample without overwhelming the UI.
//   • 10 cycles = 10 months for monthly budgets, ~10 weeks for weekly.
//   • Keeps averages and comparisons relevant to recent behaviour.
//   • If fewer than 10 completed cycles exist, all of them are used and
//     analyzedCount reflects the real count so the UI can say "Based on
//     3 cycles" rather than implying a full 10.
//
// DESIGN DECISIONS:
//   • Only COMPLETED cycles are analysed (isActive == false).
//     The in-progress cycle is excluded because its totalSpent is still
//     growing — including it would distort averages and best/worst.
//
//   • The cap is applied AFTER filtering completed cycles and sorting
//     newest-first, so "last 10" always means the 10 most recent
//     completed cycles — never older ones.
//
//   • bestCycle and worstCycle are optional (nil when analyzedCount == 0).
//     Both are safe to unwrap with `if let` in the view without crashing.
//
//   • CycleInsights is a value type (struct). It is computed once on the
//     main thread and stored as a computed property on the View — no
//     ViewModel, no @State, no async work needed.
//
// PERFORMANCE:
//   BudgetCycle objects are already in memory as part of the Budget
//   relationship graph by the time the History screen is shown.
//   InsightCalculator.calculate() runs entirely on that in-memory array
//   with no SwiftData fetch, no disk access, and no async overhead.
//
//   The algorithmic cost is O(n) where n ≤ 10 (capped window). The sort
//   before the prefix is O(m log m) on the full completed set, but m is
//   rarely more than a few dozen entries in practice.
//
//   Because the calculation is O(10) in the steady state, it is safe to
//   call it as a computed property directly in a SwiftUI View body — no
//   memoisation or caching layer is needed.
//
// HOW TO USE:
//   In any View that has access to a Budget:
//
//       private var insights: CycleInsights {
//           InsightCalculator.calculate(from: budget.sortedCycles)
//       }
//
//   Then pass `insights` to InsightSummaryView(insights:).
// ============================================================

import Foundation

// MARK: - CycleInsights

/// A snapshot of aggregate statistics computed across the last 10
/// completed budget cycles for a single Budget.
///
/// This is a value type — copy it freely. It holds no references to
/// SwiftData models except the optional best/worst cycle pointers,
/// which are safe to read at any point after the calculation completes.
struct CycleInsights {

    // ── Sample size ──────────────────────────────────────────────────────────

    /// How many completed cycles were included in this analysis (1–10).
    ///
    /// Drives the label "Based on X cycles" so users understand the
    /// sample size behind each stat.
    let analyzedCount: Int

    // ── Pass / Fail counts ───────────────────────────────────────────────────

    /// Cycles where totalSpent stayed within (or exactly at) the budget limit.
    /// Derived from: !cycle.isOver
    let underCount: Int

    /// Cycles where totalSpent exceeded the budget limit.
    /// Derived from: cycle.isOver
    let overCount: Int

    // ── Spend stats ──────────────────────────────────────────────────────────

    /// Mean totalSpent across all analyzed cycles.
    ///
    /// Formula: sum(totalSpent) / analyzedCount
    /// Returns 0 when analyzedCount is 0 (guard inside calculate()).
    let averageSpend: Double

    // ── Extremes ─────────────────────────────────────────────────────────────

    /// The cycle with the lowest totalSpent in the analyzed set.
    /// nil only when analyzedCount == 0.
    let bestCycle: BudgetCycle?

    /// The cycle with the highest totalSpent in the analyzed set.
    /// nil only when analyzedCount == 0.
    let worstCycle: BudgetCycle?

    // ── Convenience ──────────────────────────────────────────────────────────

    /// True when there are no completed cycles to analyze.
    /// The UI uses this to hide the insight panel entirely on new budgets.
    var isEmpty: Bool { analyzedCount == 0 }

    /// 0.0–1.0 ratio of under-budget cycles.
    /// Used to tint the score ring or progress indicator.
    var successRate: Double {
        guard analyzedCount > 0 else { return 0 }
        return Double(underCount) / Double(analyzedCount)
    }
}

// MARK: - InsightCalculator

/// Stateless calculator — all methods are static.
/// Call InsightCalculator.calculate(from:) and use the returned CycleInsights.
enum InsightCalculator {

    // =========================================================================
    // MARK: - Public API
    // =========================================================================

    /// Calculates summary insights from an array of BudgetCycle objects.
    ///
    /// - Parameter cycles: The full list of cycles for a budget (sortedCycles
    ///   or unsorted — the function sorts internally).
    /// - Returns: A CycleInsights value ready for display.
    ///
    /// STEPS INSIDE THIS FUNCTION:
    ///   1. Filter — keep only completed (non-active) cycles.
    ///   2. Sort   — newest-first so prefix(10) gives the *most recent* 10.
    ///   3. Cap    — take at most 10 cycles via prefix(10).
    ///   4. Guard  — return an empty CycleInsights if nothing remains.
    ///   5. Count  — underCount and overCount from isOver.
    ///   6. Average — sum totalSpent, divide by count.
    ///   7. Best/Worst — min/max by totalSpent.
    static func calculate(from cycles: [BudgetCycle]) -> CycleInsights {

        // ── Step 1: completed cycles only ────────────────────────────────────
        // Active cycles are excluded because their spend is still growing.
        // Including the in-progress cycle would skew averages and
        // misrepresent best/worst comparisons.
        let completed = cycles.filter { !$0.isActive }

        // ── Step 2 & 3: sort newest-first, then cap at 10 ───────────────────
        // Sorting before prefix ensures we always analyse the 10 MOST RECENT
        // completed cycles, not the first 10 inserted into the database.
        let analyzed = Array(
            completed
                .sorted { $0.startDate > $1.startDate }
                .prefix(10)
        )

        // ── Step 4: guard against empty input ────────────────────────────────
        guard !analyzed.isEmpty else {
            return CycleInsights(
                analyzedCount: 0,
                underCount:    0,
                overCount:     0,
                averageSpend:  0,
                bestCycle:     nil,
                worstCycle:    nil
            )
        }

        // ── Step 5: pass/fail counts ─────────────────────────────────────────
        // BudgetCycle.isOver returns true when remainingAmount < 0.
        // We invert for underCount so the two values always sum to analyzedCount.
        let underCount = analyzed.filter { !$0.isOver }.count
        let overCount  = analyzed.filter {  $0.isOver }.count

        // ── Step 6: average spend ────────────────────────────────────────────
        // Sum every cycle's totalSpent (which is already the sum of its
        // expenses via BudgetCycle.totalSpent), then divide by count.
        let totalSpend   = analyzed.reduce(0.0) { $0 + $1.totalSpent }
        let averageSpend = totalSpend / Double(analyzed.count)

        // ── Step 7: best and worst ───────────────────────────────────────────
        // min(by:) returns the cycle with the LOWEST spend  → best performance.
        // max(by:) returns the cycle with the HIGHEST spend → worst performance.
        // Both are guaranteed non-nil here because analyzed is non-empty (step 4).
        let bestCycle  = analyzed.min { $0.totalSpent < $1.totalSpent }
        let worstCycle = analyzed.max { $0.totalSpent < $1.totalSpent }

        return CycleInsights(
            analyzedCount: analyzed.count,
            underCount:    underCount,
            overCount:     overCount,
            averageSpend:  averageSpend,
            bestCycle:     bestCycle,
            worstCycle:    worstCycle
        )
    }
}
