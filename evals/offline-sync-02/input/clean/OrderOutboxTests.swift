import XCTest

final class OrderOutboxTests: XCTestCase {
    func testTimeoutAfterCommitDoesNotDuplicate() async throws {
        let server = FakeServer()
        server.mode = .commitThenTimeout
        let outbox = OrderOutbox(api: server, store: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        await outbox.submit(items: ["coffee"])
        await outbox.flush()
        XCTAssertEqual(server.committedOrders.count, 1)
    }
}
