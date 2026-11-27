import UIKit

final class GalleryCoordinator {
    private let nav: UINavigationController
    private let photos: [Photo]

    init(nav: UINavigationController, photos: [Photo]) {
        self.nav = nav
        self.photos = photos
    }

    func showDetail(for photo: Photo) {
        let vc = PhotoDetailViewController(photo: photo)
        nav.pushViewController(vc, animated: true)
    }

    // Back is handled by the navigation controller's standard pop;
    // no other code holds a reference to the detail controller.
}

struct Photo: Hashable {
    let id: String
    let url: URL
    let title: String
}
