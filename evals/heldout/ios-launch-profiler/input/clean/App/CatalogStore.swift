import Foundation

struct Trail: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let region: String
    let lengthKm: Double
}

@MainActor
final class CatalogStore: ObservableObject {
    @Published private(set) var trails: [Trail] = []
    @Published private(set) var isLoaded = false

    init() {}  // no I/O or decoding here; first frame does not wait on the catalog

    func load() async {
        guard !isLoaded else { return }
        // Read, decode and sort off the main actor, then publish once.
        let result = await Task.detached(priority: .userInitiated) { () -> [Trail] in
            guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode([Trail].self, from: data)
            else { return [] }
            return decoded.sorted { $0.name < $1.name }
        }.value
        trails = result
        isLoaded = true
    }

    func search(_ query: String) -> [Trail] {
        guard !query.isEmpty else { return trails }
        return trails.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}
