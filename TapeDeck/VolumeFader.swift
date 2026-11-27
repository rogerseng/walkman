import AVFoundation
import MediaPlayer
import SwiftUI

/// The phone's own volume, readable and settable.
///
/// iOS has no direct call for setting the system volume. The supported control
/// is `MPVolumeView`; this keeps one out of sight and moves its slider. Reading
/// comes from the audio session, so the fader also follows the side buttons.
@MainActor
final class SystemVolume: ObservableObject {
    @Published private(set) var level: Double
    let volumeView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 120, height: 40))

    private var observation: NSKeyValueObservation?
    private var lastSet = Date.distantPast
    private var levelBeforeMute = 0.5

    var isMuted: Bool { level <= 0.001 }

    /// Drops the volume to nothing, or puts it back where it was.
    func toggleMute() {
        if isMuted {
            set(max(levelBeforeMute, 1.0 / 16))
        } else {
            levelBeforeMute = level
            set(0)
        }
    }

    init() {
        let session = AVAudioSession.sharedInstance()
        level = Double(session.outputVolume)
        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor in
                // Ignore echoes of our own changes while the fader is moving.
                guard let self, Date().timeIntervalSince(self.lastSet) > 0.3 else { return }
                self.level = Double(value)
            }
        }
    }

    func set(_ newLevel: Double) {
        let clamped = min(max(newLevel, 0), 1)
        level = clamped
        lastSet = Date()
        Self.slider(in: volumeView)?.value = Float(clamped)
    }

    private static func slider(in view: UIView) -> UISlider? {
        if let slider = view as? UISlider { return slider }
        for child in view.subviews {
            if let found = slider(in: child) { return found }
        }
        return nil
    }
}

/// Keeps the system volume view in the window, where it has to be to work,
/// without showing it.
private struct VolumeHost: UIViewRepresentable {
    let view: MPVolumeView

    func makeUIView(context: Context) -> MPVolumeView { view }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

/// A vertical volume fader, as on a tape deck: a groove with tick marks and a
/// cap you slide. Up is louder. It clicks under the thumb as it passes each
/// step, and it follows the phone's volume buttons.
struct VolumeFader: View {
    @ObservedObject var volume: SystemVolume
    /// A tape is playing, so the level lights should move.
    var playing = false
    @State private var lastStep = -1
    @AppStorage(Prefs.levelLights) private var lightsOn = true

    private let capHeight: CGFloat = 22
    private let capWidth: CGFloat = 38
    private let steps = 16.0

    var body: some View {
        GeometryReader { geo in
            let travel = max(1, geo.size.height - capHeight)
            let capTop = CGFloat(1 - volume.level) * travel
            ZStack(alignment: .top) {
                // Tick marks engraved down the left of the slot
                VStack(spacing: 0) {
                    ForEach(0..<11, id: \.self) { tick in
                        Rectangle()
                            .fill(Color.white.opacity(tick % 5 == 0 ? 0.6 : 0.32))
                            .frame(width: tick % 5 == 0 ? 9 : 5, height: 1)
                            .shadow(color: .black.opacity(0.8), radius: 0, y: -0.75)
                        if tick < 10 { Spacer(minLength: 0) }
                    }
                }
                .padding(.vertical, capHeight / 2)
                .frame(maxWidth: .infinity, alignment: .leading)

                // The slot, cut into the panel: dark inside, shadowed along
                // its upper lip and lit along its lower one
                Capsule()
                    .fill(LinearGradient(colors: [Color.black, Color(white: 0.07)],
                                         startPoint: .leading, endPoint: .trailing))
                    .overlay(
                        Capsule().strokeBorder(LinearGradient(colors: [Color.black, Color.white.opacity(0.30)],
                                                              startPoint: .topLeading, endPoint: .bottomTrailing),
                                               lineWidth: 1)
                    )
                    .frame(width: 8)
                    .padding(.vertical, capHeight / 2 - 4)
                    .frame(maxWidth: .infinity)

                // Level lights down inside the slot. They only ever light
                // from the bottom up to the cap, never past it.
                if lightsOn {
                    LevelLights(level: volume.level, playing: playing)
                        .frame(width: 4)
                        .padding(.vertical, capHeight / 2 - 2)
                        .frame(maxWidth: .infinity)
                }

                // The cap: brushed metal with grip ridges and a marker line
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(stops: [
                            .init(color: Color(white: 0.98), location: 0),
                            .init(color: Color(white: 0.74), location: 0.18),
                            .init(color: Color(white: 0.56), location: 0.5),
                            .init(color: Color(white: 0.70), location: 0.82),
                            .init(color: Color(white: 0.40), location: 1)
                        ], startPoint: .top, endPoint: .bottom))
                    VStack(spacing: 2.5) {
                        ForEach(0..<5, id: \.self) { ridge in
                            Rectangle()
                                .fill(ridge == 2 ? Color(white: 0.08) : Color.black.opacity(0.22))
                                .frame(height: ridge == 2 ? 1.5 : 1)
                                .shadow(color: .white.opacity(0.5), radius: 0, y: 0.75)
                        }
                    }
                    .padding(.horizontal, 3)
                    RoundedRectangle(cornerRadius: 4).strokeBorder(Color.black.opacity(0.55), lineWidth: 0.75)
                }
                .frame(width: capWidth, height: capHeight)
                .shadow(color: .black.opacity(0.65), radius: 4, y: 3)
                // Centred on the slot
                .offset(y: capTop)
                .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let level = 1 - Double((drag.location.y - capHeight / 2) / travel)
                        volume.set(level)
                        let step = Int((min(max(level, 0), 1) * steps).rounded())
                        if step != lastStep {
                            lastStep = step
                            Haptics.detent()
                        }
                    }
            )
            .background(
                VolumeHost(view: volume.volumeView)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .allowsHitTesting(false)
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int((volume.level * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: volume.set(volume.level + 1 / steps)
            case .decrement: volume.set(volume.level - 1 / steps)
            @unknown default: break
            }
        }
    }
}

/// A ladder of small lamps inside the volume slot. How high it can light is
/// set by the volume; while a tape plays the lit part rises and falls in a
/// steady beat. It is for show: an app cannot hear what Apple Music plays.
private struct LevelLights: View {
    let level: Double
    let playing: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !playing)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                // Where the middle of the cap sits, measured from the top
                let capY = 2 + CGFloat(1 - min(max(level, 0), 1)) * (size.height - 4)
                let room = max(0, size.height - capY)
                let lit = playing ? room * CGFloat(Self.pulse(at: time)) : room
                var y = size.height
                while y - 3 > capY {
                    let on = size.height - y < lit
                    // Amber at the bottom, warming toward the cap
                    let rise = Double(1 - (y - capY) / max(1, room))
                    let lamp = Color(red: 1.0, green: 0.46 + 0.32 * rise, blue: 0.10)
                    let rect = CGRect(x: 0, y: y - 3, width: size.width, height: 3)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1),
                                 with: .color(lamp.opacity(on ? (playing ? 1.0 : 0.5) : 0.09)))
                    y -= 4.5
                }
            }
        }
        .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.1).opacity(playing ? 0.55 : 0.2), radius: 3)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 0...1: a kick on each beat that dies away, with some movement between.
    private static func pulse(at time: Double) -> Double {
        let beat = time * 2.05
        let kick = exp(-(beat - floor(beat)) * 4.5)
        let sway = 0.5 + 0.5 * sin(time * 7.3) * sin(time * 3.1 + 1.7)
        return min(1, 0.38 + 0.44 * kick + 0.18 * sway)
    }
}
