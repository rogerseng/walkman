import SwiftUI

/// Keeps the reel angles between frames. The reels turn at different rates
/// because the tape moves at a constant speed while each pack changes size.
private final class SpinState {
    var left = 0.0
    var right = 0.0
    private var last: Date?

    func advance(to now: Date, tapeSpeed: Double, leftRadius: Double, rightRadius: Double) {
        let dt = min(max(now.timeIntervalSince(last ?? now), 0), 0.1)
        last = now
        guard tapeSpeed != 0 else { return }
        // Cap the rate so fast winding does not strobe against the frame rate.
        let limit = 14.0
        left -= max(-limit, min(limit, tapeSpeed / leftRadius)) * dt
        right -= max(-limit, min(limit, tapeSpeed / rightRadius)) * dt
    }
}

/// A clear compact cassette. The front of the shell (edges, ridges, stickers,
/// label strip, rollers, screws, reflections) is see-through artwork from
/// tools/cassette-art.html. Underneath it the reels, the tape running down to
/// the rollers, and the handwriting on the label are drawn live. All
/// measurements are in millimetres of a real 100 x 63 mm shell and scaled to
/// whatever size the view is given.
struct CassetteView: View {
    var title: String
    var subtitle: String
    var progress: Double
    var motion: TapeMotion

    @State private var spin = SpinState()

    private let hubRadius = 10.0
    private let fullRadius = 25.0
    private let leftHub = CGPoint(x: 29.5, y: 28.5)
    private let rightHub = CGPoint(x: 70.5, y: 28.5)
    private let ink = Color(red: 0.07, green: 0.10, blue: 0.33)
    private let oxide = Color(red: 0.14, green: 0.10, blue: 0.08)

    var body: some View {
        GeometryReader { geo in
            let u = geo.size.width / 100
            ZStack {
                // The plastic itself: barely there, with a soft shadow below
                RoundedRectangle(cornerRadius: 2.6 * u)
                    .fill(Color.white.opacity(0.16))
                    .shadow(color: .black.opacity(0.35), radius: 2.5 * u, y: 1.2 * u)

                reels(u: u)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 2.6 * u))

                Image("CassetteFront")
                    .resizable()
                    .interpolation(.high)

                // Handwriting on the stick-on label
                Text(title.isEmpty ? " " : title)
                    .font(.custom("BradleyHandITCTT-Bold", fixedSize: 4.5 * u))
                    .foregroundColor(ink.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 62 * u, height: 5.0 * u, alignment: .bottomLeading)
                    .position(x: 54 * u, y: 6.3 * u)
                Text(subtitle.isEmpty ? " " : subtitle)
                    .font(.custom("BradleyHandITCTT-Bold", fixedSize: 3.0 * u))
                    .foregroundColor(ink.opacity(0.80))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 62 * u, height: 3.6 * u, alignment: .bottomLeading)
                    .position(x: 54 * u, y: 10.8 * u)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(100.0 / 63.0, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cassette: \(title). \(subtitle)")
    }

    private func reels(u: CGFloat) -> some View {
        let moving = motion == .playing || motion == .fastForward || motion == .rewind
        // Tape leaves the left reel and winds onto the right one. Pack radius
        // follows the wound area, so it changes fastest near the hub.
        let span = fullRadius * fullRadius - hubRadius * hubRadius
        let leftRadius = (hubRadius * hubRadius + (1 - progress) * span).squareRoot() + 0.4
        let rightRadius = (hubRadius * hubRadius + progress * span).squareRoot() + 0.4
        let speed: Double = {
            switch motion {
            case .playing: return 47.6          // 4.76 cm per second, the real thing
            case .fastForward: return 47.6 * 12
            case .rewind: return -47.6 * 12
            case .paused, .stopped: return 0
            }
        }()

        return TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !moving)) { context in
            let _ = spin.advance(to: context.date, tapeSpeed: speed,
                                 leftRadius: leftRadius, rightRadius: rightRadius)
            ZStack {
                // Tape running from each pack down to its guide roller
                Path { path in
                    let leftGuide = CGPoint(x: 8.3, y: 58.3)
                    let rightGuide = CGPoint(x: 91.7, y: 58.3)
                    let leftOff = tangent(on: leftHub, radius: CGFloat(leftRadius), from: leftGuide, leftmost: true)
                    let rightOff = tangent(on: rightHub, radius: CGFloat(rightRadius), from: rightGuide, leftmost: false)
                    path.move(to: CGPoint(x: leftOff.x * u, y: leftOff.y * u))
                    path.addLine(to: CGPoint(x: leftGuide.x * u, y: leftGuide.y * u))
                    path.addLine(to: CGPoint(x: leftGuide.x * u, y: 61.75 * u))
                    path.move(to: CGPoint(x: rightOff.x * u, y: rightOff.y * u))
                    path.addLine(to: CGPoint(x: rightGuide.x * u, y: rightGuide.y * u))
                    path.addLine(to: CGPoint(x: rightGuide.x * u, y: 61.75 * u))
                }
                .stroke(oxide, lineWidth: 0.4 * u)

                reel(radius: leftRadius, angle: spin.left, u: u)
                    .position(x: leftHub.x * u, y: leftHub.y * u)
                reel(radius: rightRadius, angle: spin.right, u: u)
                    .position(x: rightHub.x * u, y: rightHub.y * u)
            }
        }
    }

    /// Where a straight run of tape from `point` touches the pack.
    private func tangent(on center: CGPoint, radius: CGFloat, from point: CGPoint, leftmost: Bool) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > radius else { return point }
        let toward = atan2(dy, dx)
        let spread = acos(radius / distance)
        let a = CGPoint(x: center.x + radius * cos(toward + spread), y: center.y + radius * sin(toward + spread))
        let b = CGPoint(x: center.x + radius * cos(toward - spread), y: center.y + radius * sin(toward - spread))
        if leftmost { return a.x < b.x ? a : b }
        return a.x > b.x ? a : b
    }

    private func reel(radius: Double, angle: Double, u: CGFloat) -> some View {
        let size = 2 * radius * u
        return ZStack {
            // Wound tape: near-black oxide with the soft sheen a tape pack
            // has. It is a ring, because the hub in the middle is clear.
            ZStack {
                Circle()
                    .fill(RadialGradient(stops: [
                        .init(color: Color(red: 0.12, green: 0.09, blue: 0.07), location: 0),
                        .init(color: Color(red: 0.19, green: 0.15, blue: 0.12), location: 0.60),
                        .init(color: Color(red: 0.16, green: 0.12, blue: 0.10), location: 0.85),
                        .init(color: Color(red: 0.09, green: 0.07, blue: 0.06), location: 1)
                    ], center: .center, startRadius: 0, endRadius: radius * u))
                Circle()
                    .fill(AngularGradient(stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: Color.white.opacity(0.16), location: 0.08),
                        .init(color: .clear, location: 0.18),
                        .init(color: .clear, location: 0.50),
                        .init(color: Color.white.opacity(0.10), location: 0.58),
                        .init(color: .clear, location: 0.68),
                        .init(color: .clear, location: 1.00)
                    ], center: .center, angle: .degrees(200)))
            }
            .mask(Circle().strokeBorder(lineWidth: max(0, radius - hubRadius + 0.4) * u))
            .shadow(color: .black.opacity(0.35), radius: 0.8 * u, y: 0.4 * u)
            Image("ReelHub")
                .resizable()
                .interpolation(.high)
                .frame(width: 2 * hubRadius * u, height: 2 * hubRadius * u)
                .rotationEffect(.radians(angle))
        }
        .frame(width: size, height: size)
    }
}
