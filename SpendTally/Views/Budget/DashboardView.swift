// ============================================================
// FILE:   DashboardView.swift
// LOCATION: SpendTally/Views/Budget/DashboardView.swift
//
// ACTION: REPLACE EXISTING FILE — full replacement.
//
// WHAT CHANGED vs. the previous version:
//
//   ADDED — @State var showingEditBudget: Bool
//     Drives the EditBudgetView sheet, moved here from BudgetDetailView.
//
//   CHANGED — .toolbar block
//     New "…" (ellipsis.circle) ToolbarItem added alongside the existing
//     "+" button. Mirrors the exact same UI pattern used for edit expense
//     in BudgetDetailView (ellipsis.circle → sheet → EditBudgetView).
//
//   ADDED — .sheet(isPresented: $showingEditBudget)
//     Presents EditBudgetView for name / amount / pause edits.
//
// EVERYTHING ELSE IS UNCHANGED.
// ============================================================

import SwiftUI
import SwiftData

// MARK: - Cycle Status (Dashboard Layer)

private enum DashboardStatus {
    case onTrack
    case nearLimit
    case overBudget

    static let nearLimitThreshold: Double = 0.80

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

enum BudgetCycleDateHelpers {

    static func cycleRange(from start: Date, to end: Date) -> String {
        let s = formatted(start, format: "MMM d")
        let e = formatted(end,   format: "MMM d")
        return "\(s) – \(e)"
    }

    static func daysRemaining(until endDate: Date) -> Int {
        let days = Calendar.current
            .dateComponents([.day], from: .now, to: endDate)
            .day ?? 0
        return max(days, 0)
    }

    static func daysRemainingLabel(until endDate: Date) -> String {
        let days = daysRemaining(until: endDate)
        switch days {
        case 0:  return "Resets tomorrow"
        case 1:  return "Resets in 1 day"
        default: return "Resets in \(days) days"
        }
    }

    private static func formatted(_ date: Date, format: String) -> String {
        let df = DateFormatter()
        df.dateFormat = format
        return df.string(from: date)
    }
}

// MARK: - DashboardView

struct DashboardView: View {

    @Bindable var budget: Budget

    @Environment(\.modelContext) private var modelContext

    // ── Sheet toggles ─────────────────────────────────────────────────────────
    @State private var showingAddExpense  = false
    @State private var showingExpenses    = false
    // MOVED HERE from BudgetDetailView — drives the edit budget sheet.
    @State private var showingEditBudget  = false

    // MARK: - Derived State

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

                // ── Transactions row ─────────────────────────────────────────
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

                // ── History row ──────────────────────────────────────────────
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
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(budget.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // ── Add expense button ───────────────────────────────────────────
            ToolbarItem(placement: .primaryAction) {
                Button {
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

            // ── Edit budget button ───────────────────────────────────────────
            // MOVED HERE from BudgetDetailView.
            // Same ellipsis.circle pattern used for edit expense in
            // BudgetDetailView — consistent UI across the app.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditBudget = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }

        // ── Add expense sheet ────────────────────────────────────────────────
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(
                cycle: CycleEngine.ensureActiveCycleExists(
                    for: budget,
                    context: modelContext
                )
            )
        }

        // ── Edit budget sheet ────────────────────────────────────────────────
        // MOVED HERE from BudgetDetailView.
        // Name, amount (with mid-cycle scope alert), and pause toggle.
        .sheet(isPresented: $showingEditBudget) {
            EditBudgetView(budget: budget)
        }
    }

    // MARK: - Cycle Header Card

    private var cycleHeaderCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label(cycleRangeLabel, systemImage: "calendar")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(daysLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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

    private var remainingCard: some View {
        VStack(spacing: 6) {
            Text(budget.isCurrentlyOverBudget ? "Over Budget By" : "Remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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

    private var remainingColor: Color {
        switch status {
        case .onTrack:    return .primary
        case .nearLimit:  return .orange
        case .overBudget: return .red
        }
    }

    // MARK: - Metrics Row

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

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spending Progress")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(progressTint)
            }

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

    private func splitAmount(_ value: Double) -> (integer: String, decimal: String) {
        let formatted = String(format: "%.2f", value)
        let parts     = formatted.split(separator: ".")
        return (
            integer: String(parts.first ?? "0"),
            decimal: parts.count > 1 ? String(parts[1]) : "00"
        )
    }
}
