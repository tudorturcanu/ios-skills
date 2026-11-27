import Foundation
import SwiftData

// Trailhead 1.4
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Hike.self] }

    @Model
    final class Hike {
        var name: String
        var date: Date
        var distanceKm: Double = 0
        var notes: String = ""
        var isFavorite: Bool = false

        // Holds the V1 `distance` column so the migration stage can copy it
        // into `distanceKm`. Nil for hikes created in 1.4 or later.
        @Attribute(originalName: "distance")
        var legacyDistance: Double?

        init(name: String, date: Date, distanceKm: Double,
             notes: String = "", isFavorite: Bool = false) {
            self.name = name
            self.date = date
            self.distanceKm = distanceKm
            self.notes = notes
            self.isFavorite = isFavorite
        }
    }
}
