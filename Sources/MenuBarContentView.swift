import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(appModel.listeningTint))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appModel.listeningLabel)
                        .font(.headline)
                    Text(appModel.soundName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Button(appModel.isListening ? "Stop Listening" : "Start Listening") {
                Task {
                    await appModel.toggleListening()
                }
            }
            .keyboardShortcut(.defaultAction)

            Button("Preview Sound") {
                appModel.previewSound()
            }
            .disabled(appModel.selectedAudioURL == nil)

            Divider()

            Text("Detections: \(appModel.detectionCount)")
                .font(.caption)
            Text(appModel.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 260)
    }
}
