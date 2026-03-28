// ============================================================
// FILE:   CreateBudgetView.swift
// LOCATION: SpendTally/Views/Budget/CreateBudgetView.swift
//
// ACTION: REPLACE EXISTING FILE — full replacement.
//
// WHAT CHANGED:
//   • The "Reset Frequency" section is now the centrepiece.
//     A 2×2 card grid lets the user pick a cycle type, and an
//     animated contextual-config section immediately below it
//     shows only the options relevant to that choice.
//
//   • "Repeat automatically?" toggle replaces the old single-
//     checkbox; sub-text explains the consequence clearly.
//
//   • The toolbar "Save" button is now labelled "Continue".
//     Tapping it opens a Preview modal sheet for the user to
//     review the budget before committing. The modal contains
//     the Save button that triggers the actual save logic.
//
//   • BudgetPreviewModal (private struct, bottom of file):
//       – Displays the budget summary (same data as the old
//         inline preview section).
//       – "Save" button commits the budget and dismisses all.
//       – "Go Back" (leading toolbar) dismisses only the modal,
//         returning the user to the form to make adjustments.
//
//   • Private sub-views:
//       CycleTypeCard   — unchanged card design
//       OptionChip      — new horizontal pill-button for
//                         sub-option selection within a section
//       PreviewRow      — icon + label + value row in the
//                         preview card
// ============================================================

import SwiftUI
import SwiftData

struct CreateBudgetView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    @State private var vm = BudgetViewModel()

    // Controls the preview modal shown after tapping "Continue".
    @State private var showingPreviewModal = false

    // Set to true by the modal's Save action. Read in onDismiss so that
    // CreateBudgetView only dismisses AFTER the modal has fully closed —
    // preventing a crash from tearing down the parent while the child sheet
    // is still on screen.
    @State private var didSave = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                amountSection
                frequencySection

                // Contextual configuration — slides in/out with animation
                // when the user switches between cycle types.
                if vm.newBudgetCycleType == .weekly  { weeklyConfigSection }
                if vm.newBudgetCycleType == .monthly { monthlyConfigSection }
                if vm.newBudgetCycleType == .custom  { customConfigSection }

                recurrenceSection
            }
            .navigationTitle("New Budget")
            .navigationBarTitleDisplayMode(.inline)
            // Animate the appearance / disappearance of sections.
            .animation(.easeInOut(duration: 0.25), value: vm.newBudgetCycleType)
            .animation(.easeInOut(duration: 0.2),  value: vm.weeklyIntervalOption)
            .animation(.easeInOut(duration: 0.2),  value: vm.weeklyStartDayOption)
            .animation(.easeInOut(duration: 0.2),  value: vm.monthlyResetDayOption)
            .animation(.easeInOut(duration: 0.2),  value: vm.isFormValid)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        showingPreviewModal = true
                    }
                    .disabled(!vm.isFormValid)
                }
            }
            // ── Preview modal ────────────────────────────────────────────────
            // Shown when the user taps "Continue". The user reviews the budget
            // summary and either taps "Save" to commit or "Go Back" to adjust.
            //
            // SAVE FLOW (two-step dismiss to avoid a crash):
            //   1. Modal's Save button calls onSave() → vm.createBudget runs,
            //      didSave is set to true, then the MODAL dismisses itself.
            //   2. onDismiss fires after the modal is fully gone. If didSave is
            //      true, CreateBudgetView dismisses itself. This order ensures
            //      the parent is never torn down while the child is still alive.
            .sheet(isPresented: $showingPreviewModal, onDismiss: {
                if didSave { dismiss() }
            }) {
                BudgetPreviewModal(vm: vm) {
                    vm.createBudget(context: modelContext)
                    didSave = true
                    // BudgetPreviewModal dismisses itself after calling onSave();
                    // onDismiss above then dismisses CreateBudgetView.
                }
            }
        }
    }

    // MARK: - Budget Name Section

    private var nameSection: some View {
        Section("Budget Name") {
            TextField("e.g. Groceries, Travel…", text: $vm.newBudgetName)
                .autocorrectionDisabled()
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        Section("Amount") {
            HStack {
                Text("$").foregroundStyle(.secondary)
                TextField("0.00", text: $vm.newBudgetAmount)
                    .keyboardType(.decimalPad)
            }
        }
    }

    // MARK: - Frequency Section

    /// The core question: "How often does this reset?"
    /// Shows a 2×2 card grid for the four cycle types.
    private var frequencySection: some View {
        Section {
            // Short orientation sentence — no time configuration detail here.
            Text("Choose how often this budget resets. Everything else is handled automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
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

        } header: {
            Text("How often does this reset?")
        }
    }

    // MARK: - Weekly Configuration Section

    /// Shown only when .weekly is selected.
    /// Lets the user choose the interval (7d / 5d / custom) and
    /// which day the first cycle anchors to.
    @ViewBuilder
    private var weeklyConfigSection: some View {
        Section {

            // ── Reset interval ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Text("Reset every")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(WeeklyIntervalOption.allCases) { option in
                        OptionChip(
                            label: option.rawValue,
                            isSelected: vm.weeklyIntervalOption == option
                        ) { vm.weeklyIntervalOption = option }
                    }
                }

                // Custom day-count field animates in below the chips.
                if vm.weeklyIntervalOption == .custom {
                    HStack(spacing: 8) {
                        TextField("7", text: $vm.weeklyCustomDays)
                            .keyboardType(.numberPad)
                            .frame(width: 52)
                            .multilineTextAlignment(.center)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("days per cycle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            // ── Start day ─────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Text("Starting")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(WeeklyStartDayOption.allCases) { option in
                        OptionChip(
                            label: option.rawValue,
                            isSelected: vm.weeklyStartDayOption == option
                        ) { vm.weeklyStartDayOption = option }
                    }
                }

                // Custom date picker animates in below the chips.
                if vm.weeklyStartDayOption == .custom {
                    DatePicker(
                        "",
                        selection: $vm.weeklyCustomStartDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

        } header: {
            Text("Weekly settings")
        }
    }

    // MARK: - Monthly Configuration Section

    /// Shown only when .monthly is selected.
    /// Lets the user pick which day of the month the budget resets on.
    @ViewBuilder
    private var monthlyConfigSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Reset on the")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(MonthlyResetDayOption.allCases) { option in
                        OptionChip(
                            label: option.rawValue,
                            isSelected: vm.monthlyResetDayOption == option
                        ) { vm.monthlyResetDayOption = option }
                    }
                }

                if vm.monthlyResetDayOption == .custom {
                    HStack(spacing: 8) {
                        Text("Day")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("1", text: $vm.monthlyCustomResetDay)
                            .keyboardType(.numberPad)
                            .frame(width: 52)
                            .multilineTextAlignment(.center)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("of each month (1–28)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

        } header: {
            Text("Monthly settings")
        }
    }

    // MARK: - Custom Configuration Section

    /// Shown only when .custom is selected.
    @ViewBuilder
    private var customConfigSection: some View {
        Section {
            HStack(spacing: 8) {
                Text("Reset every")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("14", text: $vm.newBudgetCustomDays)
                    .keyboardType(.numberPad)
                    .frame(width: 52)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            DatePicker(
                "Starting",
                selection: $vm.customStartDate,
                displayedComponents: .date
            )

        } header: {
            Text("Custom settings")
        }
    }

    // MARK: - Recurrence Section

    private var recurrenceSection: some View {
        Section {
            Toggle(isOn: $vm.isRecurring) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Repeat automatically")
                    Text(
                        vm.isRecurring
                            ? "A new cycle begins as soon as the current one ends"
                            : "Budget runs for one cycle only, then stops"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .tint(Color.accentColor)
        } header: {
            Text("Recurrence")
        }
    }
}

// MARK: - Budget Preview Modal

/// Full-screen modal sheet that shows the user a summary of the budget
/// they're about to create. Presented after tapping "Continue".
///
/// "Save"    → calls onSave() which commits the budget and dismisses all.
/// "Go Back" → dismisses only this modal, returning the user to the form.
private struct BudgetPreviewModal: View {

    let vm: BudgetViewModel
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {

                    // ── Narrative summary ────────────────────────────────────
                    // No card/list background — text sits directly on the
                    // grouped background so it reads like a large editorial
                    // callout the user can scan at a glance.
                    narrativeSummary
                        .padding(.horizontal, 28)
                        .padding(.top, 16)

                    Text("Dates are calculated automatically — no manual tracking needed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Review Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Go Back") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // onSave() commits the budget and sets didSave = true
                        // on the parent. Then we dismiss the modal ourselves so
                        // the parent's onDismiss can fire cleanly afterward.
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Narrative Summary

    /// Builds a scannable paragraph where the key figures are bolded so the
    /// user can sweep their eyes across the text and catch every important
    /// detail without reading word-for-word.
    ///
    /// Example output:
    ///   "Groceries" is a monthly budget of $1,500.00. It starts Mar 1, 2026
    ///   and resets Apr 1, 2026. This budget resets on the 1st of each month.
    ///   The cycle is 31 days and automatically repeats.
    private var narrativeSummary: some View {
        let name       = vm.newBudgetName
        let cycleLabel = vm.newBudgetCycleType.displayName.lowercased()
        let amount     = Double(vm.newBudgetAmount).map {
            $0.formatted(.currency(code: "USD"))
        } ?? vm.newBudgetAmount
        let start      = mediumDate(vm.previewCycleStart)
        let reset      = mediumDate(vm.previewNextReset)
        let frequency  = vm.previewFrequencyLabel
        let days       = vm.previewExactCycleDays
        let dayWord    = days == 1 ? "day" : "days"
        let repeatText = vm.isRecurring ? "automatically repeats" : "runs for one cycle only"

        // Build the paragraph using Text concatenation so bold segments are
        // inline — no markdown parsing, no AttributedString complexity.
        return (
            Text("\"") +
            Text(name).bold() +
            Text("\" is a ") +
            Text(cycleLabel).bold() +
            Text(" budget of ") +
            Text(amount).bold() +
            Text(". It starts ") +
            Text(start).bold() +
            Text(" and resets ") +
            Text(reset).bold() +
            Text(". \(frequency). The cycle is ") +
            Text("\(days) \(dayWord)").bold() +
            Text(" and ") +
            Text(repeatText).bold() +
            Text(".")
        )
        .font(.title2)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func mediumDate(_ date: Date) -> String {
        let df        = DateFormatter()
        df.dateStyle  = .medium
        return df.string(from: date)
    }
}

// MARK: - Cycle Type Card

/// The large 2×2 selection card. Unchanged from the original design.
private struct CycleTypeCard: View {

    let cycleType: CycleType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: cycleType.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)

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

// MARK: - Option Chip

/// A horizontal pill-shaped button used for sub-option selection
/// (e.g. "7 days / 5 days / Custom" inside the weekly section).
private struct OptionChip: View {

    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Preview Row

/// A single labelled row inside the Preview card.
private struct PreviewRow: View {
    let icon:  String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }
}
