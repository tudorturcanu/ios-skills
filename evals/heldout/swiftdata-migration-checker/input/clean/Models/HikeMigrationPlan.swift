import SwiftData

enum HikeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2]
    }

    // V1 `distance` is carried into V2 as `legacyDistance` (originalName), then
    // copied into the renamed `distanceKm` after the schema change is applied.
    static let v1ToV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let hikes = try context.fetch(FetchDescriptor<SchemaV2.Hike>())
            for hike in hikes {
                if let old = hike.legacyDistance {
                    hike.distanceKm = old
                }
            }
            try context.save()
        }
    )
}
