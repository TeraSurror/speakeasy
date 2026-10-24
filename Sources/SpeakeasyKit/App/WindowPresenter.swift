import AppKit
import SwiftUI

/// Owns the welcome window. Status items are not touched here.
@MainActor
final class WindowPresenter {
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?

    func showSettings(model: AppModel) {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView().environmentObject(model)))
            window.title = "Speakeasy Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func showOnboarding(model: AppModel) {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let view = OnboardingView { [weak self] in
            model.settings.onboardingCompleted = true
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Welcome to Speakeasy"
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(window.contentViewController?.view.fittingSize ?? NSSize(width: 520, height: 480))
        window.center()
        onboardingWindow = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
