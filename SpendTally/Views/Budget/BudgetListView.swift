import SwiftUI
import SwiftData

struct BudgetListView: View {

    @Query(sort: \Budget.startDate, order: .reverse)
    private var budgets: [Budget]

    @Environment(\.modelContext) private var modelContext

    // NEW: scenePhase tells us when the app moves between foreground/background.
    // .active  = user can see and use the app right now
    // .inactive = transitioning (e.g. mid-swipe to home screen)
    // .background = app is backgrounded
    @Environment(\.scenePhase) private var scenePhase

    @State private var vm = BudgetViewModel()
    @State private var showingCreateSheet = false

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
            BudgetDetailView(budget: budget)
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateBudgetView()
        }

        // ── Hook 1: First load ────────────────────────────────────────────────
        // .task runs once when the view appears, on a background thread
        // (Task gives it a cooperative thread automatically in Swift concurrency).
        // This catches the very first open of the app, and any time the view
        // is re-mounted (e.g. after full app kill and relaunch).
        //
        // NOTE: We use .task instead of .onAppear because .task is cancellable
        // and plays better with SwiftUI's lifecycle — if the view disappears
        // before the work completes, the task is cancelled automatically.
        .task {
            vm.refreshAllCycles(budgets: budgets, context: modelContext)
        }

        // ── Hook 2: Return from background ───────────────────────────────────
        // .onChange(of: scenePhase) fires every time the scene phase changes.
        // We only act when it transitions TO .active — that's the moment the
        // user brings the app back to the foreground after it was backgrounded.
        //
        // REAL-WORLD SCENARIO: User has a daily budget. They last opened the
        // app yesterday. Today they tap the icon — scenePhase becomes .active,
        // this fires, yesterday's expired cycle is detected, and today's cycle
        // is created before the UI finishes rendering. The user never sees
        // a stale "yesterday" cycle.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            vm.refreshAllCycles(budgets: budgets, context: modelContext)
        }
    }

    // MARK: - Subviews (unchanged)

    private var budgetList: some View {
        List {
            ForEach(budgets) { budget in
                NavigationLink(value: budget) {
                    BudgetRowView(budget: budget)
                }
            }
            .onDelete { offsets in
                vm.deleteBudgets(at: offsets, from: budgets, context: modelContext)
            }
        }
    }

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
