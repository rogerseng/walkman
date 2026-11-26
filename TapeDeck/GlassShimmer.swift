import CoreMotion
import SwiftUI

/// Reads how the phone is being held: tilt left/right and forward/back, each
/// as -1...1 around a natural holding angle, smoothed so the glare glides.
final class TiltSensor {
    private let manager = CMMotionManager()
    private(set) var roll = 0.0
    private(set) var pitch = 0.0

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let targetRoll = max(-1, min(1, motion.attitude.roll / 0.6))
            // A phone in the hand leans back about 45 degrees; call that level.
            let targetPitch = max(-1, min(1, (motion.attitude.pitch - 0.8) / 0.6))
            self.roll += (targetRoll - self.roll) * 0.18
            self.pitch += (targetPitch - self.pitch) * 0.18
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

/// Glare on the clear case. It is driven only by how the phone is moved: a
/// broad reflection and a thin bright streak slide across as it is tilted
/// left and right, and a soft hot spot travels with both tilts, the way a
/// ceiling light does on a real piece of plastic. With Reduce Motion on, or
/// with no motion sensor, the glare stays still.
struct GlassShimmer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var tilt = TiltSensor()
    /// Multiplies the brightness.
    var strength = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: reduceMotion || scenePhase != .active)) { _ in
            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    band(at: 0.35 + tilt.roll * 0.65, width: 0.50, strength: 0.13, in: size)
                    band(at: 0.62 + tilt.roll * 0.95, width: 0.10, strength: 0.30, in: size)
                    // Hot spot
                    Circle()
                        .fill(RadialGradient(colors: [Color.white.opacity(min(1, 0.26 * strength)), .clear],
                                             center: .center, startRadius: 0,
                                             endRadius: size.width * 0.45))
                        .frame(width: size.width * 0.9, height: size.width * 0.9)
                        .position(x: size.width * (0.5 - tilt.roll * 0.55),
                                  y: size.height * (0.32 + tilt.pitch * 0.45))
                }
                .frame(width: size.width, height: size.height)
                .clipped()
            }
        }
        .allowsHitTesting(false)
        .onAppear { if !reduceMotion { tilt.start() } }
        .onDisappear { tilt.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !reduceMotion {
                tilt.start()
            } else {
                tilt.stop()
            }
        }
    }

    private func band(at position: Double, width: Double, strength: Double, in size: CGSize) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Color.white.opacity(min(1, strength * self.strength)), .clear],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: size.width * width, height: size.height * 2.2)
            .rotationEffect(.degrees(22))
            .offset(x: (position - 0.5) * size.width)
    }
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
