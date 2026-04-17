import Foundation

@MainActor
final class URLCallbackCenter {
    static let shared = URLCallbackCenter()

    var handler: ((URL) -> Void)?

    private init() {}

    func handle(_ urls: [URL]) {
        for url in urls {
            handler?(url)
        }
    }
}
