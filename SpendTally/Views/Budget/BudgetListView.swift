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
    // Set to a budget when the user swipes-to-edit on a row.
    // Cleared automatically when the sheet dismisses (item: overload).
    @State private var budgetToEdit: Budget?

    // ── drives the delete confirmation dialog ────────────────────────────────
    // Set to a budget when the user taps the trailing "Delete" swipe action.
    // The actual deletion only happens after the user confirms the dialog.
    @State private var budgetToDelete: Budget?

    var body: some View {
        Group {
            if budgets.isEmpty {
                emptyState
            } else {
                budgetList
            }
        }
        .navigationTitle("SpendTally")
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
        // Fires whenever budgetToEdit becomes non-nil (swipe-to-edit).
        // Using `item:` instead of `isPresented:` means SwiftUI automatically
        // resets budgetToEdit to nil when the sheet is dismissed — no manual
        // cleanup needed.
        .sheet(item: $budgetToEdit) { budget in
            EditBudgetView(budget: budget)
        }

        // ── Delete confirmation sheet ────────────────────────────────────────
        // Shown when the user taps the trailing "Delete" swipe action.
        // The budget is only deleted if the user taps "Delete Budget" inside
        // the sheet. Dismissing the sheet clears budgetToDelete automatically.
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

    // CHANGED: replaced `.onDelete` on the ForEach with explicit per-row
    // `.swipeActions` blocks so we can attach two distinct actions:
    //
    //   Leading edge  (swipe right) → Edit   (blue pencil)
    //   Trailing edge (swipe left)  → Delete (red trash)
    //
    // `.allowsFullSwipe(false)` on the trailing block prevents the user from
    // accidentally deleting a budget by swiping all the way across.

    private var budgetList: some View {
        List {
            ForEach(budgets) { budget in
                NavigationLink(value: budget) {
                    BudgetRowView(budget: budget)
                }
                // ── Leading swipe: Edit ──────────────────────────────────────
                // A single blue "pencil" button that sets budgetToEdit,
                // which triggers the sheet above.
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        budgetToEdit = budget
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                // ── Trailing swipe: Delete ───────────────────────────────────
                // Sets budgetToDelete to trigger the confirmation dialog.
                // The budget is NOT deleted here — only after the user confirms.
                // `.allowsFullSwipe(false)` adds a safety net against accidental
                // deletes — the user must tap the button explicitly.
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // No role: .destructive here — that role causes SwiftUI to
                    // animate the row away immediately (before the action body
                    // runs), making it look like the delete happened before the
                    // confirmation sheet even opens. Plain button: action runs
                    // normally, sheet opens, deletion only happens on confirm.
                    Button {
                        budgetToDelete = budget
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
    }

    // MARK: - Empty State (unchanged)

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("No Budgets Yet")
                .font(.title2.bold())

            Text("Tap + to create your first budget.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Create Budget") {
                showingCreateSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
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
