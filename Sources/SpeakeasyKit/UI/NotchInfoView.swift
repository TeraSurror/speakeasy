import SwiftUI

struct NotchInfoView: View {
    let appNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Some items are hidden by the notch", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(appNames.joined(separator: ", "))
                .fontWeight(.medium)
            Text("Hold ⌘ and drag them to the left of Speakeasy's | divider. They'll move into the hidden section, and you can reach them any time with the glass.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }
}
