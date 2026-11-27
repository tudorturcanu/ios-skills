import UIKit

final class PhotoDetailViewController: UIViewController {
    private let photo: Photo
    private let imageView = UIImageView()
    private var observerToken: UUID?

    init(photo: Photo) {
        self.photo = photo
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = photo.title
        view.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.frame = view.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(imageView)

        observerToken = PrefetchCenter.shared.observe { [weak self] photoID, image in
            guard let self, photoID == self.photo.id else { return }
            self.imageView.image = image
        }
        PrefetchCenter.shared.load(photo)
    }

    deinit {
        // deinit runs on the main thread for a UIViewController.
        if let observerToken { PrefetchCenter.shared.removeObserver(observerToken) }
    }
}
