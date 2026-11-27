import Foundation

struct Trail: Decodable, Identifiable {
    let id: Int
    let name: String
    let region: String
    let lengthKm: Double
}

final class CatalogStore: ObservableObject {
    @Published private(set) var trails: [Trail] = []

    init() {
        // Load the bundled trail catalog so the list is ready immediately.
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Trail].self, from: data)
        else { return }
        trails = decoded.sorted { $0.name < $1.name }
    }

    func search(_ query: String) -> [Trail] {
        guard !query.isEmpty else { return trails }
        return trails.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}
