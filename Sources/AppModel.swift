import AVFoundation
import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    private enum DefaultsKey {
        static let selectedAudioPath = "selectedAudioPath"
        static let peakMultiplier = "peakMultiplier"
        static let minPeakFloor = "minPeakFloor"
        static let minCrest = "minCrest"
        static let minTransientRatio = "minTransientRatio"
        static let minZeroCrossingRate = "minZeroCrossingRate"
        static let maxHighEnergyFraction = "maxHighEnergyFraction"
        static let cooldownMilliseconds = "cooldownMilliseconds"
    }

    private static let defaultMoanPath = "/Users/v/Downloads/usb-moan-app/sounds/moan.mp3"
    private let defaults = UserDefaults.standard
    private var isHydrating = true

    @Published var selectedAudioURL: URL? {
        didSet {
            guard !isHydrating else { return }
            defaults.set(selectedAudioURL?.path, forKey: DefaultsKey.selectedAudioPath)
        }
    }
    @Published var isListening = false
    @Published var statusMessage = "Choose an MP3 and start listening."
    @Published var detectionCount = 0
    @Published var lastTriggerSummary = "No slap detected yet."

    @Published var peakMultiplier = 2.8 { didSet { persistTuningValue(peakMultiplier, key: DefaultsKey.peakMultiplier) } }
    @Published var minPeakFloor = 0.055 { didSet { persistTuningValue(minPeakFloor, key: DefaultsKey.minPeakFloor) } }
    @Published var minCrest = 4.5 { didSet { persistTuningValue(minCrest, key: DefaultsKey.minCrest) } }
    @Published var minTransientRatio = 1.65 { didSet { persistTuningValue(minTransientRatio, key: DefaultsKey.minTransientRatio) } }
    @Published var minZeroCrossingRate = 0.09 { didSet { persistTuningValue(minZeroCrossingRate, key: DefaultsKey.minZeroCrossingRate) } }
    @Published var maxHighEnergyFraction = 0.18 { didSet { persistTuningValue(maxHighEnergyFraction, key: DefaultsKey.maxHighEnergyFraction) } }
    @Published var cooldownMilliseconds = 150.0 { didSet { persistTuningValue(cooldownMilliseconds, key: DefaultsKey.cooldownMilliseconds) } }

    private let detector = SlapDetector()
    private let player = OverlayAudioPlayer()

    init() {
        hydratePersistedState()

        detector.onDetection = { [weak self] metrics in
            guard let self else { return }
            self.detectionCount += 1
            self.lastTriggerSummary = String(
                format: "peak %.3f | crest %.2f | transient %.2f | zcr %.2f | hf %.2f",
                metrics.peak,
                metrics.crestFactor,
                metrics.transientRatio,
                metrics.zeroCrossingRate,
                metrics.highEnergyFraction
            )

            do {
                try self.player.play(url: self.requireSelectedAudioURL())
            } catch {
                self.statusMessage = "Failed to play audio: \(error.localizedDescription)"
            }
        }

        detector.onStatus = { [weak self] message in
            self?.statusMessage = message
        }

        applySettings()
        isHydrating = false
    }

    func chooseAudioFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.mp3, .mpeg4Audio, .wav, .aiff]
        panel.message = "Choose the sound that should play on a slap."

        if panel.runModal() == .OK, let url = panel.url {
            selectedAudioURL = url
            statusMessage = "Loaded \(url.lastPathComponent)."
        }
    }

    func useDefaultMoan() {
        guard FileManager.default.fileExists(atPath: Self.defaultMoanPath) else {
            statusMessage = "Default moan.mp3 was not found."
            return
        }

        selectedAudioURL = URL(fileURLWithPath: Self.defaultMoanPath)
        statusMessage = "Loaded default moan.mp3."
    }

    func previewSound() {
        do {
            try player.play(url: requireSelectedAudioURL())
            statusMessage = "Previewing \(soundName)."
        } catch {
            statusMessage = "Failed to preview audio: \(error.localizedDescription)"
        }
    }

    func toggleListening() async {
        if isListening {
            detector.stop()
            isListening = false
            statusMessage = "Listening stopped."
            return
        }

        guard selectedAudioURL != nil else {
            statusMessage = "Choose an audio file first."
            return
        }

        let granted = await requestMicrophoneAccess()
        guard granted else {
            statusMessage = "Microphone access was denied."
            return
        }

        applySettings()

        do {
            try detector.start()
            isListening = true
            statusMessage = "Listening for short impact sounds."
        } catch {
            statusMessage = "Failed to start microphone: \(error.localizedDescription)"
        }
    }

    func applySettings() {
        detector.configuration = SlapDetector.Configuration(
            peakMultiplier: peakMultiplier,
            minPeakFloor: minPeakFloor,
            minCrest: minCrest,
            minTransientRatio: minTransientRatio,
            minZeroCrossingRate: minZeroCrossingRate,
            maxHighEnergyFraction: maxHighEnergyFraction,
            cooldown: cooldownMilliseconds / 1_000
        )
    }

    func resetTuning() {
        peakMultiplier = 2.8
        minPeakFloor = 0.055
        minCrest = 4.5
        minTransientRatio = 1.65
        minZeroCrossingRate = 0.09
        maxHighEnergyFraction = 0.18
        cooldownMilliseconds = 150.0
        applySettings()
        statusMessage = "Detection tuning reset to defaults."
    }

    var soundName: String {
        selectedAudioURL?.lastPathComponent ?? "No file selected"
    }

    var isUsingDefaultMoan: Bool {
        selectedAudioURL?.path == Self.defaultMoanPath
    }

    var listeningLabel: String {
        isListening ? "Armed" : "Idle"
    }

    var listeningTint: NSColor {
        isListening ? .systemGreen : .secondaryLabelColor
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requireSelectedAudioURL() throws -> URL {
        guard let selectedAudioURL else {
            throw NSError(
                domain: "LaptopSlap",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No audio file selected."]
            )
        }

        return selectedAudioURL
    }

    private func hydratePersistedState() {
        if
            let persistedPath = defaults.string(forKey: DefaultsKey.selectedAudioPath),
            FileManager.default.fileExists(atPath: persistedPath)
        {
            selectedAudioURL = URL(fileURLWithPath: persistedPath)
            statusMessage = "Loaded \(selectedAudioURL?.lastPathComponent ?? "saved sound")."
        } else if FileManager.default.fileExists(atPath: Self.defaultMoanPath) {
            selectedAudioURL = URL(fileURLWithPath: Self.defaultMoanPath)
            statusMessage = "Loaded default moan.mp3."
        }

        peakMultiplier = tunedValue(forKey: DefaultsKey.peakMultiplier, fallback: 2.8)
        minPeakFloor = tunedValue(forKey: DefaultsKey.minPeakFloor, fallback: 0.055)
        minCrest = tunedValue(forKey: DefaultsKey.minCrest, fallback: 4.5)
        minTransientRatio = tunedValue(forKey: DefaultsKey.minTransientRatio, fallback: 1.65)
        minZeroCrossingRate = tunedValue(forKey: DefaultsKey.minZeroCrossingRate, fallback: 0.09)
        maxHighEnergyFraction = tunedValue(forKey: DefaultsKey.maxHighEnergyFraction, fallback: 0.18)
        cooldownMilliseconds = tunedValue(forKey: DefaultsKey.cooldownMilliseconds, fallback: 150.0)
    }

    private func tunedValue(forKey key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }

    private func persistTuningValue(_ value: Double, key: String) {
        guard !isHydrating else { return }
        defaults.set(value, forKey: key)
        applySettings()
    }
}
