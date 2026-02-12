import Foundation
import AudioToolbox

@MainActor
final class SoundManager: ObservableObject {
    static let shared = SoundManager()

    static let availableSounds = [
        "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]

    var isSoundEnabled: Bool {
        if UserDefaults.standard.object(forKey: "playSendSound") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "playSendSound")
    }

    var selectedSoundName: String {
        get { UserDefaults.standard.string(forKey: "sendSoundName") ?? "Blow" }
        set { UserDefaults.standard.set(newValue, forKey: "sendSoundName") }
    }

    #if os(macOS)
    private var soundIDCache: [String: SystemSoundID] = [:]

    private func getSystemSoundID(for name: String) -> SystemSoundID? {
        if let cachedID = soundIDCache[name] {
            return cachedID
        }

        let systemSoundPath = "/System/Library/Sounds/\(name).aiff"
        let soundURL = URL(fileURLWithPath: systemSoundPath)

        var soundID: SystemSoundID = 0
        let status = AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)

        if status == noErr {
            soundIDCache[name] = soundID
            return soundID
        }

        return nil
    }
    #endif

    private init() {}

    func playSendSound() {
        guard isSoundEnabled else { return }

        #if os(macOS)
        if let soundID = getSystemSoundID(for: selectedSoundName) {
            AudioServicesPlaySystemSound(soundID)
        }
        #elseif os(iOS)
        // Play system sound and trigger haptic feedback
        AudioServicesPlaySystemSound(1001)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    func previewSound(_ soundName: String) {
        #if os(macOS)
        if let soundID = getSystemSoundID(for: soundName) {
            AudioServicesPlaySystemSound(soundID)
        }
        #elseif os(iOS)
        AudioServicesPlaySystemSound(1001)
        #endif
    }
}

#if os(iOS)
import UIKit
#endif
