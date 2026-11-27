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
        var distanceKm: Double = 0   // renamed from `distance`
        var notes: String = ""
        var isFavorite: Bool = false

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
