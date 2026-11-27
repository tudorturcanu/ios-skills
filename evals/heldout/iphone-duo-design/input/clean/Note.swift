import Foundation

struct Note: Identifiable, Hashable {
    let id: UUID
    var title: String
    var body: String
}

extension Note {
    static let samples = [
        Note(id: UUID(), title: "Ridge route", body: "Start before 7am."),
        Note(id: UUID(), title: "Gear list", body: "Stove, filter, layers."),
    ]
}
