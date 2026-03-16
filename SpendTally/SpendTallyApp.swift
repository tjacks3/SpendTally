import SwiftUI
import SwiftData

@main
struct SpendTallyApp: App {

    let container: ModelContainer

    init() {
        // Define the schema — which models exist in our database.
        let schema = Schema([
            Budget.self,
            Expense.self
        ])

        // MARK: - Container Setup
        // We try CloudKit first. If that fails (e.g. iCloud container not yet
        // provisioned in the Apple Developer portal, or the user is signed out),
        // we fall back to local-only storage so the app always launches.

        do {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic   // sync via iCloud when available
            )
            container = try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            // CloudKit failed — fall back to local storage.
            // Common causes:
            //   • iCloud container not registered in the Apple Developer portal
            //   • User is not signed into iCloud on this device
            //   • Running on the Simulator without an iCloud account
            print("⚠️ CloudKit unavailable, falling back to local storage: \(error)")

            do {
                let localConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .none    // local only, no sync
                )
                container = try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                // If even local storage fails, something is seriously wrong
                // (e.g. schema mismatch after a code change). Crash with a clear message.
                fatalError("❌ Failed to create local ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
