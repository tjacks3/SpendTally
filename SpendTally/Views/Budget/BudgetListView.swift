import SwiftUI
import SwiftData

struct BudgetListView: View {
    
    // @Query fetches all Budget records, sorted by name.
    @Query(sort: \Budget.startDate, order: .reverse)
    private var budgets: [Budget]
    
    @Environment(\.modelContext) private var modelContext
    
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
        // NavigationLink destinations are declared here at the stack level.
        // Any NavigationLink(value:) with a Budget will push BudgetDetailView.
        .navigationDestination(for: Budget.self) { budget in
            BudgetDetailView(budget: budget)
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateBudgetView()
        }
    }
    
    // MARK: - Subviews
    
    private var budgetList: some View {
        List {
            ForEach(budgets) { budget in
                // NavigationLink(value:) pushes to the destination declared
                // in .navigationDestination above. The Budget must be Hashable
                // (SwiftData @Model conforms to this automatically).
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
