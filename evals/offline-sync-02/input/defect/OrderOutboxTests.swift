import XCTest

final class OrderOutboxTests: XCTestCase {
    func testQueuedOrderIsSentOnce() async throws {
        let server = FakeServer()
        let outbox = OrderOutbox(api: server, store: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        await outbox.submit(items: ["coffee"])
        await outbox.flush()
        XCTAssertEqual(server.committedOrders.count, 1)
    }
}
