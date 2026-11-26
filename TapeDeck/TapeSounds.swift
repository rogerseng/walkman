import AVFoundation

/// Tape deck sound effects, synthesised in code so the app ships no audio files.
///
/// The music itself is played by the system music player, so these sounds use an
/// audio session that mixes on top of it. It is a playback session so the app
/// stays awake behind the lock screen (see `keepAlive`), which also means the
/// sounds are not muted by the silent switch.
final class TapeSounds {
    enum Effect { case keyDown, keyUp, eject, insert }
    enum Loop { case hiss, whir }

    var enabled = true {
        didSet { applyLoop() }
    }

    /// While true, something is always playing, silence if need be. iOS suspends
    /// an app in the background unless it is playing audio, and the app has to
    /// stay awake to keep the lock screen tape in step with the music.
    var keepAlive = false {
        didSet {
            // Also restart the loop if the engine was stopped under us.
            if playingLoop != nil, !engine.isRunning { playingLoop = nil }
            applyLoop()
        }
    }

    private let engine = AVAudioEngine()
    private let fxNode = AVAudioPlayerNode()
    private let loopNode = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var effects: [Effect: AVAudioPCMBuffer] = [:]
    private var loops: [Loop: AVAudioPCMBuffer] = [:]
    private var currentLoop: Loop?
    private var playingLoop: AVAudioPCMBuffer?
    private lazy var silentLoop = buffer(Self.silence(1.0))
    private var configured = false

    init() {
        engine.attach(fxNode)
        engine.attach(loopNode)
        engine.connect(fxNode, to: engine.mainMixerNode, format: format)
        engine.connect(loopNode, to: engine.mainMixerNode, format: format)

        effects[.keyDown] = buffer(Self.keyDown())
        effects[.keyUp] = buffer(Self.keyUp())
        effects[.eject] = buffer(Self.eject())
        effects[.insert] = buffer(Self.insert())
        loops[.hiss] = buffer(Self.hiss())
        loops[.whir] = buffer(Self.whir())
    }

    func play(_ effect: Effect) {
        guard enabled, let buffer = effects[effect], start() else { return }
        fxNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        fxNode.play()
    }

    func setLoop(_ loop: Loop?) {
        guard loop != currentLoop else { return }
        currentLoop = loop
        applyLoop()
    }

    private func applyLoop() {
        var wanted: AVAudioPCMBuffer?
        var volume: Float = 1
        if enabled, let loop = currentLoop {
            wanted = loops[loop]
            volume = loop == .hiss ? 0.5 : 0.9
        } else if keepAlive {
            wanted = silentLoop
        }
        guard wanted !== playingLoop else { return }
        guard let wanted, start() else {
            if engine.isRunning { loopNode.stop() }
            playingLoop = nil
            return
        }
        loopNode.volume = volume
        loopNode.scheduleBuffer(wanted, at: nil, options: [.loops, .interrupts], completionHandler: nil)
        loopNode.play()
        playingLoop = wanted
    }

    /// Starts the engine if needed. Returns false when audio is unavailable.
    private func start() -> Bool {
        if !configured {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? session.setActive(true)
            configured = true
        }
        if engine.isRunning { return true }
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    private func buffer(_ samples: [Float]) -> AVAudioPCMBuffer {
        let count = AVAudioFrameCount(samples.count)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        buffer.frameLength = count
        let channel = buffer.floatChannelData![0]
        for i in 0..<samples.count {
            channel[i] = max(-1, min(1, samples[i]))
        }
        return buffer
    }

    // MARK: Synthesis

    private static let rate = 44_100.0

    private static func silence(_ seconds: Double) -> [Float] {
        [Float](repeating: 0, count: Int(seconds * rate))
    }

    /// Adds one mechanical knock: a decaying low tone plus a burst of noise.
    private static func knock(_ s: inout [Float], at start: Double, freq: Double,
                              decay: Double, noise: Double, gain: Double) {
        let first = Int(start * rate)
        guard first < s.count else { return }
        for i in first..<s.count {
            let t = Double(i - first) / rate
            let tone = sin(2 * .pi * freq * t) * exp(-t * decay)
            let grit = Double.random(in: -1...1) * noise * exp(-t * decay * 3)
            s[i] += Float(gain * (tone + grit))
        }
    }

    private static func keyDown() -> [Float] {
        var s = silence(0.22)
        knock(&s, at: 0, freq: 110, decay: 40, noise: 0.8, gain: 0.7)
        knock(&s, at: 0.05, freq: 230, decay: 70, noise: 0.5, gain: 0.35)
        return s
    }

    private static func keyUp() -> [Float] {
        var s = silence(0.16)
        knock(&s, at: 0, freq: 180, decay: 60, noise: 0.6, gain: 0.5)
        return s
    }

    private static func eject() -> [Float] {
        var s = silence(0.6)
        knock(&s, at: 0, freq: 95, decay: 30, noise: 0.9, gain: 0.8)
        knock(&s, at: 0.12, freq: 300, decay: 50, noise: 0.6, gain: 0.35)
        knock(&s, at: 0.2, freq: 620, decay: 18, noise: 0.1, gain: 0.12) // door spring
        knock(&s, at: 0.3, freq: 150, decay: 45, noise: 0.5, gain: 0.4)
        return s
    }

    private static func insert() -> [Float] {
        var s = silence(0.5)
        knock(&s, at: 0, freq: 400, decay: 80, noise: 0.7, gain: 0.3)   // cassette drops in
        knock(&s, at: 0.18, freq: 85, decay: 28, noise: 0.9, gain: 0.8) // door shuts
        knock(&s, at: 0.24, freq: 240, decay: 70, noise: 0.5, gain: 0.3)
        return s
    }

    /// Quiet tape hiss with a trace of motor hum. Loops seamlessly.
    private static func hiss() -> [Float] {
        var s = silence(2.0)
        var previous = 0.0
        for i in 0..<s.count {
            let t = Double(i) / rate
            let white = Double.random(in: -1...1)
            let bright = white - previous * 0.7 // tilt the noise toward the highs
            previous = white
            let hum = sin(2 * .pi * 120 * t) * 0.004
            s[i] = Float(bright * 0.012 + hum)
        }
        return s
    }

    /// Fast winding: rumbling noise with a motor whine. Loops seamlessly.
    private static func whir() -> [Float] {
        var s = silence(1.0)
        var low = 0.0
        for i in 0..<s.count {
            let t = Double(i) / rate
            low += (Double.random(in: -1...1) - low) * 0.15
            let flutter = 0.7 + 0.3 * sin(2 * .pi * 24 * t)
            let whine = sin(2 * .pi * 880 * t) * 0.03 + sin(2 * .pi * 1320 * t) * 0.015
            s[i] = Float(low * 0.22 * flutter + whine)
        }
        return s
    }
}
