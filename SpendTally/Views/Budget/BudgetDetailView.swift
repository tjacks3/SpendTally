import SwiftUI
import SwiftData

struct BudgetDetailView: View {

    @Bindable var budget: Budget
    /// When true (default), shows the balance/stats hero at the top.
    /// Set to false when presenting from DashboardView to avoid repeating the cycle summary.
    var showHero: Bool = true

    @Environment(\.modelContext) private var modelContext

    // ── Sheet triggers ───────────────────────────────────────────────────────
    @State private var showingAddExpense  = false
    // showingEditBudget REMOVED — moved to DashboardView

    @State private var selectedExpense:   Expense?
    @State private var showingEditExpense = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if showHero { heroSection }
                expenseSection
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(budget.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // ── Add expense button ───────────────────────────────────────────
            // Disabled while paused — a paused budget has no active cycle,
            // so there is nowhere to attach the new expense.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddExpense = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Color.primary)
                        .foregroundStyle(Color(.systemBackground))
                        .clipShape(Circle())
                }
                .disabled(budget.isPaused)
            }
            // ellipsis.circle ToolbarItem REMOVED — moved to DashboardView
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

        // ── Edit expense sheet ───────────────────────────────────────────────
        .sheet(isPresented: $showingEditExpense) {
            if let expense = selectedExpense {
                EditExpenseView(expense: expense)
            }
        }
        .onChange(of: showingEditExpense) { _, isShowing in
            if !isShowing { selectedExpense = nil }
        }

        // Edit budget sheet REMOVED — moved to DashboardView
    }

    // MARK: - Paused Banner

    @ViewBuilder
    private var pausedBanner: some View {
        if budget.isPaused {
            HStack(spacing: 8) {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.orange)
                Text("This budget is paused.")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button("Resume") {
                    CycleEngine.setPaused(false, for: budget)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.orange.opacity(0.12))
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        let cycle = budget.currentCycle

        return VStack(spacing: 0) {
            pausedBanner

            VStack(spacing: 6) {
                Text(budget.isCurrentlyOverBudget ? "Over Budget" : "Remaining \(budget.periodLabel)")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("$")
                        .font(.system(size: 38, weight: .light, design: .rounded))
                        .foregroundStyle(budget.isCurrentlyOverBudget ? .red : .primary)

                    Text(balanceParts(for: cycle).integer)
                        .font(.system(size: 76, weight: .thin, design: .rounded))
                        .foregroundStyle(budget.isCurrentlyOverBudget ? .red : .primary)

                    Text(".\(balanceParts(for: cycle).decimal)")
                        .font(.system(size: 38, weight: .light, design: .rounded))
                        .foregroundStyle(budget.isCurrentlyOverBudget ? .red : .primary)
                        .baselineOffset(4)
                }

                HStack(spacing: 24) {
                    miniStat(label: "Budget",
                             value: cycle?.totalAmount ?? budget.totalAmount,
                             color: .secondary)
                    miniStat(label: "Spent",
                             value: cycle?.totalSpent ?? 0,
                             color: .orange)
                }
                .padding(.top, 4)

                ProgressView(value: cycle?.progress ?? 0)
                    .tint(budget.isCurrentlyOverBudget ? .red : .accentColor)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)

                if budget.isCurrentlyOverBudget, let cycle {
                    Text("Over by \(abs(cycle.remainingAmount), format: .currency(code: "USD"))")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                        .padding(.top, 2)
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Balance String Parts

    private func balanceParts(for cycle: BudgetCycle?) -> (integer: String, decimal: String) {
        let value     = abs(cycle?.remainingAmount ?? budget.totalAmount)
        let formatted = String(format: "%.2f", value)
        let parts     = formatted.split(separator: ".")
        return (String(parts[0]), parts.count > 1 ? String(parts[1]) : "00")
    }

    private func miniStat(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value, format: .currency(code: "USD"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Expense Section

    private var expenseSection: some View {
        let expenses = budget.currentCycle?.expenses ?? []

        return LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            if expenses.isEmpty {
                emptyState
            } else {
                ForEach(groupedExpenses(from: expenses), id: \.label) { group in
                    Section {
                        ForEach(Array(group.expenses.enumerated()),
                                id: \.element.id) { index, expense in

                            Button {
                                selectedExpense    = expense
                                showingEditExpense = true
                            } label: {
                                HStack(spacing: 0) {
                                    ExpenseRowView(expense: expense)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(.tertiaryLabel))
                                        .padding(.trailing, 20)
                                }
                                .background(Color(.systemBackground))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < group.expenses.count - 1 {
                                Divider()
                                    .padding(.leading, 76)
                                    .background(Color(.systemBackground))
                            }
                        }
                        .onDelete { offsets in
                            deleteExpenses(at: offsets, from: group.expenses)
                        }
                    } header: {
                        sectionHeader(label: group.label, total: group.total)
                    }
                }
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 4)
            Text("No expenses yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Tap + to record your first expense")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .background(Color(.systemBackground))
    }

    // MARK: - Section Header

    private func sectionHeader(label: String, total: Double) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(total, format: .currency(code: "USD"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Date Grouping

    private struct ExpenseGroup {
        let label:    String
        let expenses: [Expense]
        var total:    Double { expenses.reduce(0) { $0 + $1.amount } }
    }

    private func groupedExpenses(from expenses: [Expense]) -> [ExpenseGroup] {
        let sorted   = expenses.sorted { $0.date > $1.date }
        let calendar = Calendar.current
        var groupMap: [String: [Expense]] = [:]
        var order:    [String] = []

        for expense in sorted {
            let key: String
            if calendar.isDateInToday(expense.date) {
                key = "Today"
            } else if calendar.isDateInYesterday(expense.date) {
                key = "Yesterday"
            } else {
                let df        = DateFormatter()
                df.dateFormat = "MMMM d"
                key           = df.string(from: expense.date)
            }

            if groupMap[key] == nil {
                groupMap[key] = []
                order.append(key)
            }
            groupMap[key]!.append(expense)
        }

        return order.map { ExpenseGroup(label: $0, expenses: groupMap[$0]!) }
    }

    // MARK: - Delete

    private func deleteExpenses(at offsets: IndexSet, from expenses: [Expense]) {
        for index in offsets {
            if let expense = expenses[safe: index] {
                budget.currentCycle?.expenses.removeAll { $0.id == expense.id }
            }
        }
    }
}

// MARK: - Safe Subscript Helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
