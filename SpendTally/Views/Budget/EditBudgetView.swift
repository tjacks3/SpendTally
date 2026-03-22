// ============================================================
// FILE:   EditBudgetView.swift
// LOCATION: SpendTally/Views/Budget/EditBudgetView.swift
//
// ACTION: NEW FILE
//   1. Right-click the "Budget" folder inside "Views" in the
//      Xcode Project Navigator.
//   2. New File from Template → Swift File
//   3. Name it "EditBudgetView"
//   4. Paste this entire file, replacing the generated stub.
//
// PURPOSE:
//   A focused sheet for editing a budget's name, amount, and
//   pause state. Wired into BudgetDetailView (see those changes).
//
// DESIGN PRINCIPLE: "Time should feel invisible."
//   The user never touches cycle dates, recurrence rules, or
//   cycle type here. Those are creation-time concerns.
//   Editing only addresses the three things that meaningfully
//   change: what is it called, how much can I spend, is it active?
//
// MID-CYCLE AMOUNT CHANGE:
//   If the saved amount differs from the current amount, an
//   Alert is shown before committing — asking the user whether
//   the change applies to the current cycle only, or going forward.
//   This maps directly to CycleEngine.applyBudgetAmountEdit's
//   EditScope (.currentCycleOnly / .futureOnly).
//
// SAFE UPDATE STRATEGY SUMMARY (see CycleEngine+EdgeCases.swift):
//   • Name change  → committed immediately on Save (no historical impact)
//   • Amount change → committed only after the scope alert is confirmed
//   • Pause toggle  → draft state, committed on Save (Cancel undoes it)
//
// ALL CHANGES ARE DRAFT-BASED:
//   Local @State variables mirror the budget's values.
//   Nothing is written to SwiftData until the user taps Save.
//   Tapping Cancel leaves the budget completely untouched.
// ============================================================

import SwiftUI
import SwiftData

struct EditBudgetView: View {

    // @Bindable lets us write back to the @Model object.
    // We use it only at the point of committing (Save / scope alert button).
    @Bindable var budget: Budget

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    // ── Draft state ──────────────────────────────────────────────────────────
    // These mirror the live budget values but are NOT written to SwiftData
    // until the user explicitly saves.
    @State private var draftName:     String
    @State private var draftAmount:   String
    @State private var draftIsPaused: Bool

    // Controls the mid-cycle scope confirmation alert.
    @State private var showingAmountScopeAlert = false

    // MARK: - Init

    init(budget: Budget) {
        self.budget       = budget
        _draftName        = State(initialValue: budget.name)
        _draftAmount      = State(initialValue: String(format: "%.2f", budget.totalAmount))
        _draftIsPaused    = State(initialValue: budget.isPaused)
    }

    // MARK: - Computed Helpers

    /// The draft amount parsed as a Double, or nil if the field is invalid.
    private var parsedAmount: Double? {
        guard let d = Double(draftAmount), d > 0 else { return nil }
        return d
    }

    /// True only if the user changed the amount AND the new value is valid.
    private var amountChanged: Bool {
        parsedAmount != nil && parsedAmount != budget.totalAmount
    }

    /// Form is valid when name is non-empty and amount is a positive number.
    private var isFormValid: Bool {
        !draftName.trimmingCharacters(in: .whitespaces).isEmpty &&
        parsedAmount != nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                amountSection
                pauseSection
            }
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { handleSave() }
                        .disabled(!isFormValid)
                        .fontWeight(.semibold)
                }
            }

            // ── Mid-cycle scope alert ────────────────────────────────────────
            // Shown only when the amount changed. Forces a conscious choice
            // between patching the active cycle or changing future cycles.
            // Cancel keeps the draft alive so the user can adjust the amount.
            .alert("Budget Amount Changed", isPresented: $showingAmountScopeAlert) {
                Button("Current Cycle Only") {
                    commitEdit(scope: .currentCycleOnly)
                }
                Button("Future Cycles") {
                    commitEdit(scope: .futureOnly)
                }
                Button("Cancel", role: .cancel) {
                    // User changed their mind — return to the form without saving.
                }
            } message: {
                Text(
                    "Apply \(formattedDraftAmount) to just the current cycle, " +
                    "or to all cycles going forward?"
                )
            }
        }
    }

    // MARK: - Section: Name

    private var nameSection: some View {
        Section("Budget Name") {
            TextField("e.g. Groceries, Travel…", text: $draftName)
                .autocorrectionDisabled()
        }
    }

    // MARK: - Section: Amount

    private var amountSection: some View {
        Section {
            HStack {
                Text("$").foregroundStyle(.secondary)
                TextField("0.00", text: $draftAmount)
                    .keyboardType(.decimalPad)
            }
        } header: {
            Text("Amount")
        } footer: {
            // Only show the hint when the user has actually changed the value.
            if amountChanged {
                Label(
                    "You'll choose whether this applies to the current cycle or future cycles when you save.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Section: Pause

    private var pauseSection: some View {
        Section {
            Toggle(isOn: $draftIsPaused) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pause this budget")
                    Text(
                        draftIsPaused
                            ? "No new cycles will start. Your history is preserved."
                            : "Budget is active — cycles advance automatically."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .tint(.orange)
        } header: {
            Text("Status")
        } footer: {
            if draftIsPaused && !budget.isPaused {
                // Draft is paused but the budget isn't yet — preview the effect.
                Label(
                    "Saving will stop automatic cycle progression.",
                    systemImage: "pause.circle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            } else if !draftIsPaused && budget.isPaused {
                // Draft is unpaused — preview the resume effect.
                Label(
                    "Saving will resume cycles. Any missed periods will be backfilled automatically.",
                    systemImage: "play.circle"
                )
                .font(.caption)
                .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Actions

    /// Called when the user taps Save.
    ///
    /// 1. Name change is safe to commit immediately (no historical impact).
    /// 2. Pause change is safe to commit immediately.
    /// 3. Amount change routes through the scope alert for a conscious choice.
    private func handleSave() {
        // Step 1: commit name (always safe).
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            budget.name = trimmed
        }

        // Step 2: commit pause state.
        CycleEngine.setPaused(draftIsPaused, for: budget)

        // Step 3: route amount through the scope alert, or finish immediately.
        if amountChanged {
            showingAmountScopeAlert = true
        } else {
            dismiss()
        }
    }

    /// Called after the user picks a scope in the alert.
    ///
    /// applyBudgetAmountEdit is the single point of truth for mid-cycle
    /// amount changes — it knows whether to patch the active cycle's snapshot
    /// or only update the budget template.
    private func commitEdit(scope: EditScope) {
        guard let amount = parsedAmount else { return }
        CycleEngine.applyBudgetAmountEdit(
            to: budget,
            newAmount: amount,
            scope: scope,
            context: modelContext
        )
        dismiss()
    }

    // MARK: - Helpers

    /// Formats the draft amount as a currency string for the alert message.
    private var formattedDraftAmount: String {
        guard let amount = parsedAmount else { return "the new amount" }
        return amount.formatted(.currency(code: "USD"))
    }
}

// MARK: - Preview

#Preview("Edit active budget") {
    let config    = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Budget.self, BudgetCycle.self, Expense.self,
        configurations: config
    )
    let budget = Budget(name: "Groceries", totalAmount: 400, cycleType: .monthly)
    container.mainContext.insert(budget)
    CycleEngine.ensureActiveCycleExists(for: budget, context: container.mainContext)

    return EditBudgetView(budget: budget)
        .modelContainer(container)
}

#Preview("Edit paused budget") {
    let config    = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Budget.self, BudgetCycle.self, Expense.self,
        configurations: config
    )
    let budget = Budget(name: "Travel Fund", totalAmount: 1200, cycleType: .monthly)
    budget.isPaused = true
    container.mainContext.insert(budget)

    return EditBudgetView(budget: budget)
        .modelContainer(container)
}
