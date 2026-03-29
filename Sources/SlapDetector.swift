import AVFoundation
import Foundation

struct SlapMetrics {
    let peak: Float
    let rms: Float
    let crestFactor: Float
    let transientRatio: Float
    let zeroCrossingRate: Float
    let highEnergyFraction: Float
}

final class SlapDetector {
    struct Configuration {
        var peakMultiplier: Double
        var minPeakFloor: Double
        var minCrest: Double
        var minTransientRatio: Double
        var minZeroCrossingRate: Double
        var maxHighEnergyFraction: Double
        var cooldown: TimeInterval
    }

    var onDetection: ((SlapMetrics) -> Void)?
    var onStatus: ((String) -> Void)?

    var configuration = Configuration(
        peakMultiplier: 2.8,
        minPeakFloor: 0.055,
        minCrest: 4.5,
        minTransientRatio: 1.65,
        minZeroCrossingRate: 0.09,
        maxHighEnergyFraction: 0.18,
        cooldown: 0.15
    )

    private let engine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "LaptopSlap.analysis")
    private let lock = NSLock()

    private var isRunning = false
    private var noiseFloorRMS: Float = 0.008
    private var noiseFloorPeak: Float = 0.02
    private var lastTriggerTime: CFAbsoluteTime = 0

    func start() throws {
        guard !isRunning else { return }

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.analysisQueue.async {
                self?.process(buffer: buffer)
            }
        }

        engine.prepare()
        try engine.start()
        isRunning = true
        onStatus?("Microphone is live.")
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard
            let channelData = buffer.floatChannelData?[0]
        else {
            return
        }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 64 else { return }

        var sumSquares: Float = 0
        var diffSquares: Float = 0
        var peak: Float = 0
        var zeroCrossings = 0
        var highEnergySamples = 0
        var previous = channelData[0]

        for index in 0 ..< frameCount {
            let sample = channelData[index]
            let magnitude = abs(sample)
            sumSquares += sample * sample
            peak = max(peak, magnitude)

            if index > 0 {
                let diff = sample - previous
                diffSquares += diff * diff

                if (sample >= 0 && previous < 0) || (sample < 0 && previous >= 0) {
                    zeroCrossings += 1
                }
            }

            previous = sample
        }

        let rms = sqrt(sumSquares / Float(frameCount))
        let highEnergyThreshold = max(peak * 0.35, rms * 2.2)

        for index in 0 ..< frameCount {
            if abs(channelData[index]) >= highEnergyThreshold {
                highEnergySamples += 1
            }
        }

        let diffRMS = sqrt(diffSquares / Float(max(frameCount - 1, 1)))
        let crest = peak / max(rms, 0.0001)
        let transientRatio = diffRMS / max(rms, 0.0001)
        let zeroCrossingRate = Float(zeroCrossings) / Float(frameCount)
        let highEnergyFraction = Float(highEnergySamples) / Float(frameCount)

        updateNoiseFloor(rms: rms, peak: peak, crest: crest)

        let config = configuration
        let peakGate = max(
            Float(config.minPeakFloor),
            noiseFloorPeak * Float(config.peakMultiplier),
            noiseFloorRMS * Float(config.peakMultiplier + 0.7)
        )

        guard peak > peakGate else { return }
        guard crest > Float(config.minCrest) else { return }
        guard transientRatio > Float(config.minTransientRatio) else { return }
        guard zeroCrossingRate > Float(config.minZeroCrossingRate) else { return }
        guard highEnergyFraction < Float(config.maxHighEnergyFraction) else { return }
        guard shouldTrigger(cooldown: config.cooldown) else { return }

        let metrics = SlapMetrics(
            peak: peak,
            rms: rms,
            crestFactor: crest,
            transientRatio: transientRatio,
            zeroCrossingRate: zeroCrossingRate,
            highEnergyFraction: highEnergyFraction
        )

        DispatchQueue.main.async { [weak self] in
            self?.onDetection?(metrics)
        }
    }

    private func updateNoiseFloor(rms: Float, peak: Float, crest: Float) {
        lock.lock()
        defer { lock.unlock() }

        let rmsBlend: Float = rms < noiseFloorRMS * 2.2 ? 0.04 : 0.008
        noiseFloorRMS = ((1 - rmsBlend) * noiseFloorRMS) + (rmsBlend * rms)

        let peakBlend: Float = crest < 3.2 ? 0.06 : 0.01
        noiseFloorPeak = ((1 - peakBlend) * noiseFloorPeak) + (peakBlend * peak)
    }

    private func shouldTrigger(cooldown: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastTriggerTime >= cooldown else { return false }
        lastTriggerTime = now
        return true
    }
}
