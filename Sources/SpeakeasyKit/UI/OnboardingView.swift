import SwiftUI

struct OnboardingView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Speakeasy").font(.title.bold())
            Text("Keep your menu bar short. Everything you tuck behind the divider stays one click away.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DragDemo()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                step("1", "Hold **⌘ Command** and drag a menu bar icon to the left of the **|** divider.")
                step("2", "Click the glass, or press **⌥⌘B**, to show or hide everything left of the divider.")
                step("3", "Right-click the glass for settings. Items hide again on their own after a few seconds.")
            }

            Button("Got it", action: onDone)
                .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(minWidth: 480, idealWidth: 520, minHeight: 440)
    }

    private func step(_ number: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.bold())
                .frame(width: 20, height: 20)
                .background(Circle().fill(.tint.opacity(0.2)))
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A static mock menu bar: an icon tucked to the left of the divider.
private struct DragDemo: View {
    private let slot: CGFloat = 40

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "bolt.fill").foregroundStyle(.tint).frame(width: slot)
            Rectangle().fill(.secondary).frame(width: 1.5, height: 16).padding(.horizontal, 8)
            Image(systemName: "wifi").frame(width: slot)
            Image(systemName: "battery.75").frame(width: slot)
            Image(systemName: "wineglass").frame(width: slot)
        }
        .frame(width: 320, height: 36)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }
}
