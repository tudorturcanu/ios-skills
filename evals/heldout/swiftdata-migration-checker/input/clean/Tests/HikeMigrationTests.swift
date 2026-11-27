import Testing
import Foundation
import SwiftData
@testable import Trailhead

struct HikeMigrationTests {
    private func tempStoreURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("hikes.store")
    }

    @Test func v1StoreKeepsDistanceAfterMigration() throws {
        let url = try tempStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        // 1. Create an on-disk store using the OLD schema and seed it.
        do {
            let v1 = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(
                for: v1, configurations: ModelConfiguration(schema: v1, url: url))
            let context = ModelContext(container)
            context.insert(SchemaV1.Hike(name: "Ridge",
                date: Date(timeIntervalSince1970: 1_700_000_000),
                distance: 12.5, notes: "windy"))
            try context.save()
        }

        // 2. Reopen the same file with the V2 schema and the migration plan.
        let v2 = Schema(versionedSchema: SchemaV2.self)
        let migrated = try ModelContainer(
            for: v2, migrationPlan: HikeMigrationPlan.self,
            configurations: ModelConfiguration(schema: v2, url: url))

        let hikes = try ModelContext(migrated).fetch(FetchDescriptor<SchemaV2.Hike>())
        #expect(hikes.count == 1)
        #expect(hikes[0].name == "Ridge")
        #expect(hikes[0].notes == "windy")
        #expect(hikes[0].distanceKm == 12.5)
        #expect(hikes[0].isFavorite == false)
    }
}
