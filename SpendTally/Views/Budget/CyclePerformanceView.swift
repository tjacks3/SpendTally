// ============================================================
// FILE:   CyclePerformanceView.swift
// LOCATION: SpendTally/Views/Budget/CyclePerformanceView.swift
//
// ACTION: NEW FILE
//   1. Right-click the "Budget" folder inside "Views" in the
//      Xcode Project Navigator.
//   2. New File from Template → Swift File
//   3. Name it "CyclePerformanceView"
//   4. Paste this entire file, replacing the generated stub.
//
// USAGE (inside DashboardView or BudgetHistoryView):
//
//   CyclePerformanceView(budget: budget)
//
// PURPOSE:
//   A compact, horizontal row of coloured circle indicators —
//   one dot per recent budget cycle. Oldest cycle is on the left,
//   newest (or current) on the right.
//
//     🟢 = cycle ended under budget
//     🔴 = cycle ended over budget
//     🔵 = cycle is currently in progress (on track)
//     🟠 = cycle is currently in progress (near limit: ≥ 80 % spent)
//     🔴 = cycle is currently in progress AND already over budget
//
// DESIGN NOTES:
//   • No date logic lives here. All status information comes from
//     BudgetCycle's existing computed properties (status, isActive,
//     isOver, progress) — the same source of truth used everywhere else.
//   • Limited to the last MAX_CYCLES cycles (oldest extras are clipped).
//   • Each dot animates in with a subtle scale + opacity spring when
//     the view first appears.
//   • Tapping a dot shows a small tooltip label (date range + status).
// ============================================================

import SwiftUI
import SwiftData

// MARK: - Constants

private enum PerformanceConfig {
    /// Maximum number of dots to render.
    static let maxCycles  = 15

    /// Dot diameter in points.
    static let dotSize: CGFloat = 14

    /// Gap between dots.
    static let spacing: CGFloat = 6

    /// Progress threshold above which an active cycle is "near limit".
    static let nearLimitThreshold: Double = 0.80
}

// MARK: - Dot Status

/// The visual state of a single indicator dot.
///
/// This mirrors the logic in DashboardStatus (DashboardView.swift) but
/// is kept private to this file so the view layer stays self-contained.
///
/// MAPPING RULES:
///   Active + over budget     → .activeover    (red, pulsing)
///   Active + ≥ 80% spent     → .activeNear    (orange)
///   Active + < 80% spent     → .activeOnTrack (blue)
///   Ended + over budget      → .historicalOver  (red)
///   Ended + under budget     → .historicalUnder (green)
private enum DotStatus {
    case activeOnTrack
    case activeNear
    case activeOver
    case historicalUnder
    case historicalOver

    // ── Colour mapping ──────────────────────────────────────────────────
    // These are the ONLY place in the file where status → colour is
    // decided. Change here and the entire view updates.
    var color: Color {
        switch self {
        case .activeOnTrack:   return .blue
        case .activeNear:      return .orange
        case .activeOver:      return .red
        case .historicalUnder: return .green
        case .historicalOver:  return .red
        }
    }

    /// A short text label used in the tooltip.
    var label: String {
        switch self {
        case .activeOnTrack:   return "On Track"
        case .activeNear:      return "Near Limit"
        case .activeOver:      return "Over Budget"
        case .historicalUnder: return "Under Budget"
        case .historicalOver:  return "Over Budget"
        }
    }

    /// SF Symbol used in the tooltip.
    var icon: String {
        switch self {
        case .activeOnTrack:   return "circle.fill"
        case .activeNear:      return "exclamationmark.triangle.fill"
        case .activeOver:      return "xmark.circle.fill"
        case .historicalUnder: return "checkmark.circle.fill"
        case .historicalOver:  return "xmark.circle.fill"
        }
    }

    /// True only for the currently active cycle that is over budget —
    /// used to drive the pulse animation.
    var shouldPulse: Bool {
        self == .activeOver
    }

    // ── Factory ─────────────────────────────────────────────────────────

    /// Derive the dot status from a BudgetCycle.
    init(cycle: BudgetCycle) {
        if cycle.isActive {
            if cycle.isOver {
                self = .activeOver
            } else if cycle.progress >= PerformanceConfig.nearLimitThreshold {
                self = .activeNear
            } else {
                self = .activeOnTrack
            }
        } else {
            self = cycle.isOver ? .historicalOver : .historicalUnder
        }
    }
}

// MARK: - CyclePerformanceView

/// A horizontal strip of coloured dots — one per recent budget cycle.
///
/// Receives a `Budget` and derives everything from `budget.sortedCycles`,
/// which is already available in memory (no extra SwiftData fetch needed).
struct CyclePerformanceView: View {

    // @Model objects are reference types observed automatically by SwiftUI.
    let budget: Budget

    // MARK: - Derived Data

    /// The slice of cycles to render, oldest → newest (left → right).
    ///
    /// budget.sortedCycles is NEWEST-first, so we:
    ///   1. Take at most maxCycles from the front (the most recent ones).
    ///   2. Reverse so the row reads oldest-on-left, newest-on-right.
    private var displayCycles: [BudgetCycle] {
        Array(budget.sortedCycles
            .prefix(PerformanceConfig.maxCycles)
            .reversed()
        )
    }

    // MARK: - Animation State

    /// Controls the staggered entrance animation.
    /// Toggled to `true` in `.onAppear` to trigger the animation.
    @State private var appeared = false

    /// Index of the dot whose tooltip is currently visible.
    /// `nil` means no tooltip is shown.
    @State private var selectedIndex: Int? = nil

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // ── Section header ───────────────────────────────────────────
            Text("Cycle Performance")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if displayCycles.isEmpty {
                // Placeholder while the first cycle is still being created.
                Text("No cycles yet")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                // ── Dot row ──────────────────────────────────────────────
                dotsRow
            }

            // ── Legend ───────────────────────────────────────────────────
            legend
        }
        .onAppear {
            // Small delay so the animation fires after the view settles.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Dots Row

    private var dotsRow: some View {
        HStack(spacing: PerformanceConfig.spacing) {
            ForEach(Array(displayCycles.enumerated()), id: \.element.id) { index, cycle in
                let status = DotStatus(cycle: cycle)

                DotView(
                    status: status,
                    isSelected: selectedIndex == index,
                    appeared: appeared,
                    animationDelay: Double(index) * 0.04  // stagger: 40 ms per dot
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        // Tapping the same dot again dismisses the tooltip.
                        selectedIndex = selectedIndex == index ? nil : index
                    }
                }
                // Tooltip anchored above each dot.
                .overlay(alignment: .bottom) {
                    if selectedIndex == index {
                        TooltipView(cycle: cycle, status: status)
                            .offset(y: -PerformanceConfig.dotSize - 28)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                            .zIndex(1)
                    }
                }
            }
        }
        // Dismiss tooltip when the user taps outside the row.
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation { selectedIndex = nil }
        }
    }

    // MARK: - Legend

    /// Two-item key: green = under, red = over.
    private var legend: some View {
        HStack(spacing: 12) {
            LegendItem(color: .green, label: "Under budget")
            LegendItem(color: .red,   label: "Over budget")
        }
    }
}

// MARK: - DotView

/// A single coloured circle indicator.
///
/// Handles:
///   • Entrance animation (scale + opacity spring, staggered by `animationDelay`)
///   • Pulse animation for active-over-budget dots
///   • Selection ring when tapped
private struct DotView: View {

    let status: DotStatus
    let isSelected: Bool
    let appeared: Bool
    let animationDelay: Double

    // Drives the pulse loop for over-budget active cycles.
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(
                width:  PerformanceConfig.dotSize,
                height: PerformanceConfig.dotSize
            )
            // Selection ring: a slightly larger, semi-transparent circle behind.
            .background(
                Circle()
                    .fill(status.color.opacity(0.25))
                    .frame(
                        width:  PerformanceConfig.dotSize + 6,
                        height: PerformanceConfig.dotSize + 6
                    )
                    .opacity(isSelected ? 1 : 0)
            )
            // Entrance: scale from 0 → 1 with a spring, staggered per dot.
            .scaleEffect(appeared ? (isPulsing ? 1.25 : 1.0) : 0.01)
            .opacity(appeared ? 1.0 : 0.0)
            .animation(
                .spring(response: 0.4, dampingFraction: 0.65)
                    .delay(animationDelay),
                value: appeared
            )
            // Pulse loop: only fires for active + over-budget dots.
            .animation(
                status.shouldPulse
                    ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onAppear {
                if status.shouldPulse {
                    // Small delay so the entrance animation finishes first.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isPulsing = true
                    }
                }
            }
    }
}

// MARK: - TooltipView

/// A small floating label shown when the user taps a dot.
///
/// Displays:
///   • Cycle date range (e.g. "Mar 1 – Mar 31")
///   • Status icon + label (e.g. ✓ Under Budget)
private struct TooltipView: View {

    let cycle: BudgetCycle
    let status: DotStatus

    /// "Mar 1 – Mar 31" style string.
    private var dateRange: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return "\(df.string(from: cycle.startDate)) – \(df.string(from: cycle.endDate))"
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(dateRange)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Label(status.label, systemImage: status.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        )
        // Prevent tap-through to the row's gesture.
        .allowsHitTesting(false)
    }
}

// MARK: - LegendItem

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Cycle Performance") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Budget.self, BudgetCycle.self, Expense.self,
        configurations: config
    )

    let budget = Budget(name: "Groceries", totalAmount: 400)
    container.mainContext.insert(budget)

    let cal = Calendar.current

    // Seed 12 cycles so the dot row is well populated.
    // Spending is varied to produce a mix of green and red dots.
    let cycleData: [(month: Int, year: Int, spent: Double)] = [
        (month: 4,  year: 2025, spent: 380),  // under
        (month: 5,  year: 2025, spent: 420),  // over
        (month: 6,  year: 2025, spent: 310),  // under
        (month: 7,  year: 2025, spent: 450),  // over
        (month: 8,  year: 2025, spent: 290),  // under
        (month: 9,  year: 2025, spent: 405),  // over
        (month: 10, year: 2025, spent: 370),  // under
        (month: 11, year: 2025, spent: 410),  // over
        (month: 12, year: 2025, spent: 350),  // under
        (month: 1,  year: 2026, spent: 390),  // under
        (month: 2,  year: 2026, spent: 430),  // over
        (month: 3,  year: 2026, spent: 200),  // active / on track
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

        let expense = Expense(amount: item.spent, note: "Grocery run")
        expense.budgetCycle = cycle
        container.mainContext.insert(expense)
    }

    return VStack(alignment: .leading) {
        CyclePerformanceView(budget: budget)
            .padding()
    }
    .modelContainer(container)
}
