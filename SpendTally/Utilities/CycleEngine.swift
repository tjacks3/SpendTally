// ============================================================
// FILE:   CycleEngine.swift
// ADD TO: SpendTally/Utilities/CycleEngine.swift
//
// ACTION: NEW FILE
//   1. Right-click the "Utilities" folder in the Xcode
//      Project Navigator
//   2. New File from Template → Swift File
//   3. Name it "CycleEngine"
//   4. Paste this entire file, replacing the generated stub
//
// AFTER ADDING THIS FILE — update two call sites:
//
//   BudgetViewModel.swift  line ~34:
//     OLD: CycleManager.getOrCreateCurrentCycle(for: budget, context: context)
//     NEW: CycleEngine.ensureActiveCycleExists(for: budget, context: context)
//
//   BudgetDetailView.swift  (in the .sheet body for AddExpenseView):
//     OLD: CycleManager.getOrCreateCurrentCycle(for: budget, context: modelContext)
//     NEW: CycleEngine.ensureActiveCycleExists(for: budget, context: modelContext)
//
// CycleManager.swift stays — CycleEngine calls it for date math.
// ============================================================

import Foundation
import SwiftData

// MARK: - CycleEngine

/// Manages the full lifecycle of budget cycles.
///
/// CycleEngine answers one question: "what cycle should the user see right now?"
/// It always ensures the answer is correct, even if the user hasn't opened the
/// app in weeks, and does all of that work silently without any UI involvement.
///
/// ┌──────────────────────────────────────────────────────────┐
/// │  View / ViewModel                                        │
/// │       │                                                  │
/// │       ▼                                                  │
/// │  CycleEngine   ← lifecycle (this file)                  │
/// │       │                                                  │
/// │       ▼                                                  │
/// │  CycleManager  ← date math (CycleManager.swift)         │
/// │       │                                                  │
/// │       ▼                                                  │
/// │  SwiftData (BudgetCycle, Budget)                        │
/// └──────────────────────────────────────────────────────────┘
///
/// CycleEngine is a struct with only static methods.
/// You never create an instance — just call CycleEngine.method().
struct CycleEngine {

    // =========================================================================
    // MARK: - 1. Get Current Cycle (pure read)
    // =========================================================================

    /// Returns the cycle whose date range contains today, or nil.
    ///
    /// This is a pure read — it never touches SwiftData.
    /// Use it when you only need to *check*, not *guarantee*, a cycle exists.
    ///
    /// For the common case (show the user their active cycle), call
    /// `ensureActiveCycleExists` instead — it creates one if needed.
    ///
    /// HOW IT WORKS:
    ///   Loops through budget.cycles and checks whether Date.now falls
    ///   inside [cycle.startDate … cycle.endDate]. The first match wins.
    ///
    ///   Budget.cycles is already loaded in memory by SwiftData when the
    ///   Budget object is fetched, so this loop is fast (no database query).
    static func getCurrentCycle(for budget: Budget) -> BudgetCycle? {
        let now = Date.now
        return budget.cycles.first { cycle in
            now.isBetween(cycle.startDate, and: cycle.endDate)
        }
    }

    // =========================================================================
    // MARK: - 2. Generate Next Cycle
    // =========================================================================

    /// Creates and persists the cycle that immediately follows `previousCycle`.
    ///
    /// HOW THE DATE MATH WORKS:
    ///   previousCycle ends at 23:59:59 on its last day.
    ///   Adding 1 second lands at 00:00:00 the next day — the clean start
    ///   of the new cycle. CycleManager then computes where that cycle ends
    ///   based on the budget's CycleType (daily / weekly / monthly / custom).
    ///
    ///   Example (weekly budget):
    ///     previousCycle.endDate   = "2026-03-21 23:59:59"
    ///     nextStart               = "2026-03-22 00:00:00"
    ///     nextEnd (7 days later)  = "2026-03-28 23:59:59"
    ///
    /// @discardableResult means the caller can ignore the return value.
    /// It's used that way in handleMissedCycles (we don't need each
    /// intermediate cycle, only the final one matters for the loop).
    @discardableResult
    static func generateNextCycle(
        for budget: Budget,
        after previousCycle: BudgetCycle,
        context: ModelContext
    ) -> BudgetCycle {

        // 1. The new cycle starts exactly one second after the previous one ends.
        let nextStart = previousCycle.endDate.addingTimeInterval(1)

        // 2. Delegate end-date calculation to CycleManager (owns all date math).
        let nextEnd = CycleManager.cycleEndDate(for: budget, startDate: nextStart)

        // 3. Create the cycle, wire up the relationship, and insert into SwiftData.
        let cycle        = BudgetCycle(budget: budget, startDate: nextStart, endDate: nextEnd)
        cycle.budget     = budget
        budget.cycles.append(cycle)
        context.insert(cycle)

        return cycle
    }

    // =========================================================================
    // MARK: - 3. Ensure Active Cycle Exists
    // =========================================================================

    /// The primary entry point for all Views and ViewModels.
    ///
    /// Guarantees that a cycle covering today exists in the database,
    /// creating one (and any missed intermediate cycles) if needed.
    ///
    /// Call this:
    ///   • When a BudgetDetailView appears
    ///   • When the user taps "Add Expense"
    ///   • When BudgetViewModel creates a new budget
    ///
    /// HOW IT WORKS (two paths):
    ///
    ///   FAST PATH (99% of opens): an active cycle already exists.
    ///     → Returns immediately. No writes to the database.
    ///
    ///   SLOW PATH (first open of a new period):
    ///     1. No active cycle found.
    ///     2. handleMissedCycles fills any gaps between the last known
    ///        cycle and today (silently, no UI involved).
    ///     3. Check again — gap-filling may have just created today's cycle.
    ///     4. If still nothing, create the very first cycle for this budget.
    @discardableResult
    static func ensureActiveCycleExists(
        for budget: Budget,
        context: ModelContext
    ) -> BudgetCycle {

        // ── Fast path ────────────────────────────────────────────────────────
        if let active = getCurrentCycle(for: budget) {
            return active
        }

        // ── Slow path ────────────────────────────────────────────────────────

        // Fill any cycles that should have been created while the app was closed.
        handleMissedCycles(for: budget, context: context)

        // Gap-filling may have already created today's cycle. Check again.
        if let active = getCurrentCycle(for: budget) {
            return active
        }

        // No previous cycles at all — create the very first one.
        return createFirstCycle(for: budget, context: context)
    }

    // =========================================================================
    // MARK: - 4. Handle Missed Cycles
    // =========================================================================

    /// Silently creates every cycle between the last recorded cycle and today.
    ///
    /// This is called automatically by ensureActiveCycleExists — you rarely
    /// need to call it directly.
    ///
    /// SCENARIO:
    ///   User has a weekly budget (resets every Sunday).
    ///   They last opened the app on March 1.
    ///   Today is March 22.
    ///
    ///   Missed cycles:
    ///     Mar  2 – Mar  8   (week 1)
    ///     Mar  9 – Mar 15   (week 2)
    ///     Mar 16 – Mar 22   (week 3 / current)
    ///
    ///   Before this function: only the Feb 23 – Mar 1 cycle exists.
    ///   After  this function: all three gaps are filled in SwiftData.
    ///   The last generated cycle covers today → getCurrentCycle succeeds.
    ///
    /// HOW THE LOOP WORKS:
    ///   We start from the most recently ended cycle and keep calling
    ///   generateNextCycle() until the newly created cycle's end date
    ///   is in the future (meaning it covers today).
    ///
    /// SAFETY CAP:
    ///   The loop is capped at 366 iterations to prevent an infinite loop
    ///   if the budget was created a very long time ago. 366 covers a full
    ///   year of daily cycles — more than enough for any practical use case.
    static func handleMissedCycles(for budget: Budget, context: ModelContext) {

        // Non-recurring budgets have exactly one cycle. Never backfill them.
        guard budget.isRecurring else { return }

        // Find the cycle with the most recent end date.
        // sorted(by:) returns a new array; .first is the most recent.
        guard let lastCycle = budget.cycles
            .sorted(by: { $0.endDate > $1.endDate })
            .first else {
            // No cycles exist yet — nothing to backfill.
            // createFirstCycle (called by ensureActiveCycleExists) handles this.
            return
        }

        let now = Date.now

        // If the last cycle hasn't ended yet, it's the current one. Nothing to do.
        guard lastCycle.endDate < now else { return }

        // ── Backfill loop ────────────────────────────────────────────────────
        let maxIterations = 366   // safety cap (see comment above)
        var generated     = 0
        var previous      = lastCycle

        // Keep generating until the newest cycle covers today, or we hit the cap.
        while previous.endDate < now && generated < maxIterations {
            previous  = generateNextCycle(for: budget, after: previous, context: context)
            generated += 1
        }

        // Log how many were created — useful during development.
        // Remove or #if DEBUG-guard this line before shipping if desired.
        if generated > 0 {
            print("[CycleEngine] \"\(budget.name)\": backfilled \(generated) missed cycle(s).")
        }

        if generated == maxIterations {
            // This means the budget was inactive for > 366 daily cycles (1+ year).
            // We've caught up enough — the next call to getCurrentCycle will find
            // the most recently generated cycle and can decide if it's active.
            print("[CycleEngine] Warning: hit backfill cap for \"\(budget.name)\". " +
                  "Consider archiving old budgets.")
        }
    }

    // =========================================================================
    // MARK: - Private Helpers
    // =========================================================================

    /// Creates the very first cycle for a budget, aligned to today's date.
    ///
    /// HOW IT WORKS:
    ///   CycleManager.cycleStartDate figures out where the current period
    ///   begins based on the CycleType (e.g. for monthly, it returns the
    ///   1st of the current month; for weekly, the most recent cycle-start
    ///   weekday relative to budget.startDate).
    @discardableResult
    private static func createFirstCycle(
        for budget: Budget,
        context: ModelContext
    ) -> BudgetCycle {

        let start = CycleManager.cycleStartDate(for: budget, containing: .now)
        let end   = CycleManager.cycleEndDate(for: budget, startDate: start)

        let cycle        = BudgetCycle(budget: budget, startDate: start, endDate: end)
        cycle.budget     = budget
        budget.cycles.append(cycle)
        context.insert(cycle)

        print("[CycleEngine] \"\(budget.name)\": created first cycle " +
              "\(start.formatted(.dateTime.month().day())) – " +
              "\(end.formatted(.dateTime.month().day())).")

        return cycle
    }
}

// ============================================================
// MARK: - DEBUGGING GUIDE
// ============================================================
//
// Cycle boundaries — how to verify they're correct
// -------------------------------------------------
//
// Add a temporary debug print anywhere in BudgetDetailView or
// BudgetViewModel to inspect a cycle's boundaries:
//
//   let cycle = CycleEngine.ensureActiveCycleExists(for: budget, context: ctx)
//   let fmt   = DateFormatter()
//   fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
//   print("Cycle: \(fmt.string(from: cycle.startDate)) → \(fmt.string(from: cycle.endDate))")
//
// Expected output for a monthly budget opened March 21:
//   Cycle: 2026-03-01 00:00:00 → 2026-03-31 23:59:59
//
// Expected output for a weekly budget started on a Monday:
//   Cycle: 2026-03-16 00:00:00 → 2026-03-22 23:59:59
//
//
// Missed-cycle backfill — how to test it
// ---------------------------------------
//
// The easiest way to simulate a lapsed budget in the Simulator:
//
//   1. Create a daily budget today.
//   2. In Xcode, open the scheme editor (Product → Scheme → Edit Scheme).
//   3. Under Run → Arguments, add: -com.apple.CoreData.SQLDebug 1
//      (shows SwiftData activity in the console)
//   4. Change Date.now inside createFirstCycle to a date 5 days ago:
//        let start = Calendar.current.date(byAdding: .day,
//                                           value: -5, to: .now)!
//   5. Run the app. You should see "[CycleEngine] backfilled 5 missed cycle(s)."
//   6. Revert the change.
//
//
// Common mistake: cycle start/end 1 second off
// ---------------------------------------------
//
// generateNextCycle adds 1 second to previousCycle.endDate.
// endDate is always set to 23:59:59, so:
//   23:59:59 + 1 second = 00:00:00 next day ✓
//
// If you ever change endOfDay to use midnight (00:00:00 next day),
// remove the +1 second — otherwise cycles will start 1 second late.
// ============================================================
