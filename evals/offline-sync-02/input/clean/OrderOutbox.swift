import Foundation

protocol OrdersAPI {
    func post(path: String, body: [String], idempotencyKey: String) async throws
}

/// Durable queue for orders created while offline or on a flaky network.
actor OrderOutbox {
    struct Pending: Codable {
        let operationID: UUID      // generated once at creation, persisted with the order
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
        queue.append(Pending(operationID: UUID(), items: items))
        persist()
        Task { await flush() }
    }

    func flush() async {
        guard !flushing else { return }
        flushing = true
        defer { flushing = false }
        var delay: UInt64 = 1_000_000_000
        while let first = queue.first {
            do {
                try await api.post(path: "/orders", body: first.items, idempotencyKey: first.operationID.uuidString)
                queue.removeFirst()
                persist()
                delay = 1_000_000_000
            } catch {
                try? await Task.sleep(nanoseconds: delay)
                delay = min(delay * 2, 60_000_000_000)
            }
        }
    }

    private func persist() {
        try? JSONEncoder().encode(queue).write(to: store)
    }
}
