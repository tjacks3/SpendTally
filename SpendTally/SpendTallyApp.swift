import SwiftUI
import SwiftData

@main
struct SpendPalApp: App {
    
    // We build the container manually so we can configure CloudKit.
    let container: ModelContainer
    
    init() {
        // 1. Define the "schema" — which models exist in our database.
        let schema = Schema([
            Budget.self,
            Expense.self
        ])
        
        // 2. Configure storage.
        //    cloudKitDatabase: .automatic tells SwiftData to sync with
        //    the iCloud container you enabled in Signing & Capabilities.
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,         // save to disk
            cloudKitDatabase: .automatic         // sync via iCloud
        )
        
        // 3. Create the container. `fatalError` stops the app at launch
        //    if the database can't be created — which shouldn't happen
        //    unless you have a code bug, so it's safe for an MVP.
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("❌ Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject the container into the SwiftUI environment.
                // Every view can now access the database via @Environment(\.modelContext)
                .modelContainer(container)
        }
    }
}
