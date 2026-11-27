import Foundation

protocol OrdersAPI {
    func post(path: String, body: [String]) async throws
}

/// Durable queue for orders created while offline or on a flaky network.
actor OrderOutbox {
    struct Pending: Codable {
        let items: [String]
    }

    private let api: OrdersAPI
    private let store: URL
    private var queue: [Pending]
    private var flushing = false

    init(api: OrdersAPI, store: URL) {
        self.api = api
        self.store = store
        self.queue = (try? JSONDecoder().decode([Pending].self, from: Data(contentsOf: store))) ?? []
    }

    func submit(items: [String]) {
        queue.append(Pending(items: items))
        persist()
        Task { await flush() }
    }

    func flush() async {
        guard !flushing else { return }
        flushing = true
        defer { flushing = false }
        while let first = queue.first {
            do {
                try await api.post(path: "/orders", body: first.items)
                queue.removeFirst()
                persist()
            } catch {
                // Network error or timeout: try again shortly.
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func persist() {
        try? JSONEncoder().encode(queue).write(to: store)
    }
}
