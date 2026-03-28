// ============================================================
// FILE:   SettingsView.swift
// LOCATION: SpendTally/Views/Settings/SettingsView.swift
//
// ACTION: NEW FILE
//   1. In Xcode's Project Navigator, right-click the "Views" group.
//   2. New Group → name it "Settings".
//   3. Right-click the new "Settings" group → New File from Template
//      → Swift File → name it "SettingsView".
//   4. Paste this entire file, replacing the generated stub.
//
// WHAT THIS FILE PROVIDES:
//   • SettingsView — the top-level Settings tab content.
//
// APPEARANCE PERSISTENCE:
//   The selected appearance mode is stored in UserDefaults under the
//   key "appearanceMode" via @AppStorage. ContentView reads the same
//   key and applies .preferredColorScheme() at the window level so
//   the preference is honoured everywhere in the app.
//
// SECTION MAP:
//   ┌─────────────────────────────────────┐
//   │  APPEARANCE                         │
//   │    Appearance mode picker chip row  │
//   ├─────────────────────────────────────┤
//   │  SUPPORT                            │
//   │    Help & Support   →               │
//   │    Terms of Service →               │
//   ├─────────────────────────────────────┤
//   │  ABOUT                              │
//   │    Version          1.0 (1)         │
//   └─────────────────────────────────────┘
// ============================================================

import SwiftUI

// MARK: - AppearanceMode

/// The three user-selectable appearance options.
///
/// Raw value is the string persisted in UserDefaults / @AppStorage.
/// The same raw values are read by ContentView to resolve a
/// `ColorScheme?` via `AppearanceMode.resolvedColorScheme`.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var id: String { rawValue }

    /// Human-readable label shown in the UI.
    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// SF Symbol representing each mode.
    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    /// The `ColorScheme?` to pass to `.preferredColorScheme()`.
    /// `nil` means "follow the system default".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - SettingsView

struct SettingsView: View {

    // Persisted appearance preference.
    // ContentView reads the same key and applies .preferredColorScheme().
    @AppStorage("appearanceMode") private var appearanceRaw: String = AppearanceMode.system.rawValue

    // Resolved enum — derived from the stored raw string.
    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    // Controls presentation of the web-content sheets below.
    @State private var showingHelp: Bool = false
    @State private var showingTerms: Bool = false

    // MARK: - Body

    var body: some View {
        List {
            appearanceSection
            supportSection
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        // ── Help & Support sheet ──────────────────────────────────────────────
        .sheet(isPresented: $showingHelp) {
            HelpSupportSheet()
        }
        // ── Terms of Service sheet ────────────────────────────────────────────
        .sheet(isPresented: $showingTerms) {
            TermsOfServiceSheet()
        }
    }

    // MARK: - Appearance Section

    /// Segmented chip row for choosing System / Light / Dark.
    ///
    /// Three chips are used instead of a Picker wheel so all options are
    /// visible at once — a common pattern in iOS settings screens (e.g. Maps).
    private var appearanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(AppearanceMode.allCases) { mode in
                        AppearanceChip(
                            mode: mode,
                            isSelected: appearanceMode == mode
                        ) {
                            appearanceRaw = mode.rawValue
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Appearance")
        } footer: {
            Text("Choose how SpendTally looks. System follows your device setting.")
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        Section("Support") {
            // ── Help & Support ───────────────────────────────────────────────
            Button {
                showingHelp = true
            } label: {
                Label("Help & Support", systemImage: "questionmark.circle")
                    .foregroundStyle(.primary)
            }

            // ── Terms of Service ─────────────────────────────────────────────
            Button {
                showingTerms = true
            } label: {
                Label("Terms of Service", systemImage: "doc.text")
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - About Section

    /// Displays the marketing version and build number from the main bundle.
    ///
    /// The values come from the app's Info.plist:
    ///   • CFBundleShortVersionString → e.g. "1.0"
    ///   • CFBundleVersion            → e.g. "1"
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(versionString)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Helpers

    /// e.g. "1.0 (1)"
    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}

// MARK: - AppearanceChip

/// A single tappable chip representing one AppearanceMode.
///
/// Selected state is shown with the accent colour fill and a white label.
/// Unselected state uses a secondary background (adapts to light/dark).
private struct AppearanceChip: View {

    let mode:       AppearanceMode
    let isSelected: Bool
    let onTap:      () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 20))
                Text(mode.label)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected
                    ? Color.accentColor
                    : Color(.secondarySystemGroupedBackground)
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .animation(.easeInOut(duration: 0.18), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - HelpSupportSheet

/// Minimal support screen shown when the user taps "Help & Support".
///
/// Extend this sheet later with a real FAQ list, a contact form, or
/// a link to a support URL — without touching SettingsView itself.
private struct HelpSupportSheet: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Budgets reset automatically at the start of each cycle — you don't need to do anything.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("How budgets work")
                }

                Section {
                    Link(destination: URL(string: "mailto:support@spendtally.app")!) {
                        Label("Email Support", systemImage: "envelope")
                    }
                } header: {
                    Text("Contact")
                }
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - TermsOfServiceSheet

/// Minimal Terms of Service screen.
///
/// Replace the placeholder body text with real legal copy when ready.
private struct TermsOfServiceSheet: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text("""
                    Last updated: March 2026

                    By using SpendTally you agree to these terms. \
                    SpendTally is provided "as is" without warranty of any kind. \
                    Your data is stored locally on your device and optionally \
                    synced via iCloud. We do not sell your personal information.

                    *(Replace this placeholder with your real legal copy.)*
                    """)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(24)
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
}
