import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            AppearanceTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            HotkeysTab()
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 460)
    }
}

// MARK: - Building blocks

private struct IconBadge: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color.gradient))
            .accessibilityHidden(true)
    }
}

/// A System Settings–style row: colored icon, title with optional detail, control on the right.
private struct SettingRow<Control: View>: View {
    let symbol: String
    let color: Color
    let title: String
    var detail: String?
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.vertical, 2)
    }
}

private func switchToggle(_ title: String, isOn: Binding<Bool>) -> some View {
    Toggle(title, isOn: isOn)
        .labelsHidden()
        .toggleStyle(.switch)
}

// MARK: - General

private struct GeneralTab: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            SwiftUI.Section {
                SettingRow(symbol: "timer", color: .orange, title: "Hide automatically",
                           detail: "Tuck the hidden items away again after a short while.") {
                    switchToggle("Hide automatically", isOn: $model.settings.rehideEnabled)
                }
                SettingRow(symbol: "hourglass", color: .blue, title: "Delay") {
                    HStack(spacing: 8) {
                        Slider(value: $model.settings.rehideDelay, in: Settings.rehideDelayRange, step: 1)
                            .frame(width: 150)
                            .accessibilityLabel("Auto-rehide delay in seconds")
                        Text("\(Int(model.settings.rehideDelay)) s")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                .disabled(!model.settings.rehideEnabled)
                SettingRow(symbol: "cursorarrow.click.2", color: .purple, title: "Hide when I click away",
                           detail: "Also hide when you click outside the menu bar or switch apps.") {
                    switchToggle("Hide when I click away", isOn: $model.settings.rehideOnClickOutside)
                }
            } header: {
                Text("Auto-rehide")
            }

            SwiftUI.Section {
                SettingRow(symbol: "power", color: .green, title: "Launch at login",
                           detail: model.launchAtLoginError ?? "Open Speakeasy automatically when you log in.") {
                    switchToggle("Launch at login", isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                }
            } header: {
                Text("Startup")
            }

            SwiftUI.Section {
                SettingRow(symbol: "hand.wave.fill", color: .pink, title: "Welcome guide",
                           detail: "See again how to arrange your menu bar.") {
                    Button("Show…") { model.showWelcome() }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { model.refreshLaunchAtLogin() }
    }
}

// MARK: - Appearance

private struct AppearanceTab: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            SwiftUI.Section {
                HStack(spacing: 12) {
                    ForEach(ToggleIcon.allCases) { icon in
                        IconCard(icon: icon, isSelected: model.settings.toggleIcon == icon) {
                            model.settings.toggleIcon = icon
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Toggle icon")
            }

            SwiftUI.Section {
                SettingRow(symbol: "sparkles", color: .teal, title: "Slide animation",
                           detail: "Items glide in and out when you show or hide them. Off when Reduce Motion is on.") {
                    switchToggle("Slide animation", isOn: $model.settings.animateTransitions)
                }
                SettingRow(symbol: "rectangle.split.2x1", color: .gray, title: "Divider",
                           detail: "Show a thin line between hidden and visible items while revealed.") {
                    switchToggle("Divider", isOn: $model.settings.showSeparator)
                }
            } header: {
                Text("Behavior")
            }
        }
        .formStyle(.grouped)
    }
}

private struct IconCard: View {
    let icon: ToggleIcon
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    Image(systemName: icon.symbolName(isHidden: true))
                    Image(systemName: icon.symbolName(isHidden: false))
                }
                .font(.system(size: 17))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.quaternary))
                Text(icon.title)
                    .font(.callout)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Hotkeys

private struct HotkeysTab: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            SwiftUI.Section {
                SettingRow(symbol: "command", color: .indigo, title: "Show / hide hidden items",
                           detail: "Works from anywhere. Default is ⌥⌘B.") {
                    KeyboardShortcuts.Recorder(for: .toggleHiddenSection) { _ in
                        model.refreshHotkeyConflict()
                    }
                }
                if let conflict = model.hotkeyConflict {
                    Label(conflict, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Shortcuts")
            } footer: {
                Text("Conflicts with other apps' global shortcuts can't be detected.")
            }
        }
        .formStyle(.grouped)
        .onAppear { model.refreshHotkeyConflict() }
    }
}

// MARK: - About

private struct AboutTab: View {
    @EnvironmentObject var model: AppModel
    @State private var copied = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wineglass")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 84, height: 84)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Speakeasy").font(.title.bold())
                Text("Version \(Diagnostics.appVersion)").foregroundStyle(.secondary)
            }
            Text("The good stuff is behind a hidden door.")
                .italic()
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.diagnostics(), forType: .string)
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy Diagnostics", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                Button(role: .destructive) {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit Speakeasy", systemImage: "power")
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
