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

/// A compact cassette. The shell, label, screws and window glass are artwork
/// (see tools/cassette-art.html); the reels and the writing on the label are
/// drawn live underneath and on top of it. All measurements are in millimetres
/// of a real 100 x 63 mm shell and scaled to whatever size the view is given.
struct CassetteView: View {
    var title: String
    var subtitle: String
    var progress: Double
    var motion: TapeMotion

    @State private var spin = SpinState()

    private let hubRadius = 6.5
    private let fullRadius = 18.0
    private let ink = Color(red: 0.07, green: 0.10, blue: 0.33)

    var body: some View {
        GeometryReader { geo in
            let u = geo.size.width / 100
            ZStack {
                // Inside of the shell, seen through the window
                RoundedRectangle(cornerRadius: 2.6 * u)
                    .fill(Color(white: 0.03))
                window(u: u)
                    .frame(width: 64 * u, height: 22 * u)
                    .position(x: 50 * u, y: 31 * u)

                Image("CassetteFront")
                    .resizable()
                    .interpolation(.high)

                // Handwriting on the two ruled lines of the label
                Text(title.isEmpty ? " " : title)
                    .font(.custom("BradleyHandITCTT-Bold", fixedSize: 5.0 * u))
                    .foregroundColor(ink.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 74 * u, height: 5.6 * u, alignment: .bottomLeading)
                    .position(x: 52 * u, y: 8.9 * u)
                Text(subtitle.isEmpty ? " " : subtitle)
                    .font(.custom("BradleyHandITCTT-Bold", fixedSize: 3.4 * u))
                    .foregroundColor(ink.opacity(0.80))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 74 * u, height: 4.4 * u, alignment: .bottomLeading)
                    .position(x: 52 * u, y: 14.5 * u)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(100.0 / 63.0, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cassette: \(title). \(subtitle)")
    }

    private func window(u: CGFloat) -> some View {
        let moving = motion == .playing || motion == .fastForward || motion == .rewind
        // Tape leaves the left reel and winds onto the right one. Pack radius
        // follows the wound area, so it changes fastest near the hub.
        let span = fullRadius * fullRadius - hubRadius * hubRadius
        let leftRadius = (hubRadius * hubRadius + (1 - progress) * span).squareRoot() + 0.6
        let rightRadius = (hubRadius * hubRadius + progress * span).squareRoot() + 0.6
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
                // Slip sheet behind the reels
                LinearGradient(colors: [Color(red: 0.16, green: 0.14, blue: 0.13),
                                        Color(red: 0.08, green: 0.07, blue: 0.07)],
                               startPoint: .top, endPoint: .bottom)
                reel(radius: leftRadius, angle: spin.left, u: u)
                    .position(x: 11 * u, y: 11 * u)
                reel(radius: rightRadius, angle: spin.right, u: u)
                    .position(x: 53 * u, y: 11 * u)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2 * u))
    }

    private func reel(radius: Double, angle: Double, u: CGFloat) -> some View {
        let size = 2 * radius * u
        return ZStack {
            // Wound tape: dark brown oxide with the soft sheen a tape pack has
            Circle()
                .fill(RadialGradient(stops: [
                    .init(color: Color(red: 0.20, green: 0.12, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.27, green: 0.17, blue: 0.11), location: 0.55),
                    .init(color: Color(red: 0.23, green: 0.14, blue: 0.09), location: 0.80),
                    .init(color: Color(red: 0.15, green: 0.09, blue: 0.06), location: 1)
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
            Circle()
                .strokeBorder(Color.black.opacity(0.55), lineWidth: 0.25 * u)
            Image("ReelHub")
                .resizable()
                .interpolation(.high)
                .frame(width: 2 * hubRadius * u, height: 2 * hubRadius * u)
                .rotationEffect(.radians(angle))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.6), radius: 0.8 * u, y: 0.4 * u)
    }
}
