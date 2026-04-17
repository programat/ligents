import Foundation

@MainActor
final class AppActivationCenter {
    static let shared = AppActivationCenter()

    var handler: (() -> Void)?

    private init() {}

    func handleDidBecomeActive() {
        handler?()
    }
}
