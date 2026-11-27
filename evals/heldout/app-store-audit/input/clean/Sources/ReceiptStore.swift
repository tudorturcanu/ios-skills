import Foundation

/// Stores scanned receipt PDFs in the app's Documents directory.
final class ReceiptStore {
    private let defaults = UserDefaults.standard
    private let fm = FileManager.default

    private var documentsURL: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var sortOrder: String {
        get { defaults.string(forKey: "sortOrder") ?? "date" }
        set { defaults.set(newValue, forKey: "sortOrder") }
    }

    func save(pdf data: Data, name: String) throws -> URL {
        let url = documentsURL.appendingPathComponent("\(name).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Returns receipts newest first, using each file's modification date.
    func receipts() throws -> [URL] {
        let urls = try fm.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        return urls
            .filter { $0.pathExtension == "pdf" }
            .sorted { a, b in
                let da = (try? fm.attributesOfItem(atPath: a.path)[.modificationDate] as? Date) ?? .distantPast
                let db = (try? fm.attributesOfItem(atPath: b.path)[.modificationDate] as? Date) ?? .distantPast
                return da > db
            }
    }
}
