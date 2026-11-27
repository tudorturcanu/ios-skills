import Foundation

/// Mirrors the documented backend contract: `Idempotency-Key` is honored for 7 days and a repeated key
/// returns the original result without creating another order.
final class FakeServer: OrdersAPI {
    enum Mode { case ok, commitThenTimeout }
    var mode: Mode = .ok
    private(set) var committedOrders: [[String]] = []
    private var seenKeys: Set<String> = []
    private var timedOutOnce = false

    func post(path: String, body: [String], idempotencyKey: String) async throws {
        if !seenKeys.contains(idempotencyKey) {
            seenKeys.insert(idempotencyKey)
            committedOrders.append(body)
        }
        if mode == .commitThenTimeout && !timedOutOnce {
            timedOutOnce = true
            throw URLError(.timedOut)
        }
    }
}
