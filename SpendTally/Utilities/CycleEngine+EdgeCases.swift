// ============================================================
// FILE:   CycleEngine+EdgeCases.swift
// LOCATION: SpendTally/Utilities/CycleEngine+EdgeCases.swift
//
// ACTION: NEW FILE — paste alongside the existing CycleEngine.swift.
//         Swift extensions can live in separate files, so nothing in
//         the original CycleEngine.swift needs to change.
//
// WHAT THIS FILE ADDS:
//   1. EditScope enum — two choices when an amount changes mid-cycle
//   2. applyBudgetAmountEdit — the ONLY safe way to change a budget's amount
//   3. setPaused — toggles pause without breaking history
//
// WHAT STAYS UNCHANGED:
//   • handleMissedCycles (already covers Case 1 — missed cycles)
//     It is called by ensureActiveCycleExists, which is invoked by:
//       – BudgetListView .task {} (first open)
//       – BudgetListView .onChange(scenePhase) (foreground return)
//       – BudgetViewModel.refreshAllCycles (both hooks above call this)
//     Paused budgets are already skipped in refreshAllCycles via:
//       guard !budget.isPaused else { continue }
// ============================================================

import Foundation
import SwiftData

// ============================================================
// MARK: - EditScope
// ============================================================
//
// When a user changes the dollar amount of a budget mid-cycle,
// we need to know: does the change affect what's happening NOW
// (the current cycle), or only what comes NEXT (future cycles)?
//
// This enum is the user's answer to that question, captured
// after they tap Save in EditBudgetView and confirm the alert.
//
// WHY THIS MATTERS (the snapshot contract):
//   BudgetCycle.totalAmount is a snapshot copied from Budget.totalAmount
//   at cycle creation time. That snapshot is what makes history accurate.
//   If a user raised their grocery budget from $400 → $500 in March,
//   their February cycle must still show $400 — not the new $500.
//
//   applyBudgetAmountEdit() respects this contract. It never retroactively
//   changes completed cycles — only the active cycle (if .currentCycleOnly)
//   or the template amount for future snapshots (if .futureOnly).

enum EditScope {
    /// Patch the ACTIVE cycle's totalAmount snapshot only.
    ///
    /// Use when the user says: "just for this month, I have extra budget."
    /// budget.totalAmount is intentionally NOT changed, so the next cycle
    /// resets back to the original amount.
    case currentCycleOnly

    /// Change budget.totalAmount (the template) only.
    ///
    /// Use when the user says: "going forward, my limit is different."
    /// The active cycle keeps its existing snapshot — history stays intact.
    /// Future generateNextCycle calls will snapshot the new value.
    case futureOnly
}

// ============================================================
// MARK: - CycleEngine Extension
// ============================================================

extension CycleEngine {

    // =========================================================================
    // MARK: - Case 1: Missed Cycles (documentation note only)
    // =========================================================================
    //
    // No new code needed for missed cycles — handleMissedCycles() already
    // handles this correctly in the main CycleEngine.swift.
    //
    // HOW IT WORKS ON NEXT APP OPEN:
    //   1. App launches → BudgetListView .task fires
    //   2. vm.refreshAllCycles(budgets:context:) is called
    //   3. For each non-paused budget, CycleEngine.ensureActiveCycleExists runs
    //   4. ensureActiveCycleExists calls handleMissedCycles()
    //   5. handleMissedCycles() loops: generates one cycle per missed period
    //      until the newest cycle covers today (capped at 366 iterations)
    //   6. User sees today's cycle — time felt invisible
    //
    // The same flow repeats when the app returns from background
    // (BudgetListView .onChange(scenePhase == .active)).
    //
    // SAFETY CAP: 366 iterations prevents runaway loops if a budget
    // was abandoned for years. After the cap, the user sees the most
    // recent generated cycle and can decide what to do.

    // =========================================================================
    // MARK: - Case 2: Budget Edited Mid-Cycle
    // =========================================================================

    /// The ONLY correct way to change a budget's amount after cycles exist.
    ///
    /// Never write `budget.totalAmount = x` directly from a view or ViewModel
    /// when the budget already has cycles — the snapshot contract will break.
    /// Always call this method and pass an EditScope.
    ///
    /// SAFE UPDATE STRATEGIES by scope:
    ///
    ///   .currentCycleOnly
    ///     – Writes: activeCycle.totalAmount = newAmount
    ///     – Does NOT change: budget.totalAmount
    ///     – Effect: the current cycle reflects the new limit immediately.
    ///       The next cycle will revert to the original budget.totalAmount.
    ///     – Use case: "I got a bonus this month, I can spend more."
    ///
    ///   .futureOnly
    ///     – Writes: budget.totalAmount = newAmount
    ///     – Does NOT change: activeCycle.totalAmount
    ///     – Effect: the current cycle continues under its original limit.
    ///       Future generateNextCycle calls snapshot the new budget.totalAmount.
    ///     – Use case: "Starting next cycle, my grocery budget is $600."
    ///
    /// In both cases, completed (historical) cycles are NEVER touched.
    static func applyBudgetAmountEdit(
        to budget: Budget,
        newAmount: Double,
        scope: EditScope,
        context: ModelContext
    ) {
        switch scope {

        case .currentCycleOnly:
            // Find the cycle that covers today and patch its snapshot.
            // If no active cycle exists (paused budget), nothing changes —
            // ensureActiveCycleExists will use budget.totalAmount when it
            // eventually creates the next cycle.
            if let activeCycle = getCurrentCycle(for: budget) {
                activeCycle.totalAmount = newAmount
                print(
                    "[CycleEngine] \"\(budget.name)\": current cycle amount patched to " +
                    "\(newAmount). budget.totalAmount unchanged (\(budget.totalAmount))."
                )
            } else {
                print(
                    "[CycleEngine] \"\(budget.name)\": no active cycle found. " +
                    "currentCycleOnly edit had no effect."
                )
            }

        case .futureOnly:
            // Update the template. The snapshot on the active cycle is untouched.
            let previousAmount = budget.totalAmount
            budget.totalAmount = newAmount
            print(
                "[CycleEngine] \"\(budget.name)\": budget.totalAmount changed " +
                "\(previousAmount) → \(newAmount). Active cycle snapshot unchanged."
            )
        }
    }

    // =========================================================================
    // MARK: - Case 3: Pause / Resume
    // =========================================================================

    /// Sets a budget's pause state safely.
    ///
    /// PAUSED BEHAVIOUR:
    ///   • refreshAllCycles (called on every app open + foreground) skips
    ///     paused budgets entirely via `guard !budget.isPaused else { continue }`.
    ///   • No new cycles are created while paused.
    ///   • History is fully preserved — no cycles are deleted or altered.
    ///   • The last active cycle sits frozen in the database.
    ///   • The UI should show a "Paused" badge so the user isn't confused
    ///     by a stale cycle date (see BudgetDetailView changes).
    ///
    /// RESUME BEHAVIOUR:
    ///   • isPaused = false is set here.
    ///   • On the very next app open (or foreground return), refreshAllCycles
    ///     will call ensureActiveCycleExists, which calls handleMissedCycles.
    ///   • Any cycles missed during the pause are backfilled automatically.
    ///   • Today's cycle is created if it doesn't exist yet.
    ///   • Time feels invisible — the user never has to "restart" manually.
    ///
    /// WHY A STATIC METHOD (not direct property access):
    ///   Centralising the mutation here makes it easy to add side-effects
    ///   later (analytics, audit log, etc.) without touching any view.
    ///
    /// - Parameters:
    ///   - paused: true to pause, false to resume.
    ///   - budget: the budget to update.
    static func setPaused(_ paused: Bool, for budget: Budget) {
        guard budget.isPaused != paused else { return }   // no-op if already in that state
        budget.isPaused = paused

        if paused {
            print(
                "[CycleEngine] \"\(budget.name)\": PAUSED — " +
                "cycles will not advance until resumed."
            )
        } else {
            print(
                "[CycleEngine] \"\(budget.name)\": RESUMED — " +
                "missed cycles will be backfilled on next app open."
            )
        }
    }
}
