import UIKit

enum Route: Equatable {
    case recipe(id: Int)
    case collection(slug: String)
}

struct DeepLinkRouter {
    static let universalHost = "links.trailmix.example"
    static let customScheme = "trailmix"

    static func route(for url: URL) -> Route? {
        switch url.scheme {
        case "https":
            guard url.host == universalHost else { return nil }
            return parse(pathComponents: url.pathComponents.filter { $0 != "/" })
        case customScheme:
            // trailmix://recipes/42 -> host = "recipes", path = "/42"
            var parts = [url.host ?? ""]
            parts += url.pathComponents.filter { $0 != "/" }
            return parse(pathComponents: parts)
        default:
            return nil
        }
    }

    private static func parse(pathComponents p: [String]) -> Route? {
        guard let first = p.first else { return nil }
        switch first {
        case "recipes":
            guard p.count == 2, let id = Int(p[1]) else { return nil }
            return .recipe(id: id)
        case "collections":
            guard p.count == 2 else { return nil }
            return .collection(slug: p[1])
        default:
            return nil
        }
    }
}
