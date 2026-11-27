import Foundation

// Test doubles only. The two reviewed methods are inserted from a verified checkout.
struct Status { let id: String }
struct TextValue { let string: String }
struct Draft { let content: String }

@MainActor final class DraftContext {
    var contents: [String] = []
    func insert(_ draft: Draft) { contents.append(draft.content) }
}

@MainActor final class EditorStore {
    enum Mode { case new, replyTo(status: Status) }
    let id: String
    let statusText: TextValue
    let succeeds: Bool
    var mode: Mode = .new
    var postingError: String? { succeeds ? nil : "injected failure" }
    init(_ id: String, text: String, succeeds: Bool) {
        self.id = id
        self.statusText = TextValue(string: text)
        self.succeeds = succeeds
    }
}

@MainActor final class Subject {
    let mainStore: EditorStore
    let followUpStores: [EditorStore]
    let context = DraftContext()
    var attempted: [String] = []
    var acknowledged: [String] = []
    var replyParents: [String] = []

    init(root: EditorStore, replies: [EditorStore]) {
        mainStore = root
        followUpStores = replies
    }

    private func postStatus(with model: EditorStore, isMainPost: Bool) async -> Status? {
        attempted.append(model.id)
        if case let .replyTo(status) = model.mode { replyParents.append(status.id) }
        guard model.succeeds else { return nil }
        acknowledged.append(model.id)
        return Status(id: model.id)
    }

    // INSERT_VERIFIED_METHODS

    func observe(name: String) async -> [String: Any] {
        let (status, _) = await postAllStatus()
        // Explicitly models handlePostingResult's nil-result branch (lines 166–167).
        // The SwiftUI handler, SwiftData persistence, and toast are not executed.
        if status == nil { saveDraftIfNeeded() }
        return [
            "name": name,
            "returned_status": status?.id as Any? ?? NSNull(),
            "attempted": attempted,
            "acknowledged": acknowledged,
            "reply_parents": replyParents,
            "draft_insertions": context.contents
        ]
    }
}

@main struct Probe {
    @MainActor static func main() async throws {
        var observations: [[String: Any]] = []
        for (name, successes, rootText) in [
            ("all_success", [true, true, true], "Root text"),
            ("root_failure", [false, true, true], "Root text"),
            ("first_reply_failure", [true, false, true], "Root text"),
            ("second_reply_failure", [true, true, false], "Root text"),
            ("blank_root_failure", [false], "  \n")
        ] {
            let root = EditorStore("root", text: rootText, succeeds: successes[0])
            let replies = successes.dropFirst().enumerated().map { index, succeeds in
                EditorStore("reply\(index + 1)", text: "Reply \(index + 1) text", succeeds: succeeds)
            }
            let subject = Subject(root: root, replies: replies)
            observations.append(await subject.observe(name: name))
        }
        let data = try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
