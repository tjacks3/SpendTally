// ============================================================
// FILE:   BudgetDetailView.swift
// LOCATION: SpendTally/Views/Budget/BudgetDetailView.swift
//
// FIXES IN THIS VERSION:
//   1. @Bindable var budget: Budget — restored explicitly.
//      The two "Referencing subscript requires wrapper Bindable<Budget>"
//      errors occur when this annotation is missing. Any use of
//      $budget inside the view body (e.g. $budget.name in a TextField,
//      or passing budget as a Bindable argument) requires it.
//
//   2. Replaced .sheet(item: $selectedExpense) with the
//      isPresented + separate Bool pattern.
//      The two "Property 'id' requires Binding<Subject>.Element be a
//      class type" errors come from a SwiftUI/Swift version mismatch
//      where the compiler can't verify Expense is Identifiable inside
//      the sheet(item:) overload. Using showingEditExpense: Bool +
//      selectedExpense: Expense? sidesteps the issue entirely.
//
//   3. Removed the "if let cycle = ... { return ... }" pattern inside
//      the AddExpense sheet closure.
//      ViewBuilder does not allow explicit 'return' statements.
//      CycleManager.getOrCreateCurrentCycle is also non-optional, so
//      'if let' would not compile regardless. Fixed by inlining the
//      call directly as an argument.
// ============================================================

import SwiftUI
import SwiftData

struct BudgetDetailView: View {

    // FIX 1: @Bindable is required whenever you use $budget.property
    // or pass budget to a child that declares @Bindable.
    // Without it the compiler produces "Referencing subscript
    // 'subscript(dynamicMember:)' requires wrapper 'Bindable<Budget>'".
    @Bindable var budget: Budget

    @Environment(\.modelContext) private var modelContext

    // ── Sheet triggers ───────────────────────────────────────────────────────
    @State private var showingAddExpense  = false

    // FIX 2a: Keep the selected expense as plain @State (not a Binding
    // passed to sheet(item:)).
    @State private var selectedExpense:   Expense?

    // FIX 2b: Drive the edit sheet with a separate Bool so we use
    // .sheet(isPresented:) instead of .sheet(item:).
    // This avoids the "Property 'id' requires class type" compiler error
    // that appears when SwiftUI can't resolve Expense: Identifiable
    // through the Binding<Expense?> overload.
    @State private var showingEditExpense = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                expenseSection
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(budget.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
            }
        }

        // ── Add expense sheet ────────────────────────────────────────────────
        // FIX 3: CycleManager.getOrCreateCurrentCycle returns a non-optional
        // BudgetCycle, so 'if let' won't compile and explicit 'return' is
        // not allowed in ViewBuilder. Pass the result directly as an argument.
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(
                cycle: CycleManager.getOrCreateCurrentCycle(
                    for: budget,
                    context: modelContext
                )
            )
        }

        // ── Edit expense sheet ───────────────────────────────────────────────
        // FIX 2c: .sheet(isPresented:) + unwrapping selectedExpense inside
        // the closure. This is equivalent to .sheet(item:) but avoids the
        // Identifiable/Binding compiler bug.
        //
        // When the sheet dismisses, SwiftUI sets showingEditExpense = false.
        // We then nil out selectedExpense in the .onChange below so the
        // reference doesn't linger.
        .sheet(isPresented: $showingEditExpense) {
            // selectedExpense is guaranteed non-nil here because we set it
            // to a real expense before setting showingEditExpense = true.
            if let expense = selectedExpense {
                EditExpenseView(expense: expense)
            }
        }
        // Clean up selectedExpense after the sheet closes.
        .onChange(of: showingEditExpense) { _, isShowing in
            if !isShowing { selectedExpense = nil }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        // Use the current cycle for all spending numbers.
        let cycle = budget.currentCycle

        return VStack(spacing: 6) {
            Text(budget.isCurrentlyOverBudget ? "Over Budget" : "Remaining \(budget.periodLabel)")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)

            // Large split number: $292.50 rendered as "$" + "292" + ".50"
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
        // Pull expenses from the active cycle, not the budget directly.
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
                                // FIX 2d: Set the target, THEN flip the Bool.
                                // The Bool change triggers .sheet(isPresented:).
                                // Reversing the order could show an empty sheet
                                // if SwiftUI reacts before selectedExpense is set.
                                selectedExpense   = expense
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
                // Remove from the cycle's expense list
                budget.currentCycle?.expenses.removeAll { $0.id == expense.id }
            }
        }
    }
}

// MARK: - Safe Subscript Helper

// Prevents index-out-of-range crashes in deleteExpenses.
private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    do {
        let schema = Schema([Budget.self, BudgetCycle.self, Expense.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext

        let budget = Budget(name: "Groceries", totalAmount: 500, cycleType: .monthly)
        ctx.insert(budget)

        let cycle = CycleManager.getOrCreateCurrentCycle(for: budget, context: ctx)

        let samples: [(Double, String, Int)] = [
            (24.99, "Whole Foods run",      0),
            (4.75,  "Coffee",               0),
            (3.35,  "Pet treats",           0),
            (39.75, "Jeff's birthday gift", -1),
            (12.50, "Lunch",               -1),
            (89.00, "Weekly shop",         -3),
        ]
        for (amount, note, daysAgo) in samples {
            let date = Calendar.current.date(byAdding: .day, value: daysAgo, to: .now)!
            let e = Expense(amount: amount, note: note, date: date)
            e.budgetCycle = cycle
            cycle.expenses.append(e)
            ctx.insert(e)
        }

        return NavigationStack {
            BudgetDetailView(budget: budget)
        }
        .modelContainer(container)
    } catch {
        return Text("Preview failed: \(error.localizedDescription)")
    }
}
