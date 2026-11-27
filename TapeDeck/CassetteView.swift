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

/// A clear compact cassette, built in layers from artwork made by
/// tools/cassette-art.html. At the back is the inside of the shell (slip
/// sheet, reel wells, shield, pad spring). On that sit the live parts: the
/// reels of wound tape, the tape running down to the rollers, and the hubs.
/// Over them goes the see-through front of the shell (edges, ridges, stickers,
/// label strip, rollers, screws, scratches, reflections), and last the
/// lettering on the label. All
/// measurements are in millimetres of a real 100 x 63 mm shell and scaled to
/// whatever size the view is given.
struct CassetteView: View {
    var title: String
    var subtitle: String
    var progress: Double
    var motion: TapeMotion
    /// "A" or "B", printed in the ring at the end of the label.
    var side = "A"
    /// A shop-bought tape: the label is printed in the cover art's colours.
    /// Otherwise it is a paper label written on by hand.
    var printed = false
    /// The cover art's colour. Tints the clear shell, and fills a printed label.
    var tint: Color?
    /// The colour the cover art suggests for lettering on `tint`.
    var printColor: Color?

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
                    .fill((tint ?? .white).opacity(tint == nil ? 0.16 : 0.30))
                    .shadow(color: .black.opacity(0.35), radius: 2.5 * u, y: 1.2 * u)

                // Inside the shell: slip sheet, reel wells, shield and pad spring
                Image("CassetteBack")
                    .resizable()
                    .interpolation(.high)

                reels(u: u)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 2.6 * u))

                Image("CassetteFront")
                    .resizable()
                    .interpolation(.high)

                label(u: u)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(100.0 / 63.0, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cassette: \(title). \(subtitle)")
    }

    /// The lettering on the label strip, which the artwork leaves blank.
    @ViewBuilder
    private func label(u: CGFloat) -> some View {
        let showPrint = printed && tint != nil
        let lettering = showPrint ? (printColor ?? .white) : Color(white: 0.17)
        if showPrint, let tint {
            // Printed label: a block of the album's colour with a light gloss
            RoundedRectangle(cornerRadius: 0.5 * u)
                .fill(tint)
                .overlay(
                    LinearGradient(colors: [Color.white.opacity(0.22), .clear, Color.black.opacity(0.12)],
                                   startPoint: .top, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 0.5 * u))
                )
                .frame(width: 74 * u, height: 10.3 * u)
                .position(x: 50 * u, y: 8.45 * u)
        }

        // Side letter in its ring
        Text(side)
            .font(.system(size: 3.4 * u, weight: .bold))
            .foregroundColor(lettering)
            .frame(width: 4.6 * u, height: 4.6 * u)
            .overlay(Circle().strokeBorder(lettering, lineWidth: 0.26 * u))
            .position(x: 22.6 * u, y: 8.4 * u)

        if showPrint {
            // Album title and artist, in the same marker as every tape name
            Text(title.isEmpty ? " " : title)
                .font(Typeface.markerFixed(4.3 * u))
                .foregroundColor(lettering)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .frame(width: 58 * u, height: 5.0 * u, alignment: .leading)
                .position(x: 56 * u, y: 6.4 * u)
            Text(subtitle.isEmpty ? " " : subtitle)
                .font(Typeface.markerFixed(2.9 * u))
                .foregroundColor(lettering.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 58 * u, height: 3.6 * u, alignment: .leading)
                .position(x: 56 * u, y: 10.7 * u)
        } else {
            // Handwriting on the paper label's ruled lines
            Text(title.isEmpty ? " " : title)
                .font(Typeface.markerFixed(4.5 * u))
                .foregroundColor(ink.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 58 * u, height: 5.0 * u, alignment: .bottomLeading)
                .position(x: 56 * u, y: 6.3 * u)
            Text(subtitle.isEmpty ? " " : subtitle)
                .font(Typeface.markerFixed(3.0 * u))
                .foregroundColor(ink.opacity(0.80))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 58 * u, height: 3.6 * u, alignment: .bottomLeading)
                .position(x: 56 * u, y: 10.8 * u)
        }
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
        let full = 2 * fullRadius * u
        return ZStack {
            // Wound tape. The artwork is a whole reel, turn upon turn; the
            // ring cut from it is as wide as the tape wound on so far. The
            // middle is left open because the hub is clear.
            Image("TapePack")
                .resizable()
                .interpolation(.high)
                .frame(width: full, height: full)
                .mask(
                    Circle()
                        .strokeBorder(lineWidth: max(0, radius - hubRadius + 0.4) * u)
                        .frame(width: size, height: size)
                )
                .shadow(color: .black.opacity(0.45), radius: 1.0 * u, y: 0.5 * u)
            // The outermost turn catches the light
            Circle()
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.18 * u)
                .frame(width: size, height: size)
            Image("ReelHub")
                .resizable()
                .interpolation(.high)
                .frame(width: 2 * hubRadius * u, height: 2 * hubRadius * u)
                .rotationEffect(.radians(angle))
        }
        .frame(width: size, height: size)
    }
}
