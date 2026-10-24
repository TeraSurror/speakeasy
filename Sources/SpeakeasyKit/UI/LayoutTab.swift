import AppKit
import SwiftUI

/// Lists every discovered item in three columns; dragging an item to another column moves it in the real menu bar.
struct LayoutTab: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.accessibilityTrusted {
                columns
            } else {
                AccessibilityExplainer()
            }
        }
        .onAppear { model.refreshAccessibility() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshAccessibility() // the user may have just granted access in System Settings
        }
    }

    private var columns: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(Section.allCases, id: \.self) { section in
                    LayoutColumn(section: section)
                }
            }
            HStack(spacing: 10) {
                status
                Spacer()
                Button("Move overflow from notch") { model.moveOverflowFromNotch() }
                    .disabled(model.notchItems.isEmpty || isMoving)
                    .help("Moves items that are covered by the notch into the Hidden section.")
            }
        }
        .padding(16)
    }

    private var isMoving: Bool {
        if case .moving = model.moveStatus { return true }
        return false
    }

    @ViewBuilder private var status: some View {
        switch model.moveStatus {
        case .idle:
            Text("Drag an item to another column, or use its right-click menu.")
                .foregroundStyle(.secondary)
        case .moving(let name):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Moving \(name)…")
            }
        case .done(let message):
            Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension Section {
    var title: String {
        switch self {
        case .visible: "Visible"
        case .hidden: "Hidden"
        case .alwaysHidden: "Always Hidden"
        }
    }
}

private struct LayoutColumn: View {
    @EnvironmentObject var model: AppModel
    let section: Section
    @State private var isTargeted = false

    private var items: [MenuBarItem] { model.items.filter { $0.section == section } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.title).font(.headline)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(items) { item in
                        LayoutRow(item: item)
                    }
                    if items.isEmpty {
                        Text("Nothing here").foregroundStyle(.secondary).padding(8)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isTargeted ? 2 : 1))
            .dropDestination(for: String.self) { ids, _ in
                guard let id = ids.first else { return false }
                model.move(itemID: id, to: section)
                return true
            } isTargeted: { isTargeted = $0 }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(section.title) items")
    }
}

private struct LayoutRow: View {
    @EnvironmentObject var model: AppModel
    let item: MenuBarItem

    var body: some View {
        HStack(spacing: 6) {
            if let icon = model.icon(for: item) {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            } else {
                Image(systemName: "app").frame(width: 16, height: 16)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(item.appName).lineLimit(1)
                if let title = item.title {
                    Text(title).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if model.notchItems.contains(where: { $0.id == item.id }) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    .help("Hidden behind the notch")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .draggable(item.id)
        .contextMenu {
            ForEach(Section.allCases.filter { $0 != item.section }, id: \.self) { target in
                Button("Move to \(target.title)") { model.move(itemID: item.id, to: target) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Move to Visible") { model.move(itemID: item.id, to: .visible) }
        .accessibilityAction(named: "Move to Hidden") { model.move(itemID: item.id, to: .hidden) }
        .accessibilityAction(named: "Move to Always Hidden") { model.move(itemID: item.id, to: .alwaysHidden) }
    }
}

/// Shown before the system prompt, so the permission is never a surprise.
private struct AccessibilityExplainer: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Let Speakeasy move your menu bar items").font(.title3.bold())
            Text("""
                macOS has no API for rearranging other apps' menu bar items. Speakeasy does it the way you would: \
                by holding ⌘ and dragging the item with the pointer. Posting those mouse events requires \
                Accessibility access.

                Speakeasy only uses it while you move an item here, never reads what's on screen, and \
                puts the pointer back afterwards. Everything else works without it, and you can still ⌘-drag \
                items yourself.
                """)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)
            HStack {
                Button("Grant Access…") { model.requestAccessibility() }
                    .buttonStyle(.borderedProminent)
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
