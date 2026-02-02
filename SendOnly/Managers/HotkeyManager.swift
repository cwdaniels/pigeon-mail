import Foundation
import Carbon
import AppKit
import Combine
import AudioToolbox

@MainActor
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    @Published var isHotkeyRegistered = false
    @Published var lastError: String?

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    // Available system sounds for send
    static let availableSounds = [
        "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]

    // Default hotkey: ⌘⌥⇧M (Cmd+Option+Shift+M)
    var hotkeyModifiers: UInt32 {
        get { UInt32(UserDefaults.standard.integer(forKey: "hotkeyModifiers").nonZero ?? Int(cmdKey | optionKey | shiftKey)) }
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkeyModifiers") }
    }

    var hotkeyKeyCode: UInt32 {
        get { UInt32(UserDefaults.standard.integer(forKey: "hotkeyKeyCode").nonZero ?? kVK_ANSI_M) }
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkeyKeyCode") }
    }

    var selectedSoundName: String {
        get { UserDefaults.standard.string(forKey: "sendSoundName") ?? "Blow" }
        set { UserDefaults.standard.set(newValue, forKey: "sendSoundName") }
    }

    private init() {}

    // MARK: - Send Sound

    var isSoundEnabled: Bool {
        // Default to true if not set
        if UserDefaults.standard.object(forKey: "playSendSound") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "playSendSound")
    }

    private var soundIDCache: [String: SystemSoundID] = [:]

    private func getSystemSoundID(for name: String) -> SystemSoundID? {
        // Check cache first
        if let cachedID = soundIDCache[name] {
            return cachedID
        }

        // Try to create sound from system sounds directory
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

    func playSendSound() {
        guard isSoundEnabled else { return }

        if let soundID = getSystemSoundID(for: selectedSoundName) {
            AudioServicesPlaySystemSound(soundID)
        }
    }

    func previewSound(_ soundName: String) {
        if let soundID = getSystemSoundID(for: soundName) {
            AudioServicesPlaySystemSound(soundID)
        }
    }

    // MARK: - Register Global Hotkey

    func registerGlobalHotkey() {
        // Unregister any existing hotkey first
        unregisterGlobalHotkey()

        // Define the hotkey signature
        let hotKeyID = EventHotKeyID(signature: OSType(0x534E444F), id: 1) // "SNDO" + id 1

        // Set up the event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                Task { @MainActor in
                    HotkeyManager.shared.hotkeyPressed()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        guard status == noErr else {
            lastError = "Failed to install event handler: \(status)"
            return
        }

        // Register the hotkey
        var hotKeyRefLocal: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            hotkeyKeyCode,
            hotkeyModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefLocal
        )

        guard registerStatus == noErr else {
            lastError = "Failed to register hotkey: \(registerStatus)"
            return
        }

        hotKeyRef = hotKeyRefLocal
        isHotkeyRegistered = true
        lastError = nil
    }

    func unregisterGlobalHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        isHotkeyRegistered = false
    }

    // MARK: - Hotkey Action

    private func hotkeyPressed() {
        // Bring app to front and open compose window
        NSApplication.shared.activate(ignoringOtherApps: true)
        openComposeWindow()
    }

    func openComposeWindow() {
        // First, check if compose window already exists and show it
        for window in NSApplication.shared.windows {
            if window.title == "Compose Email" || window.identifier?.rawValue == "compose" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }

        // No existing window - post notification for app to create one
        NotificationCenter.default.post(name: .openComposeWindow, object: nil)
    }

    // MARK: - Hotkey Configuration

    func setHotkey(keyCode: UInt32, modifiers: UInt32) {
        hotkeyKeyCode = keyCode
        hotkeyModifiers = modifiers
        registerGlobalHotkey()
    }

    var hotkeyDisplayString: String {
        var parts: [String] = []

        if hotkeyModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if hotkeyModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if hotkeyModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if hotkeyModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }

        parts.append(keyCodeToString(hotkeyKeyCode))

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        default: return "?"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openComposeWindow = Notification.Name("openComposeWindow")
}
