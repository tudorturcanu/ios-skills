import UIKit

final class PhotoDetailViewController: UIViewController {
    private let photo: Photo
    private let imageView = UIImageView()
    private var currentImage: UIImage?

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

        PrefetchCenter.shared.observe { photoID, image in
            guard photoID == self.photo.id else { return }
            self.currentImage = image
            self.imageView.image = image
        }
        PrefetchCenter.shared.load(photo)
    }
}
