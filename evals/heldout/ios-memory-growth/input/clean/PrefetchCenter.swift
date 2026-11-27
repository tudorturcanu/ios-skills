import UIKit

/// Loads and decodes full-size images. Process-wide singleton.
final class PrefetchCenter {
    static let shared = PrefetchCenter()
    private init() {}

    typealias Handler = (_ photoID: String, _ image: UIImage) -> Void

    private var handlers: [UUID: Handler] = [:]
    private let queue = DispatchQueue(label: "prefetch", qos: .userInitiated)

    /// Register interest in decoded images. Handlers are called on the main thread.
    /// Returns a token; the caller must pass it to `removeObserver` when done.
    /// Must be called on the main thread.
    func observe(_ handler: @escaping Handler) -> UUID {
        let token = UUID()
        handlers[token] = handler
        return token
    }

    func removeObserver(_ token: UUID) {
        handlers[token] = nil
    }

    func load(_ photo: Photo) {
        queue.async { [weak self] in
            guard let data = try? Data(contentsOf: photo.url),
                  let image = UIImage(data: data)?.preparingForDisplay() else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                for handler in self.handlers.values { handler(photo.id, image) }
            }
        }
    }
}
