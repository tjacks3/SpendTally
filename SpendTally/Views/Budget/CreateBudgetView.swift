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
//   • A live Preview section appears once the form is valid.
//     It shows the first cycle's start date, the next reset
//     date, the cycle length in days, and the repeat setting —
//     all derived from CycleManager so the numbers are exact.
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

                // Preview only appears once the form has enough valid data.
                if vm.isFormValid { previewSection }
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
                    Button("Save") {
                        vm.createBudget(context: modelContext)
                        dismiss()
                    }
                    .disabled(!vm.isFormValid)
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

    // MARK: - Preview Section

    /// A live summary card that appears once the form is valid.
    /// All values come directly from CycleManager, so what the user
    /// sees here is exactly what the app will create.
    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {

                // ── Header row ────────────────────────────────────────────
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.newBudgetName)
                            .font(.subheadline.bold())

                        if let amount = Double(vm.newBudgetAmount) {
                            Text(amount, format: .currency(code: "USD"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Cycle type pill badge
                    Text(vm.newBudgetCycleType.displayName)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }

                Divider()

                // ── Detail rows ───────────────────────────────────────────
                PreviewRow(
                    icon:  "arrow.clockwise",
                    label: "Frequency",
                    value: vm.previewFrequencyLabel
                )
                PreviewRow(
                    icon:  "calendar",
                    label: "Cycle begins",
                    value: mediumDate(vm.previewCycleStart)
                )
                PreviewRow(
                    icon:  "clock.arrow.2.circlepath",
                    label: "Next reset",
                    value: mediumDate(vm.previewNextReset)
                )
                PreviewRow(
                    icon:  "ruler",
                    label: "Cycle length",
                    value: "\(vm.previewExactCycleDays) day\(vm.previewExactCycleDays == 1 ? "" : "s")"
                )
                PreviewRow(
                    icon:  "repeat",
                    label: "Repeats",
                    value: vm.isRecurring ? "Yes, automatically" : "One time only"
                )
            }
            .padding(.vertical, 4)

        } header: {
            Text("Preview")
        } footer: {
            Text("Dates are calculated automatically — no manual tracking needed.")
                .font(.caption)
        }
    }

    // MARK: - Helpers

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
