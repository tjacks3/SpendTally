// ============================================================
// FILE:   BudgetListView.swift
// LOCATION: SpendTally/Views/Budget/BudgetListView.swift
//
// ACTION: REPLACE EXISTING FILE — full replacement.
//
// WHAT CHANGED vs. the previous version:
//
//   ADDED — @State var budgetToEdit: Budget?
//     Optional reference to whichever budget the user long-pressed
//     or swiped-to-edit. When non-nil the sheet fires automatically.
//     Cleared back to nil when the sheet dismisses.
//
//   CHANGED — budgetList computed property
//     • Replaced bare `.onDelete` on the ForEach with per-row explicit
//       `.swipeActions` so we can have two distinct swipe directions:
//         – Leading (left→right) blue pencil  → opens EditBudgetView
//         – Trailing (right→left) red trash   → deletes (same logic)
//     • The NavigationLink is unchanged in every other respect.
//
//   ADDED — .sheet(item: $budgetToEdit)
//     Presents EditBudgetView for the selected budget.
//     Uses the `item:` overload so the sheet is automatically dismissed
//     and budgetToEdit is automatically cleared when the view disappears.
//
// EVERYTHING ELSE IS UNCHANGED.
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

    // ── NEW: drives the edit sheet ───────────────────────────────────────────
    // Set to a budget when the user swipes-to-edit on a row.
    // Cleared automatically when the sheet dismisses (item: overload).
    @State private var budgetToEdit: Budget?

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

        // ── NEW: Edit budget sheet ───────────────────────────────────────────
        // Fires whenever budgetToEdit becomes non-nil (swipe-to-edit).
        // Using `item:` instead of `isPresented:` means SwiftUI automatically
        // resets budgetToEdit to nil when the sheet is dismissed — no manual
        // cleanup needed.
        .sheet(item: $budgetToEdit) { budget in
            EditBudgetView(budget: budget)
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
                // Mirrors the old `.onDelete` behavior exactly.
                // `.allowsFullSwipe(false)` adds a small safety net against
                // accidental deletes — the user must tap the button explicitly.
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        if let index = budgets.firstIndex(where: { $0.id == budget.id }) {
                            vm.deleteBudgets(
                                at: IndexSet(integer: index),
                                from: budgets,
                                context: modelContext
                            )
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
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
