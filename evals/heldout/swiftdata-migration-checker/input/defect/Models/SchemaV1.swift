import Foundation
import SwiftData

// Shipped in Trailhead 1.0 - 1.3. Do not edit.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Hike.self] }

    @Model
    final class Hike {
        var name: String
        var date: Date
        var distance: Double   // kilometres
        var notes: String = ""

        init(name: String, date: Date, distance: Double, notes: String = "") {
            self.name = name
            self.date = date
            self.distance = distance
            self.notes = notes
        }
    }
}
