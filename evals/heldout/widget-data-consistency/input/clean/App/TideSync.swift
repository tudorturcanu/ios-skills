import Foundation
import WidgetKit

protocol TideAPI {
    func fetchNextHighTide(harbor: String) async throws -> TideSnapshot
}

final class TideSync {
    private let api: TideAPI
    private let harbor: String

    init(api: TideAPI, harbor: String) {
        self.api = api
        self.harbor = harbor
    }

    /// Called on pull-to-refresh and when the app becomes active.
    func refresh() async throws -> TideSnapshot {
        let snapshot = try await api.fetchNextHighTide(harbor: harbor)

        // Persist first so the provider reads the new snapshot when it re-runs.
        SharedStore.save(snapshot)

        // Then ask WidgetKit to re-run the timeline provider.
        WidgetCenter.shared.reloadAllTimelines()
        return snapshot
    }
}
