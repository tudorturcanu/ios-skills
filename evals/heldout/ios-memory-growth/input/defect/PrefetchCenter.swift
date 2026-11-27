import UIKit

/// Loads and decodes full-size images. Process-wide singleton.
final class PrefetchCenter {
    static let shared = PrefetchCenter()
    private init() {}

    typealias Handler = (_ photoID: String, _ image: UIImage) -> Void

    private var handlers: [Handler] = []
    private let queue = DispatchQueue(label: "prefetch", qos: .userInitiated)

    /// Register interest in decoded images. Handlers are called on the main thread.
    func observe(_ handler: @escaping Handler) {
        handlers.append(handler)
    }

    func load(_ photo: Photo) {
        queue.async {
            guard let data = try? Data(contentsOf: photo.url),
                  let image = UIImage(data: data)?.preparingForDisplay() else { return }
            DispatchQueue.main.async {
                for handler in self.handlers { handler(photo.id, image) }
            }
        }
    }
}
