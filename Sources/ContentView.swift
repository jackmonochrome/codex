import Foundation
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showAdvancedTuning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard
                soundCard
                statusCard
                tuningCard
            }
            .padding(20)
        }
        .frame(width: 700, height: 760)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.95, blue: 0.92),
                    Color(red: 0.93, green: 0.94, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LaptopSlap")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("A tiny desktop app that listens for short taps on the laptop body and fires your moan instantly, even when the previous one is still playing.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                statusBadge
            }

            HStack(spacing: 12) {
                Button(appModel.isListening ? "Stop Listening" : "Start Listening") {
                    Task {
                        await appModel.toggleListening()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

                Button("Preview Sound") {
                    appModel.previewSound()
                }
                .controlSize(.large)
                .disabled(appModel.selectedAudioURL == nil)
            }
        }
        .cardStyle()
    }

    private var soundCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sound")
                .font(.title3.weight(.semibold))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appModel.soundName)
                        .font(.headline)
                    Text(appModel.isUsingDefaultMoan ? "Using your default moan." : "Custom sound selected.")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button("Choose Audio") {
                    appModel.chooseAudioFile()
                }

                Button("Use Default Moan") {
                    appModel.useDefaultMoan()
                }
            }
        }
        .cardStyle()
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.title3.weight(.semibold))

            HStack(spacing: 14) {
                statPill(title: "Detections", value: "\(appModel.detectionCount)")
                statPill(title: "Mode", value: appModel.listeningLabel)
            }

            Text(appModel.statusMessage)
                .fixedSize(horizontal: false, vertical: true)

            Text(appModel.lastTriggerSummary)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    private var tuningCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Detection")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Reset Defaults") {
                    appModel.resetTuning()
                }
            }

            Text("The detector favors sharp, short impacts over speech. If it still catches talking, tighten the advanced values below.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DisclosureGroup(showAdvancedTuning ? "Hide Advanced Tuning" : "Show Advanced Tuning", isExpanded: $showAdvancedTuning) {
                tuningGroup
                    .padding(.top, 12)
            }
        }
        .cardStyle()
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(appModel.listeningTint))
                .frame(width: 10, height: 10)
            Text(appModel.listeningLabel)
                .font(.headline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var tuningGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            sliderRow(
                title: "Peak Gate",
                value: $appModel.peakMultiplier,
                range: 1.5 ... 5.0,
                format: "%.2f"
            )

            sliderRow(
                title: "Minimum Peak",
                value: $appModel.minPeakFloor,
                range: 0.01 ... 0.15,
                format: "%.3f"
            )

            sliderRow(
                title: "Crest Factor",
                value: $appModel.minCrest,
                range: 2.5 ... 8.0,
                format: "%.2f"
            )

            sliderRow(
                title: "Transient Ratio",
                value: $appModel.minTransientRatio,
                range: 1.0 ... 3.5,
                format: "%.2f"
            )

            sliderRow(
                title: "Zero Crossing",
                value: $appModel.minZeroCrossingRate,
                range: 0.02 ... 0.25,
                format: "%.2f"
            )

            sliderRow(
                title: "High-Energy Cap",
                value: $appModel.maxHighEnergyFraction,
                range: 0.05 ... 0.40,
                format: "%.2f"
            )

            sliderRow(
                title: "Cooldown ms",
                value: $appModel.cooldownMilliseconds,
                range: 60 ... 350,
                format: "%.0f"
            )
        }
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
            }

            Slider(value: value, in: range)
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
    }
}
