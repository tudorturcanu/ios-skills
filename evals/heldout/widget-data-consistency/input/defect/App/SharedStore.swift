import Foundation

struct TideSnapshot: Codable, Equatable {
    var harbor: String
    var nextHighTide: Date
    var heightMeters: Double
    var fetchedAt: Date
}

/// Shared by the app and the widget extension (target membership: both).
enum SharedStore {
    static let groupID = "group.com.example.tidewatch"
    private static let key = "tide.snapshot.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: groupID)!
    }

    static func save(_ snapshot: TideSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> TideSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TideSnapshot.self, from: data)
    }
}
