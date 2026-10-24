import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleHiddenSection = Self(
        "toggleHiddenSection",
        default: .init(.b, modifiers: [.option, .command])
    )
}

public struct KeyboardShortcutsHotkeys: HotkeyRegistering {
    public init() {}

    private func name(for action: HotkeyAction) -> KeyboardShortcuts.Name {
        switch action {
        case .toggleHiddenSection: .toggleHiddenSection
        }
    }

    @MainActor
    public func setHandler(for action: HotkeyAction, _ handler: @escaping @MainActor () -> Void) {
        KeyboardShortcuts.onKeyUp(for: name(for: action)) {
            MainActor.assumeIsolated { handler() }
        }
    }

    @MainActor
    public func combo(for action: HotkeyAction) -> KeyCombo? {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name(for: action)) else { return nil }
        var mods = 0
        let flags = shortcut.modifiers
        if flags.contains(.command) { mods |= cmdKey }
        if flags.contains(.shift) { mods |= shiftKey }
        if flags.contains(.option) { mods |= optionKey }
        if flags.contains(.control) { mods |= controlKey }
        return KeyCombo(keyCode: shortcut.carbonKeyCode, carbonModifiers: mods)
    }
}

/// Checks a combo against the enabled macOS symbolic hotkeys (Spotlight, Mission Control, screenshots, ...).
/// Other apps' global hotkeys are not observable, so those can't be detected.
public struct SystemHotkeyConflictChecker: HotkeyConflictChecking {
    public init() {}

    public func conflict(for combo: KeyCombo) -> String? {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr,
              let list = unmanaged?.takeRetainedValue() as? [[String: Any]] else { return nil }
        let mask = cmdKey | shiftKey | optionKey | controlKey
        for entry in list {
            guard (entry[kHISymbolicHotKeyEnabled as String] as? Bool) == true,
                  let code = entry[kHISymbolicHotKeyCode as String] as? Int,
                  let mods = entry[kHISymbolicHotKeyModifiers as String] as? Int else { continue }
            if code == combo.keyCode && (mods & mask) == combo.carbonModifiers {
                return "This shortcut is already used by a macOS system shortcut."
            }
        }
        return nil
    }
}
