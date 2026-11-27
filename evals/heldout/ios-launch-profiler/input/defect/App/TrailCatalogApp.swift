import SwiftUI

@main
struct TrailCatalogApp: App {
    @StateObject private var store = CatalogStore()

    var body: some Scene {
        WindowGroup {
            TrailListView()
                .environmentObject(store)
        }
    }
}

struct TrailListView: View {
    @EnvironmentObject var store: CatalogStore
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(store.search(query)) { trail in
                VStack(alignment: .leading) {
                    Text(trail.name).font(.headline)
                    Text("\(trail.region) - \(trail.lengthKm, specifier: "%.1f") km")
                        .font(.subheadline)
                }
            }
            .searchable(text: $query)
            .navigationTitle("Trails")
        }
    }
}
