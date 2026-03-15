import SwiftUI

/// The root view. NavigationStack manages the push/pop navigation stack.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            BudgetListView()
        }
    }
}
