import CoreMotion
import SwiftUI

/// Reads how far the phone is tilted left or right, as -1...1.
final class TiltSensor {
    private let manager = CMMotionManager()
    private(set) var roll = 0.0

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            self?.roll = max(-1, min(1, motion.attitude.roll / 0.7))
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

/// Light playing across the door glass. A broad reflection slides as the phone
/// is tilted, and every few seconds a thin glint sweeps across on its own.
/// With Reduce Motion on, it is a still reflection.
struct GlassShimmer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var tilt = TiltSensor()
    /// Multiplies the brightness. Pale backgrounds need more than dark ones.
    var strength = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion || scenePhase != .active)) { context in
            GeometryReader { geo in
                let cycle = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 7)
                ZStack {
                    band(at: 0.35 + tilt.roll * 0.55, width: 0.45, strength: 0.16, in: geo.size)
                    if !reduceMotion, cycle < 1.3 {
                        band(at: -0.4 + cycle / 1.3 * 1.8, width: 0.16, strength: 0.30, in: geo.size)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
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
