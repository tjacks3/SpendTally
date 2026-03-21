// ============================================================
// FILE:   DateUtilities.swift
// ADD TO: SpendTally/Utilities/DateUtilities.swift
//
// ACTION: NEW FILE
//   1. Right-click the "Utilities" folder in the Xcode
//      Project Navigator
//   2. New File from Template → Swift File
//   3. Name it "DateUtilities"
//   4. Paste this entire file, replacing the generated stub
//
// PURPOSE:
//   Tiny Date extensions used by CycleEngine.
//   Keeps date gymnastics readable — no magic numbers inline.
// ============================================================

import Foundation

extension Date {

    // ── Day boundaries ───────────────────────────────────────────────────────

    /// 00:00:00 on this day in the device's current calendar.
    ///
    ///   Date.now.startOfDay  →  "2026-03-21 00:00:00"
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// 23:59:59 on this day in the device's current calendar.
    ///
    ///   Date.now.endOfDay  →  "2026-03-21 23:59:59"
    ///
    /// WHY 23:59:59 instead of midnight-of-next-day?
    ///   Using the last second of the day means "endDate < now"
    ///   is true as soon as the clock ticks past midnight, making
    ///   the expired-cycle check in CycleEngine simple and correct.
    var endOfDay: Date {
        var comps    = Calendar.current.dateComponents([.year, .month, .day], from: self)
        comps.hour   = 23
        comps.minute = 59
        comps.second = 59
        // Fallback to self if the calendar can't construct the date (extremely unlikely).
        return Calendar.current.date(from: comps) ?? self
    }

    // ── Range check ─────────────────────────────────────────────────────────

    /// Returns true if this date falls inside [start, end] (both ends inclusive).
    ///
    /// Usage:
    ///   Date.now.isBetween(cycle.startDate, and: cycle.endDate)
    func isBetween(_ start: Date, and end: Date) -> Bool {
        start <= self && self <= end
    }
}
