import SwiftUI
import SwiftData

struct CreateBudgetView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // @State creates a ViewModel that lives as long as this view.
    @State private var vm = BudgetViewModel()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Budget Name") {
                    TextField("e.g. Groceries, Travel...", text: $vm.newBudgetName)
                        .autocorrectionDisabled()
                }
                
                Section("Amount") {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $vm.newBudgetAmount)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section("Period") {
                    Picker("Period", selection: $vm.newBudgetPeriod) {
                        ForEach(vm.periods, id: \.self) { period in
                            Text(period.capitalized).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.createBudget(context: modelContext)
                        dismiss()
                    }
                    .disabled(!vm.isFormValid)
                }
            }
        }
    }
}
