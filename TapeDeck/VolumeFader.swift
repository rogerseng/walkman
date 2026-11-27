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
    @State private var lastStep = -1

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
