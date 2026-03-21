import SwiftUI
import SwiftData

struct CreateBudgetView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

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
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $vm.newBudgetAmount)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Reset Frequency") {
                    // Show all four cycle types as a grid of cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                              spacing: 10) {
                        ForEach(CycleType.allCases) { type in
                            CycleTypeCard(
                                cycleType: type,
                                isSelected: vm.newBudgetCycleType == type
                            ) {
                                vm.newBudgetCycleType = type
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))

                    // Only show custom days field when .custom is selected
                    if vm.newBudgetCycleType == .custom {
                        HStack {
                            TextField("14", text: $vm.newBudgetCustomDays)
                                .keyboardType(.numberPad)
                            Text("days per cycle")
                                .foregroundStyle(.secondary)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: vm.newBudgetCycleType)

                Section {
                    // Preview: show when the cycle will reset
                    if vm.isFormValid {
                        Label(nextResetDescription, systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

    /// A human-readable preview of when the cycle resets.
    private var nextResetDescription: String {
        let budget = Budget(
            name: "preview",
            totalAmount: 1,
            cycleType: vm.newBudgetCycleType,
            cycleLengthInDays: Int(vm.newBudgetCustomDays) ?? 14
        )
        let start  = CycleManager.cycleStartDate(for: budget, containing: .now)
        let end    = CycleManager.cycleEndDate(for: budget, startDate: start)
        let df     = DateFormatter()
        df.dateStyle = .medium
        return "Resets after \(df.string(from: end))"
    }
}

// MARK: - Cycle Type Selection Card

private struct CycleTypeCard: View {

    let cycleType: CycleType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: cycleType.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .accentColor)
                Text(cycleType.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
