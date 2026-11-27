import AVFoundation
import UIKit

/// Tape deck sound effects, synthesised in code so the app ships no audio files.
///
/// The music itself is played by the system music player, so these sounds use an
/// audio session that mixes on top of it. It is a playback session so the hiss
/// carries on behind the lock screen, which also means the sounds are not muted
/// by the silent switch.
final class TapeSounds {
    enum Effect { case keyDown, keyUp, eject, insert, motorUp, motorDown }
    enum Loop { case hiss, whir, reverse }

    var enabled = true {
        didSet { applyLoop() }
    }

    /// Tape hiss can be turned off on its own, leaving the mechanical sounds.
    var hissEnabled = true {
        didSet { if hissEnabled != oldValue { applyLoop() } }
    }

    /// Set while a tape is in. It only makes sure the audible loop (hiss or
    /// motor) is running; it never plays silence. iOS keeps an app awake in
    /// the background only while it is making sound the listener can hear, and
    /// App Review rejects apps that play silence to stay awake. So the lock
    /// screen tape keeps in step with the music while the hiss is on, and
    /// otherwise shows the tape as it was when the app was left.
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
    /// Speeds the winding sounds up as the reels gather speed.
    private let varispeed = AVAudioUnitVarispeed()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var effects: [Effect: AVAudioPCMBuffer] = [:]
    private var loops: [Loop: AVAudioPCMBuffer] = [:]
    private var currentLoop: Loop?
    private var playingLoop: AVAudioPCMBuffer?
    private var configured = false

    init() {
        engine.attach(fxNode)
        engine.attach(loopNode)
        engine.attach(varispeed)
        engine.connect(fxNode, to: engine.mainMixerNode, format: format)
        engine.connect(loopNode, to: varispeed, format: format)
        engine.connect(varispeed, to: engine.mainMixerNode, format: format)

        effects[.keyDown] = buffer(Self.keyDown())
        effects[.keyUp] = buffer(Self.keyUp())
        effects[.eject] = buffer(Self.eject())
        effects[.insert] = buffer(Self.insert())
        effects[.motorUp] = buffer(Self.motor(from: 0.35, to: 1.0, seconds: 0.36))
        effects[.motorDown] = buffer(Self.motor(from: 1.0, to: 0.3, seconds: 0.4))
        // Start the engine now, so the first key press is heard at once
        // rather than after the engine spins up.
        _ = start()
        let centre = NotificationCenter.default
        centre.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            // Never keep running in the background just to make silence.
            guard let self, self.playingLoop == nil else { return }
            self.engine.pause()
        }
        centre.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            _ = self?.start()
        }
        loops[.hiss] = buffer(Self.hiss())
        loops[.whir] = buffer(Self.whir())
        loops[.reverse] = buffer(Self.reverse())
    }

    /// How fast the tape is being wound, 0 just off the mark to 1 at full
    /// speed. The winding sounds rise in pitch with it.
    func setWindSpeed(_ speed: Double) {
        let clamped = min(max(speed, 0), 1)
        varispeed.rate = Float(1 + clamped * 0.9)
    }

    func play(_ effect: Effect) {
        guard enabled, let buffer = effects[effect], start() else { return }
        // The player node is left running, so a sound only has to be queued.
        fxNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !fxNode.isPlaying { fxNode.play() }
    }

    func setLoop(_ loop: Loop?) {
        guard loop != currentLoop else { return }
        currentLoop = loop
        varispeed.rate = 1
        applyLoop()
    }

    private func applyLoop() {
        var wanted: AVAudioPCMBuffer?
        var volume: Float = 1
        if enabled, let loop = currentLoop, hissEnabled || loop != .hiss {
            wanted = loops[loop]
            switch loop {
            case .hiss: volume = 0.5
            case .whir: volume = 0.9
            case .reverse: volume = 1.0
            }
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
            // A short buffer, so a key's clunk lands with the press.
            try? session.setPreferredIOBufferDuration(0.005)
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

    /// Rewinding with the tape against the heads: music running backwards
    /// and fast. Every note swells up out of nothing and stops dead, the way
    /// a played note sounds reversed, over garbled backwards voices and the
    /// motor underneath. Apple Music's own audio cannot be reached by an app,
    /// so the music here is made up. Loops seamlessly.
    private static func reverse() -> [Float] {
        let length = 2.4
        var s = silence(length)
        let count = s.count
        // A minor pentatonic, up an octave and a half for the tape speed
        let scale = [440.0, 523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.7, 1318.5]
        var rng = SystemRandomNumberGenerator()

        // Notes, each laid down reversed: a rising swell cut off sharply
        var start = 0.0
        while start < length {
            let duration = Double.random(in: 0.09...0.22, using: &rng)
            let freq = scale[Int.random(in: 0..<scale.count, using: &rng)]
            let gain = Double.random(in: 0.05...0.11, using: &rng)
            let first = Int(start * rate)
            let frames = Int(duration * rate)
            for k in 0..<frames {
                let i = (first + k) % count // wrap so the loop has no seam
                let t = Double(k) / rate
                let left = duration - t
                // A pluck decays as exp(-t * 18); reversed, it grows into the cut.
                let envelope = exp(-left * 18) * min(1, left * 400)
                let phase = 2 * .pi * freq * t
                let tone = sin(phase) + 0.45 * sin(2 * phase) + 0.25 * sin(3 * phase)
                s[i] += Float(gain * envelope * tone)
            }
            start += Double.random(in: 0.05...0.12, using: &rng)
        }

        // Backwards voices: filtered noise in syllables that swell and stop
        var band = 0.0
        var low = 0.0
        var syllable = 0.0
        var syllableLength = 0.12
        for i in 0..<count {
            let t = Double(i) / rate
            syllable += 1 / rate
            if syllable >= syllableLength {
                syllable = 0
                syllableLength = Double.random(in: 0.07...0.16, using: &rng)
            }
            let left = syllableLength - syllable
            let shape = exp(-left * 22) * min(1, left * 300)
            let noise = Double.random(in: -1...1, using: &rng)
            // A rough band pass that wanders like a vowel
            let centre = 0.10 + 0.06 * sin(2 * .pi * 3.3 * t)
            low += (noise - low) * centre
            band += (low - band) * 0.35
            s[i] += Float((low - band) * shape * 0.22)
        }

        // The motor and the tape rubbing past the heads
        var rumble = 0.0
        for i in 0..<count {
            let t = Double(i) / rate
            rumble += (Double.random(in: -1...1, using: &rng) - rumble) * 0.12
            let flutter = 0.8 + 0.2 * sin(2 * .pi * 20 * t)
            s[i] += Float(rumble * 0.07 * flutter + sin(2 * .pi * 880 * t) * 0.008)
        }
        return s
    }

    /// The capstan motor changing speed: a whine and rumble whose pitch
    /// slides from one speed to another, fading in or out at the slow end.
    private static func motor(from start: Double, to end: Double, seconds: Double) -> [Float] {
        var s = silence(seconds)
        var phase = 0.0
        var low = 0.0
        for i in 0..<s.count {
            let t = Double(i) / rate
            let along = t / seconds
            let speed = start + (end - start) * along
            phase += 2 * .pi * 620 * speed / rate
            low += (Double.random(in: -1...1) - low) * 0.12
            let level = min(1, speed) * min(1, (1 - along) * 12) * min(1, along * 40)
            s[i] = Float(level * (sin(phase) * 0.035 + sin(phase * 1.5) * 0.015 + low * 0.10))
        }
        return s
    }
}
