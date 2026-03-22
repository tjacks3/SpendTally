// ============================================================
// FILE:   DashboardView.swift
// ADD TO: SpendTally/Views/Budget/DashboardView.swift
//
// ACTION: NEW FILE
//   1. Right-click the "Budget" folder inside "Views" in
//      the Xcode Project Navigator
//   2. New File from Template → Swift File
//   3. Name it "DashboardView"
//   4. Paste this entire file, replacing the generated stub
//
// WIRING IT UP (BudgetListView.swift):
//   Replace the existing .navigationDestination block with:
//
//       .navigationDestination(for: Budget.self) { budget in
//           DashboardView(budget: budget)
//       }
//
//   DashboardView takes over as the primary destination when
//   the user taps a budget row. BudgetDetailView is still used
//   inside DashboardView for the expense list portion.
//
// CONTAINS:
//   • DashboardView          — main per-budget active-cycle view
//   • BudgetCycleDateHelpers — formatting utilities (range, days left)
//   • CycleStatus helpers    — nearLimit threshold + label/color
// ============================================================

import SwiftUI
import SwiftData

// MARK: - Cycle Status (Dashboard Layer)

/// A three-state status for dashboard display.
///
/// BudgetCycle.status (in the model layer) only distinguishes
/// onTrack / over / under. We add nearLimit here so the UI can
/// warn the user before they go over — without touching the model.
///
/// NEAR LIMIT THRESHOLD: 80 % of the budget has been spent.
/// Adjust `nearLimitThreshold` below to change the warning point.
private enum DashboardStatus {
    case onTrack
    case nearLimit   // 80 %+ spent but not yet over
    case overBudget

    /// The threshold at which "Near Limit" kicks in (0.0 – 1.0).
    static let nearLimitThreshold: Double = 0.80

    /// Derive the status from a cycle.
    init(cycle: BudgetCycle) {
        if cycle.isOver {
            self = .overBudget
        } else if cycle.progress >= DashboardStatus.nearLimitThreshold {
            self = .nearLimit
        } else {
            self = .onTrack
        }
    }

    var label: String {
        switch self {
        case .onTrack:    return "On Track"
        case .nearLimit:  return "Near Limit"
        case .overBudget: return "Over Budget"
        }
    }

    var icon: String {
        switch self {
        case .onTrack:    return "checkmark.circle.fill"
        case .nearLimit:  return "exclamationmark.triangle.fill"
        case .overBudget: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .onTrack:    return .green
        case .nearLimit:  return .orange
        case .overBudget: return .red
        }
    }
}

// MARK: - Date Helpers

/// Pure date-formatting utilities used by DashboardView.
///
/// All functions are static — no instance needed.
/// Kept in a dedicated type so they are easy to find and reuse.
enum BudgetCycleDateHelpers {

    // MARK: Cycle Range Label

    /// Formats a cycle's start/end as a human-readable range.
    ///
    /// SAME MONTH:   "Mar 11 – 17"
    /// CROSS MONTH:  "Mar 28 – Apr 3"
    /// SAME DAY:     "Mar 21"
    ///
    /// HOW IT WORKS:
    ///   We check whether both dates share the same month and year.
    ///   • If yes  → omit the month from the end date to avoid repetition.
    ///   • If no   → include the full month on both dates.
    ///   • If same → just the one date.
    static func cycleRange(from start: Date, to end: Date) -> String {
        let calendar = Calendar.current

        // Are both endpoints in the same calendar month/year?
        let sameMonth = calendar.isDate(start, equalTo: end, toGranularity: .month)

        // Are they literally the same day? (daily budget)
        if calendar.isDate(start, inSameDayAs: end) {
            return formatted(end, format: "MMM d")
        }

        let startStr = formatted(start, format: "MMM d")

        if sameMonth {
            // "Mar 11 – 17"  (omit month on end)
            let endStr = formatted(end, format: "d")
            return "\(startStr) – \(endStr)"
        } else {
            // "Mar 28 – Apr 3"
            let endStr = formatted(end, format: "MMM d")
            return "\(startStr) – \(endStr)"
        }
    }

    // MARK: Days Remaining

    /// How many full calendar days are left until a cycle ends.
    ///
    /// HOW IT WORKS:
    ///   Calendar.dateComponents counts whole elapsed days between
    ///   the start of today and the end of the cycle. We clamp at 0
    ///   so an expired cycle never shows a negative count.
    ///
    ///   Example:
    ///     today (start of day) = Mar 21 00:00:00
    ///     cycle.endDate        = Mar 31 23:59:59
    ///     dateComponents .day  = 10
    ///     → "10 days"
    ///
    ///   On the final day:
    ///     today                = Mar 31 00:00:00
    ///     cycle.endDate        = Mar 31 23:59:59
    ///     dateComponents .day  = 0
    ///     → "Resets tomorrow" (handled by daysRemainingLabel below)
    static func daysRemaining(until endDate: Date) -> Int {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        let days = Calendar.current
            .dateComponents([.day], from: startOfToday, to: endDate)
            .day ?? 0
        return max(days, 0)
    }

    /// A friendly sentence for the "resets in X days" label.
    ///
    ///   0 days → "Resets tomorrow"   (last day of the cycle)
    ///   1 day  → "Resets in 1 day"
    ///   N days → "Resets in N days"
    static func daysRemainingLabel(until endDate: Date) -> String {
        let days = daysRemaining(until: endDate)
        switch days {
        case 0:  return "Resets tomorrow"
        case 1:  return "Resets in 1 day"
        default: return "Resets in \(days) days"
        }
    }

    // MARK: Private

    private static func formatted(_ date: Date, format: String) -> String {
        let df = DateFormatter()
        df.dateFormat = format
        return df.string(from: date)
    }
}

// MARK: - DashboardView

/// A focused, single-screen summary of the budget's CURRENT active cycle.
///
/// Design philosophy: "time should feel invisible."
/// The user sees what matters — name, cycle window, budget vs. spent,
/// remaining balance, status, and how many days are left — without
/// ever needing to configure anything manually.
///
/// NAVIGATION:
///   Presented as the navigation destination for a budget row in
///   BudgetListView. Receives a Budget and derives everything else
///   from budget.currentCycle.
struct DashboardView: View {

    // @Bindable allows two-way bindings to @Model properties if needed
    // by child views (e.g. EditExpenseView).
    @Bindable var budget: Budget

    @Environment(\.modelContext) private var modelContext

    // Sheet toggles
    @State private var showingAddExpense  = false
    @State private var showingExpenses    = false

    // MARK: - Derived State
    // All display values come from the active cycle.
    // We use `budget.currentCycle` (already on Budget) rather than
    // calling CycleEngine again — the cycle was created by
    // BudgetListView's .task hook before navigation arrived here.

    private var cycle: BudgetCycle? { budget.currentCycle }

    private var status: DashboardStatus {
        guard let cycle else { return .onTrack }
        return DashboardStatus(cycle: cycle)
    }

    private var cycleRangeLabel: String {
        guard let cycle else { return "—" }
        return BudgetCycleDateHelpers.cycleRange(from: cycle.startDate, to: cycle.endDate)
    }

    private var daysLabel: String {
        guard let cycle else { return "" }
        return BudgetCycleDateHelpers.daysRemainingLabel(until: cycle.endDate)
    }

    private var remainingAmount: Double {
        cycle?.remainingAmount ?? budget.totalAmount
    }

    private var spentAmount: Double {
        cycle?.totalSpent ?? 0
    }

    private var progress: Double {
        cycle?.progress ?? 0
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                cycleHeaderCard
                remainingCard
                metricsRow
                progressSection
                resetFooter
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(budget.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Ensure a cycle exists before presenting the sheet.
                    CycleEngine.ensureActiveCycleExists(for: budget, context: modelContext)
                    showingAddExpense = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Color.primary)
                        .foregroundStyle(Color(.systemBackground))
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(
                cycle: CycleEngine.ensureActiveCycleExists(
                    for: budget,
                    context: modelContext
                )
            )
        }
        // ADD inside DashboardView body, at the bottom of the VStack(spacing: 20) block,
        // after the existing resetFooter card:

        // ── Transactions row ──────────────────────────────────────────────────────────
        // NavigationLink works here because DashboardView is already inside the
        // NavigationStack created by ContentView. No sheet needed.
        NavigationLink {
            BudgetDetailView(budget: budget, showHero: false)
        } label: {
            HStack {
                Label("Transactions", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let count = cycle?.transactionCount, count > 0 {
                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)

        // ── History row ───────────────────────────────────────────────────────────────
        NavigationLink {
            BudgetHistoryView(budget: budget)
        } label: {
            HStack {
                Label("History", systemImage: "calendar.badge.clock")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    
    
    // MARK: - Cycle Header Card

    /// Shows the budget's cycle window and the "resets in X days" hint.
    private var cycleHeaderCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // e.g. "Mar 11 – Mar 31"
                Label(cycleRangeLabel, systemImage: "calendar")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                // e.g. "Resets in 10 days"
                Text(daysLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status badge — colour changes with DashboardStatus
            statusBadge
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        Label(status.label, systemImage: status.icon)
            .font(.caption.bold())
            .foregroundStyle(status.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(status.color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Remaining Card

    /// The visual centrepiece: the remaining balance displayed large.
    /// Negative numbers (over budget) are shown in red.
    private var remainingCard: some View {
        VStack(spacing: 6) {

            Text(budget.isCurrentlyOverBudget ? "Over Budget By" : "Remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Split the number into integer / decimal parts so we can
            // render them at different font sizes — a common finance-app trick
            // that makes the primary value immediately readable.
            let parts = splitAmount(abs(remainingAmount))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("$")
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .foregroundStyle(remainingColor)

                Text(parts.integer)
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundStyle(remainingColor)

                Text(".\(parts.decimal)")
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .foregroundStyle(remainingColor)
                    .baselineOffset(4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Remaining balance colour follows the status.
    private var remainingColor: Color {
        switch status {
        case .onTrack:    return .primary
        case .nearLimit:  return .orange
        case .overBudget: return .red
        }
    }

    // MARK: - Metrics Row

    /// Two side-by-side stat tiles: Budget limit and Spent so far.
    private var metricsRow: some View {
        HStack(spacing: 12) {
            metricTile(
                label: "Budget",
                amount: cycle?.totalAmount ?? budget.totalAmount,
                color: .secondary
            )
            metricTile(
                label: "Spent",
                amount: spentAmount,
                color: status == .overBudget ? .red : .orange
            )
        }
    }

    private func metricTile(label: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount, format: .currency(code: "USD"))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Progress Section

    /// A labelled progress bar showing how much of the budget has been consumed.
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header: "Spending Progress" + percentage
            HStack {
                Text("Spending Progress")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(progressTint)
            }

            // The bar itself
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(progressTint)
                        .frame(width: geo.size.width * progress, height: 12)
                        .animation(.easeOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 12)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var progressTint: Color {
        switch status {
        case .onTrack:    return .accentColor
        case .nearLimit:  return .orange
        case .overBudget: return .red
        }
    }

    // MARK: - Reset Footer

    /// A small, quiet note at the bottom reiterating when the cycle resets.
    private var resetFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(daysLabel)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Private Helpers

    /// Splits a Double into its integer and two-digit decimal components.
    ///
    ///   splitAmount(292.50) → (integer: "292", decimal: "50")
    ///   splitAmount(4.07)   → (integer: "4",   decimal: "07")
    ///
    /// WHY: Rendering "$292" in a large font and ".50" in a smaller font
    /// is a standard finance-app design pattern that aids quick scanning.
    private func splitAmount(_ value: Double) -> (integer: String, decimal: String) {
        let formatted = String(format: "%.2f", value)
        let parts     = formatted.split(separator: ".")
        return (
            integer: String(parts.first ?? "0"),
            decimal: parts.count > 1 ? String(parts[1]) : "00"
        )
    }
}

// MARK: - Preview

#Preview {
    do {
        let schema    = Schema([Budget.self, BudgetCycle.self, Expense.self])
        let config    = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx       = container.mainContext

        let budget = Budget(name: "Groceries", totalAmount: 200, cycleType: .monthly)
        ctx.insert(budget)

        let cycle = CycleEngine.ensureActiveCycleExists(for: budget, context: ctx)

        let samples: [(Double, String)] = [
            (42.00, "Whole Foods"),
            (18.50, "Trader Joe's"),
            (31.99, "Costco run"),
            (49.99, "Weekly shop"),
        ]
        for (amount, note) in samples {
            let e = Expense(amount: amount, note: note)
            e.budgetCycle = cycle
            cycle.expenses.append(e)
            ctx.insert(e)
        }

        return NavigationStack {
            DashboardView(budget: budget)
        }
        .modelContainer(container)
    } catch {
        return Text("Preview failed: \(error.localizedDescription)")
    }
}
