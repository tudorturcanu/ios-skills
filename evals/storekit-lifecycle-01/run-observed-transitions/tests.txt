import XCTest
@testable import StoreKitProbe

final class ProbeTests: XCTestCase {
    @MainActor func testLocalLifecycle() async throws {
        XCTAssertEqual(ProcessInfo.processInfo.environment["IOS_SKILL_HOSTED_TEST"], "1")
        await ProbeController().runProbe()
        let data = try Data(contentsOf: URL.documentsDirectory.appending(path: "results.json"))
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(result["passed"] as? Bool, true, String(decoding: data, as: UTF8.self))
    }
}
