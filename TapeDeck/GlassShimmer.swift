import CoreMotion
import SwiftUI

/// Reads how the phone is being held: tilt left/right and forward/back, each
/// as -1...1 around a natural holding angle, smoothed so the glare glides.
/// It only reports a change once the phone has really moved, so a phone held
/// still costs nothing to draw.
@Observable
final class TiltSensor {
    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var smoothRoll = 0.0
    @ObservationIgnored private var smoothPitch = 0.0
    private(set) var roll = 0.0
    private(set) var pitch = 0.0

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let targetRoll = max(-1, min(1, motion.attitude.roll / 0.6))
            // A phone in the hand leans back about 45 degrees; call that level.
            let targetPitch = max(-1, min(1, (motion.attitude.pitch - 0.8) / 0.6))
            self.smoothRoll += (targetRoll - self.smoothRoll) * 0.2
            self.smoothPitch += (targetPitch - self.smoothPitch) * 0.2
            if abs(self.smoothRoll - self.roll) > 0.004 || abs(self.smoothPitch - self.pitch) > 0.004 {
                self.roll = self.smoothRoll
                self.pitch = self.smoothPitch
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

/// Glare on the clear case: one soft, faint glow that drifts as the phone is
/// tilted, the way a ceiling light does on plastic. No streaks or lines.
/// With Reduce Motion on, or with no motion sensor, it stays still.
struct GlassShimmer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var tilt = TiltSensor()
    @AppStorage(Prefs.glare) private var glareOn = true
    /// Multiplies the brightness.
    var strength = 1.0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let roll = still ? 0 : tilt.roll
            let pitch = still ? 0 : tilt.pitch
            ZStack {
                // Hot spot
                Circle()
                    .fill(RadialGradient(colors: [Color.white.opacity(min(1, 0.07 * strength)), .clear],
                                         center: .center, startRadius: 0,
                                         endRadius: size.width * 0.45))
                    .frame(width: size.width * 0.9, height: size.width * 0.9)
                    .position(x: size.width * (0.5 - roll * 0.4),
                              y: size.height * (0.32 + pitch * 0.3))
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            // Flattened into one layer, so a tilt redraws a single image.
            .drawingGroup()
        }
        .allowsHitTesting(false)
        .onAppear { if !still { tilt.start() } }
        .onDisappear { tilt.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !still {
                tilt.start()
            } else {
                tilt.stop()
            }
        }
        .onChange(of: glareOn) { _, on in
            if on, !reduceMotion {
                tilt.start()
            } else {
                tilt.stop()
            }
        }
    }

    /// The glare holds still when Reduce Motion is on or the setting is off.
    private var still: Bool { reduceMotion || !glareOn }

}

/// Brushed aluminium, for the plates and trim on the player body.
struct BrushedSilver: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.86), Color(white: 0.70), Color(white: 0.78)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                var y: CGFloat = 0.5
                while y < size.height {
                    let line = Path(CGRect(x: 0, y: y, width: size.width, height: 0.5))
                    context.fill(line, with: .color(.white.opacity(0.22)))
                    y += 2
                }
            }
        }
    }
}

/// A small cross-head screw.
struct Screw: View {
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.45)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Rectangle().fill(Color(white: 0.2)).frame(width: 6, height: 1)
            Rectangle().fill(Color(white: 0.2)).frame(width: 1, height: 6)
        }
        .frame(width: 9, height: 9)
        .accessibilityHidden(true)
    }
}
