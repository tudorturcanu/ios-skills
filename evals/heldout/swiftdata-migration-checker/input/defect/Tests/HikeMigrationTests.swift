import Testing
import Foundation
import SwiftData
@testable import Trailhead

struct HikeMigrationTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: schema,
            migrationPlan: HikeMigrationPlan.self,
            configurations: config
        )
    }

    @Test func containerBuildsWithMigrationPlan() throws {
        let container = try makeContainer()
        #expect(container.schema.version == Schema.Version(2, 0, 0))
    }

    @Test func storesAndFetchesHike() throws {
        let context = ModelContext(try makeContainer())
        context.insert(Hike(name: "Ridge", date: .now, distanceKm: 12.5))
        try context.save()

        let hikes = try context.fetch(FetchDescriptor<Hike>())
        #expect(hikes.count == 1)
        #expect(hikes[0].distanceKm == 12.5)
        #expect(hikes[0].isFavorite == false)
    }
}
