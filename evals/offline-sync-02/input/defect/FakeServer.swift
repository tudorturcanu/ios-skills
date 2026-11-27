import Foundation

/// Test double used by OrderOutboxTests. Mirrors production behavior reported by the backend team.
final class FakeServer: OrdersAPI {
    enum Mode { case ok, commitThenTimeout }
    var mode: Mode = .ok
    private(set) var committedOrders: [[String]] = []
    private var timedOutOnce = false

    func post(path: String, body: [String]) async throws {
        switch mode {
        case .ok:
            committedOrders.append(body)
        case .commitThenTimeout:
            committedOrders.append(body)          // server commits the order...
            if !timedOutOnce {
                timedOutOnce = true
                throw URLError(.timedOut)          // ...but the response is lost
            }
        }
    }
}
