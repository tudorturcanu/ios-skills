import SwiftUI
import SwiftData

typealias Hike = SchemaV2.Hike

@main
struct TrailheadApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema(versionedSchema: SchemaV2.self)
            container = try ModelContainer(
                for: schema,
                migrationPlan: HikeMigrationPlan.self,
                configurations: ModelConfiguration(schema: schema)
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup { HikeListView() }
            .modelContainer(container)
    }
}
