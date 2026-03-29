// ============================================================
// FILE:   BudgetListView.swift
// LOCATION: SpendTally/Views/Budget/BudgetListView.swift
//
// ACTION: REPLACE EXISTING FILE — full replacement.
//
// WHAT CHANGED vs. the previous version:
//
//   REMOVED — .navigationTitle("SpendTally")
//     The navigation bar title has been removed entirely.
//     The home tab's navigation chrome stays minimal and uncluttered.
//
//   REPLACED — List { ForEach { NavigationLink { BudgetRowView } } }
//     The inner row view is now BudgetCardView, which renders a
//     typography-first card with a subtle gradient and no progress bar.
//     The List remains (preserving swipe-to-edit and swipe-to-delete),
//     but rows are styled as floating cards via listRowBackground,
//     listRowSeparator, and listRowInsets modifiers.
//
// EVERYTHING ELSE IS UNCHANGED:
//   • Swipe-to-edit (leading) and swipe-to-delete (trailing) are intact.
//   • NavigationLink(value:) → DashboardView push is intact.
//   • refreshAllCycles hooks (.task + .onChange scenePhase) are intact.
//   • CreateBudgetView, EditBudgetView, DeleteBudgetSheet sheets intact.
//   • Empty state view is unchanged.
// ============================================================

import SwiftUI
import SwiftData

struct BudgetListView: View {

    @Query(sort: \Budget.startDate, order: .reverse)
    private var budgets: [Budget]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase)   private var scenePhase

    @State private var vm = BudgetViewModel()
    @State private var showingCreateSheet = false

    // ── drives the edit sheet ────────────────────────────────────────────────
    @State private var budgetToEdit: Budget?

    // ── drives the delete confirmation dialog ────────────────────────────────
    @State private var budgetToDelete: Budget?

    var body: some View {
        Group {
            if budgets.isEmpty {
                emptyState
            } else {
                budgetList
            }
        }
        // Title removed — no .navigationTitle here
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Budget", systemImage: "plus") {
                    showingCreateSheet = true
                }
            }
        }
        .navigationDestination(for: Budget.self) { budget in
            DashboardView(budget: budget)
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateBudgetView()
        }

        // ── Edit budget sheet ────────────────────────────────────────────────
        .sheet(item: $budgetToEdit) { budget in
            EditBudgetView(budget: budget)
        }

        // ── Delete confirmation sheet ────────────────────────────────────────
        .sheet(item: $budgetToDelete) { budget in
            DeleteBudgetSheet(budget: budget) {
                if let index = budgets.firstIndex(where: { $0.id == budget.id }) {
                    vm.deleteBudgets(
                        at: IndexSet(integer: index),
                        from: budgets,
                        context: modelContext
                    )
                }
                // budgetToDelete is intentionally NOT cleared here.
                // DeleteBudgetSheet calls its own dismiss() after onDelete(),
                // and .sheet(item:) automatically sets the binding to nil
                // when the sheet fully dismisses — no manual clear needed.
            }
        }

        // ── Hook 1: First load ───────────────────────────────────────────────
        .task {
            vm.refreshAllCycles(budgets: budgets, context: modelContext)
        }

        // ── Hook 2: Return from background ───────────────────────────────────
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            vm.refreshAllCycles(budgets: budgets, context: modelContext)
        }
    }

    // MARK: - Budget List

    private var budgetList: some View {
        List {
            ForEach(budgets) { budget in
                // ── Invisible NavigationLink trick ───────────────────────────
                // Wrapping in a ZStack prevents List from detecting a direct
                // NavigationLink child, which is what adds the chevron arrow.
                // The NavigationLink is hidden behind the card and still
                // handles tap-to-navigate correctly via NavigationLink(value:).
                ZStack {
                    NavigationLink(value: budget) { EmptyView() }
                        .opacity(0)
                    BudgetCardView(budget: budget)
                }
                // ── Remove default List row chrome ───────────────────────────
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                // ── Leading swipe: Edit ──────────────────────────────────────
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        budgetToEdit = budget
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }

                // ── Trailing swipe: Delete ───────────────────────────────────
                // No role: .destructive — that would animate the row away
                // immediately, before the confirmation sheet opens.
                // Plain button + .tint(.red) gives the red colour without
                // the premature disappear animation.
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        budgetToDelete = budget
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text("No budgets yet")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Tap + to create your first budget")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Delete Budget Sheet

/// Confirmation sheet shown when the user swipes to delete a budget.
/// Presents the budget name, a plain-language warning, and two actions:
///   "Delete Budget" (destructive) — calls onDelete() then self-dismisses.
///   "Dismiss"                     — closes the sheet without deleting.
private struct DeleteBudgetSheet: View {

    let budget: Budget
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {

                // ── Icon + name ──────────────────────────────────────────────
                HStack(spacing: 14) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(budget.name)
                            .font(.title3.bold())
                        Text("Budget")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // ── Warning body ─────────────────────────────────────────────
                (
                    Text("Deleting ") +
                    Text(budget.name).bold() +
                    Text(" will permanently remove this budget and ") +
                    Text("all of its expense history").bold() +
                    Text(". Active cycles, past cycles, and every recorded expense will be gone. ") +
                    Text("This action cannot be undone.").bold()
                )
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // ── Actions ──────────────────────────────────────────────────
                VStack(spacing: 12) {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Text("Delete Budget")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Dismiss")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(24)
            .navigationTitle("Delete Budget")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    let config    = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Budget.self, BudgetCycle.self, Expense.self,
        configurations: config
    )

    let cal = Calendar.current

    // Budget 1: monthly, under budget
    let groceries = Budget(name: "Groceries", totalAmount: 1500, cycleType: .monthly)
    container.mainContext.insert(groceries)

    let gStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
    let gEnd   = cal.date(from: DateComponents(year: 2026, month: 3, day: 31,
                                               hour: 23, minute: 59, second: 59))!
    let gCycle = BudgetCycle(budget: groceries, startDate: gStart, endDate: gEnd)
    container.mainContext.insert(gCycle)

    let e1 = Expense(amount: 40, note: "Trader Joe's")
    e1.budgetCycle = gCycle
    container.mainContext.insert(e1)

    // Budget 2: weekly, over budget
    let dining = Budget(name: "Dining Out", totalAmount: 200, cycleType: .weekly)
    container.mainContext.insert(dining)

    let dStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 22))!
    let dEnd   = cal.date(from: DateComponents(year: 2026, month: 3, day: 28,
                                               hour: 23, minute: 59, second: 59))!
    let dCycle = BudgetCycle(budget: dining, startDate: dStart, endDate: dEnd)
    container.mainContext.insert(dCycle)

    let e2 = Expense(amount: 260, note: "Restaurant")
    e2.budgetCycle = dCycle
    container.mainContext.insert(e2)

    // Budget 3: daily, no activity
    let coffee = Budget(name: "Coffee", totalAmount: 10, cycleType: .daily)
    container.mainContext.insert(coffee)

    return NavigationStack {
        BudgetListView()
    }
    .modelContainer(container)
}
