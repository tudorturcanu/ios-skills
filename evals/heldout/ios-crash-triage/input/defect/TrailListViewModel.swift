import Foundation

struct Trail: Decodable {
    let id: String
    let name: String
    let distanceKm: Double
    let photos: [URL]
}

struct TrailsResponse: Decodable {
    let region: String
    let trails: [Trail]
}

struct TrailRow {
    let title: String
    let subtitle: String
    let thumbnail: URL
}

final class TrailListViewModel {
    private(set) var rows: [TrailRow] = []

    func load(from data: Data) throws {
        let response = try JSONDecoder().decode(TrailsResponse.self, from: data)
        rows = response.trails.map { makeRow(for: $0) }
    }

    func makeRow(for trail: Trail) -> TrailRow {
        let subtitle = String(format: "%.1f km", trail.distanceKm)
        let thumb = trail.photos[0]
        return TrailRow(title: trail.name, subtitle: subtitle, thumbnail: thumb)
    }
}
