import AppKit

@MainActor
final class SoundPlayer: NSObject, NSSoundDelegate {
    static let shared = SoundPlayer()

    private var activeSounds: [NSSound] = []

    private override init() {}

    func play(soundName: String) {
        if soundName == "Default" {
            NSSound.beep()
            return
        }

        guard let sound = NSSound(named: NSSound.Name(soundName)) else {
            NSSound.beep()
            return
        }

        sound.delegate = self
        activeSounds.append(sound)
        sound.play()
    }

    func preview(soundName: String) {
        play(soundName: soundName)
    }

    nonisolated func sound(
        _ sound: NSSound,
        didFinishPlaying finishedPlaying: Bool
    ) {
        Task { @MainActor in
            activeSounds.removeAll { $0 === sound }
        }
    }
}
