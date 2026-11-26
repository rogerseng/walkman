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

/// A compact cassette. All measurements are in millimetres of a real
/// 100 x 63 mm shell and scaled to whatever size the view is given.
struct CassetteView: View {
    var title: String
    var subtitle: String
    var progress: Double
    var motion: TapeMotion

    @State private var spin = SpinState()

    private let hubRadius = 6.5
    private let fullRadius = 18.0

    var body: some View {
        GeometryReader { geo in
            let u = geo.size.width / 100
            ZStack {
                // Shell
                RoundedRectangle(cornerRadius: 3 * u)
                    .fill(LinearGradient(colors: [Color(white: 0.20), Color(white: 0.11)],
                                         startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: 3 * u)
                    .strokeBorder(Color(white: 0.32), lineWidth: 0.5 * u)

                // Paper label
                label(u: u)
                    .frame(width: 90 * u, height: 43 * u)
                    .position(x: 50 * u, y: 25.5 * u)

                // Window with the reels
                window(u: u)
                    .frame(width: 60 * u, height: 24 * u)
                    .position(x: 50 * u, y: 31 * u)

                // Head opening at the bottom
                HeadOpening()
                    .fill(Color(white: 0.16))
                    .overlay(HeadOpening().stroke(Color(white: 0.30), lineWidth: 0.4 * u))
                    .frame(width: 62 * u, height: 12 * u)
                    .position(x: 50 * u, y: 57 * u)
                ForEach([32.0, 50.0, 68.0], id: \.self) { x in
                    Circle()
                        .fill(Color.black)
                        .frame(width: (x == 50 ? 2.6 : 3.6) * u, height: (x == 50 ? 2.6 : 3.6) * u)
                        .position(x: x * u, y: 58 * u)
                }

                // Corner screws
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(Color(white: 0.38))
                        .overlay(Rectangle().fill(Color(white: 0.15)).frame(height: 0.35 * u))
                        .frame(width: 2.4 * u, height: 2.4 * u)
                        .position(x: (i % 2 == 0 ? 4.0 : 96.0) * u, y: (i < 2 ? 4.0 : 59.0) * u)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(100.0 / 63.0, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cassette: \(title). \(subtitle)")
    }

    private func label(u: CGFloat) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 1.6 * u)
                .fill(Color(red: 0.95, green: 0.91, blue: 0.81))
            // Colour bands behind the window
            VStack(spacing: 0) {
                Color(red: 0.96, green: 0.48, blue: 0.13)
                Color(red: 0.89, green: 0.24, blue: 0.16)
                Color(red: 0.97, green: 0.76, blue: 0.19)
            }
            .frame(height: 15 * u)
            .padding(.top, 19 * u)

            VStack(spacing: 0.3 * u) {
                Text(title.isEmpty ? " " : title)
                    .font(.custom("MarkerFelt-Wide", size: 5.4 * u))
                    .foregroundColor(Color(red: 0.10, green: 0.12, blue: 0.35))
                Text(subtitle.isEmpty ? " " : subtitle)
                    .font(.custom("MarkerFelt-Thin", size: 3.8 * u))
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.30))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 4 * u)
            .padding(.top, 1.6 * u)

            HStack {
                Text("A").font(.system(size: 4.2 * u, weight: .black))
                Spacer()
                Text("C-90").font(.system(size: 2.4 * u, weight: .semibold))
            }
            .foregroundColor(Color(white: 0.2))
            .padding(.horizontal, 3 * u)
            .padding(.top, 36.5 * u)
        }
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
                Color(red: 0.09, green: 0.07, blue: 0.06)
                reel(radius: leftRadius, angle: spin.left, u: u)
                    .position(x: 10 * u, y: 12 * u)
                reel(radius: rightRadius, angle: spin.right, u: u)
                    .position(x: 50 * u, y: 12 * u)
                // Glass reflection
                LinearGradient(colors: [Color.white.opacity(0.16), .clear, .clear,
                                        Color.white.opacity(0.06)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3 * u))
        .overlay(RoundedRectangle(cornerRadius: 3 * u).strokeBorder(Color.black, lineWidth: 0.7 * u))
    }

    private func reel(radius: Double, angle: Double, u: CGFloat) -> some View {
        ZStack {
            // Wound tape
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.34, green: 0.21, blue: 0.13),
                                              Color(red: 0.22, green: 0.13, blue: 0.08)],
                                     center: .center, startRadius: 0, endRadius: radius * u))
                .frame(width: 2 * radius * u, height: 2 * radius * u)
            // Hub with six drive teeth
            ZStack {
                Circle().fill(Color(white: 0.93))
                Circle().fill(Color(red: 0.09, green: 0.07, blue: 0.06))
                    .frame(width: 7.4 * u, height: 7.4 * u)
                ForEach(0..<6, id: \.self) { tooth in
                    Rectangle()
                        .fill(Color(white: 0.93))
                        .frame(width: 1.3 * u, height: 2.0 * u)
                        .offset(y: -2.9 * u)
                        .rotationEffect(.degrees(Double(tooth) * 60))
                }
            }
            .frame(width: 2 * hubRadius * u, height: 2 * hubRadius * u)
            .rotationEffect(.radians(angle))
        }
    }
}

/// The trapezoid at the bottom of a cassette where the heads reach the tape.
private struct HeadOpening: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.07
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
