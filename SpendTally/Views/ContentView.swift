// ============================================================
// FILE:   ContentView.swift
// LOCATION: SpendTally/Views/ContentView.swift
//
// ACTION: REPLACE EXISTING FILE — full replacement.
//
// WHAT CHANGED vs. the previous version:
//
//   REPLACED — NavigationStack { BudgetListView() }
//     The root view is now a TabView with two primary tabs:
//       1. Home     — wraps BudgetListView in a NavigationStack
//                     (all existing push navigation is preserved)
//       2. Settings — wraps SettingsView in a NavigationStack
//
//   ADDED — @AppStorage("appearanceMode")
//     Reads the same UserDefaults key written by SettingsView.
//     Resolved to a ColorScheme? and applied via .preferredColorScheme()
//     at the TabView level so the choice is honoured everywhere.
//
// EVERYTHING ELSE IS UNCHANGED:
//   • BudgetListView and its NavigationStack behaviour are identical.
//   • No SwiftData or CycleEngine code is touched.
//
// LAYOUT:
//   TabView
//     ├─ Tab("Home", systemImage: "house")
//     │    └─ NavigationStack → BudgetListView()
//     └─ Tab("Settings", systemImage: "gear")
//          └─ NavigationStack → SettingsView()
// ============================================================

import SwiftUI
import SwiftData

/// The root view of SpendTally.
///
/// Owns the TabView shell and the app-wide appearance preference.
/// Individual tab content is delegated to BudgetListView and SettingsView.
struct ContentView: View {

    // ── Appearance preference ────────────────────────────────────────────────
    // Written by SettingsView via the same @AppStorage key.
    // Reading it here ensures .preferredColorScheme() is applied at the
    // window root — the only place that guarantees the whole app responds.
    @AppStorage("appearanceMode") private var appearanceRaw: String = AppearanceMode.system.rawValue

    /// Resolved colour scheme — nil means "follow the system".
    private var preferredColorScheme: ColorScheme? {
        (AppearanceMode(rawValue: appearanceRaw) ?? .system).colorScheme
    }

    // MARK: - Body

    var body: some View {
        TabView {

            // ── Tab 1: Home ──────────────────────────────────────────────────
            // BudgetListView already owns its navigation title and toolbar.
            // Wrapping in a NavigationStack here preserves the existing
            // push-navigation graph (BudgetListView → DashboardView, etc.)
            // exactly as it was when NavigationStack lived in ContentView.
            Tab("Home", systemImage: "house") {
                NavigationStack {
                    BudgetListView()
                }
            }

            // ── Tab 2: Settings ──────────────────────────────────────────────
            // SettingsView is a self-contained List-based settings screen.
            // Its own NavigationStack allows future drill-down rows (e.g.
            // a full FAQ page) without coupling to the Home stack.
            Tab("Settings", systemImage: "gearshape.fill") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        // Apply the user's preferred colour scheme to the entire app.
        // nil → system default, .light → always light, .dark → always dark.
        .preferredColorScheme(preferredColorScheme)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [Budget.self, BudgetCycle.self, Expense.self],
                        inMemory: true)
}
