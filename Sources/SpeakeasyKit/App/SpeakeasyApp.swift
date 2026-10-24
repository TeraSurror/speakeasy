import SwiftUI

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()
    let controller = AppController()
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppEnvironment.shared.controller.start()
        }
    }
}

public struct SpeakeasyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    public init() {}

    public var body: some Scene {
        // Settings and the welcome guide are opened from the menu bar as plain windows (see WindowPresenter);
        // the Settings scene's action is unreliable for agent apps. A scene is still required here.
        SwiftUI.Settings { EmptyView() }
    }
}
