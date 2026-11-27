import SwiftUI

/// Parts of the upright recorder the open phone becomes when it is held on
/// end: a slab of moulded plastic with a speaker grille at the top, the
/// cassette door under it, and a row of piano keys in a trough at the foot.

/// A hollow cut into the case: dark inside, with the wall above it in shadow
/// and the lip below it catching the light.
struct Recess: ViewModifier {
    var corner: CGFloat = 10
    var depth: CGFloat = 1

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner)
        content
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(Color.black.opacity(0.85), lineWidth: 8 * depth)
                    .blur(radius: 5 * depth)
                    .offset(y: 4 * depth)
                    .clipShape(shape)
                    .allowsHitTesting(false)
            )
            .overlay(
                shape.strokeBorder(LinearGradient(colors: [Color.black.opacity(0.9), Color.white.opacity(0.30)],
                                                  startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                    .allowsHitTesting(false)
            )
            // The rounded edge of the case rolling into the hollow
            .background(
                shape.stroke(Color.white.opacity(0.14), lineWidth: 2).blur(radius: 1).offset(y: 1.5)
            )
    }
}

/// A rounded panel with a bite out of its top right corner, for the speaker
/// plate that is moulded round the clock and status icons.
struct NotchedPanel: Shape {
    var notch: CGSize
    var corner: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let nw = min(max(0, notch.width), w - corner * 3)
        let nh = min(max(0, notch.height), h - corner * 3)
        guard nw > 0, nh > corner else { return Path(roundedRect: rect, cornerRadius: corner) }
        path.move(to: CGPoint(x: corner, y: 0))
        path.addArc(tangent1End: CGPoint(x: w - nw, y: 0), tangent2End: CGPoint(x: w - nw, y: nh), radius: corner)
        path.addArc(tangent1End: CGPoint(x: w - nw, y: nh), tangent2End: CGPoint(x: w, y: nh), radius: corner)
        path.addArc(tangent1End: CGPoint(x: w, y: nh), tangent2End: CGPoint(x: w, y: h), radius: corner)
        path.addArc(tangent1End: CGPoint(x: w, y: h), tangent2End: CGPoint(x: 0, y: h), radius: corner)
        path.addArc(tangent1End: CGPoint(x: 0, y: h), tangent2End: CGPoint(x: 0, y: 0), radius: corner)
        path.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: w, y: 0), radius: corner)
        path.closeSubpath()
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// A hollow of any outline, cut into the case: the wall above it in shadow
/// and the lip below it catching the light.
struct RecessIn<Outline: Shape>: ViewModifier {
    let outline: Outline
    var depth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .clipShape(outline)
            .overlay(
                outline.stroke(Color.black.opacity(0.85), lineWidth: 16 * depth)
                    .blur(radius: 5 * depth)
                    .offset(y: 4 * depth)
                    .clipShape(outline)
                    .allowsHitTesting(false)
            )
            .overlay(
                outline.stroke(LinearGradient(colors: [Color.black.opacity(0.9), Color.white.opacity(0.30)],
                                              startPoint: .top, endPoint: .bottom), lineWidth: 3)
                    .clipShape(outline)
                    .allowsHitTesting(false)
            )
            .background(
                outline.stroke(Color.white.opacity(0.14), lineWidth: 2).blur(radius: 1).offset(y: 1.5)
            )
    }
}

/// A part that stands proud of the case: lit along its top and left, in
/// shadow along its foot, and throwing a shadow below.
struct Raised: ViewModifier {
    var corner: CGFloat = 12

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner)
        content
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.42), Color.white.opacity(0.06),
                                                           Color.black.opacity(0.55)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.6), radius: 7, y: 6)
    }
}

/// The speaker: a plate of the case's plastic punched with rows of square
/// holes, with the cone dark behind it. The cone moves a little on each beat
/// while a tape plays, which shows as light shifting behind the holes.
struct SpeakerGrille: View {
    let colors: [Color]
    var playing = false
    var tempo = PlayerModel.defaultTempo
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Behind the plate: the cone, seen only through the holes
                Color(white: 0.03)
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !playing || reduceMotion)) { timeline in
                    let beat = timeline.date.timeIntervalSinceReferenceDate * tempo / 60
                    let kick = playing && !reduceMotion ? exp(-(beat - floor(beat)) * 5) : 0
                    let size = min(geo.size.height * 1.25, geo.size.width * 0.62)
                    Circle()
                        .fill(RadialGradient(colors: [Color(white: 0.42), Color(white: 0.20), Color(white: 0.05)],
                                             center: .center, startRadius: 0, endRadius: size / 2))
                        .frame(width: size, height: size)
                        .scaleEffect(1 + 0.035 * kick)
                        .opacity(0.75 + 0.25 * kick)
                }
                // The plate, with its holes cut clean through
                Canvas { context, size in
                    context.fill(Path(CGRect(origin: .zero, size: size)),
                                 with: .linearGradient(Gradient(colors: colors),
                                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                    let pitch: CGFloat = max(9, size.width / 62)
                    let hole = pitch * 0.56
                    let columns = Int((size.width - 20) / pitch)
                    let rows = Int((size.height - 20) / pitch)
                    let left = (size.width - CGFloat(columns - 1) * pitch) / 2
                    let top = (size.height - CGFloat(rows - 1) * pitch) / 2
                    // Each hole has a lit lower edge, where the cut faces up
                    for row in 0..<max(rows, 0) {
                        for column in 0..<max(columns, 0) {
                            let rect = CGRect(x: left + CGFloat(column) * pitch - hole / 2,
                                              y: top + CGFloat(row) * pitch - hole / 2,
                                              width: hole, height: hole)
                            context.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 1), cornerRadius: 1.2),
                                         with: .color(.white.opacity(0.22)))
                        }
                    }
                    context.blendMode = .destinationOut
                    for row in 0..<max(rows, 0) {
                        for column in 0..<max(columns, 0) {
                            let rect = CGRect(x: left + CGFloat(column) * pitch - hole / 2,
                                              y: top + CGFloat(row) * pitch - hole / 2,
                                              width: hole, height: hole)
                            context.fill(Path(roundedRect: rect, cornerRadius: 1.2), with: .color(.black))
                        }
                    }
                }
                .compositingGroup()
                .overlay(PlasticGrain(strength: 0.4).allowsHitTesting(false))
                // Light across the plate from above
                LinearGradient(colors: [Color.white.opacity(0.10), .clear, Color.black.opacity(0.22)],
                               startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One piano key of the recorder: a block of plastic hinged at the back,
/// with its mark moulded dark into its top. Pressed, it tips down
/// into the trough and its front wall disappears. It reports press and
/// release separately, and stays down while latched.
struct PianoKey: View {
    var symbol: String
    var label: String
    var accent = false
    var dark = false
    var latched = false
    var height: CGFloat = 104
    /// How round the key's lower corners are. The keys at the ends of the
    /// row follow the corner of the case beside them.
    var lowerLeft: CGFloat = 4
    var lowerRight: CGFloat = 4
    var onDown: () -> Void = {}
    var onUp: () -> Void = {}

    @State private var pressed = false
    @GestureState private var touching = false
    @AppStorage(Prefs.skin) private var skinName = Skin.standard.rawValue

    private var skin: Skin { Skin(rawValue: skinName) ?? Skin.standard }
    /// The lamp behind the play key while it is in.
    private static let lit = Color(red: 1.0, green: 0.88, blue: 0.42)
    private let wall: CGFloat = 18
    private let travel: CGFloat = 13

    var body: some View {
        let down = pressed || latched
        let top = topColors(down: down)
        VStack(spacing: 0) {
            // The top of the key, which the thumb presses
            ZStack {
                LinearGradient(colors: top, startPoint: .top, endPoint: .bottom)
                PlasticGrain(strength: 0.35)
                // The mark is moulded into the key: a dark hollow in the
                // plastic, with light on its lower edge.
                GeometryReader { face in
                    let size = min(face.size.width, face.size.height) * 0.36
                    Group {
                        if symbol == BeamedNotes.symbol {
                            BeamedNotes().frame(width: size * 1.05, height: size * 1.1)
                        } else {
                            Image(systemName: symbol).font(.system(size: size, weight: .heavy))
                        }
                    }
                    .foregroundColor(symbolColor(down: down))
                    .shadow(color: dark ? Color.black.opacity(0.9) : Color.white.opacity(down && accent ? 0 : 0.30),
                            radius: 0, y: dark ? -1 : 1)
                    .shadow(color: down && accent ? Self.lit : .clear, radius: 6)
                    .position(x: face.size.width / 2, y: face.size.height / 2)
                }
                // Lit along the back edge and the left, dark along the right
                UnevenRoundedRectangle(topLeadingRadius: 13, topTrailingRadius: 13)
                    .strokeBorder(LinearGradient(colors: [Color.white.opacity(down ? 0.08 : 0.38), .clear,
                                                          Color.black.opacity(0.5)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                // Pressed, the trough's back wall shades the key
                LinearGradient(colors: [Color.black.opacity(down ? 0.55 : 0), .clear],
                               startPoint: .top, endPoint: .center)
            }
            .frame(height: height - wall)
            // The front wall of the key, seen while it stands up
            LinearGradient(colors: wallColors, startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.22)).frame(height: 1) }
                .frame(height: down ? wall - travel : wall)
        }
        // Rounded over at the back, where the key meets the case
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 13, bottomLeadingRadius: lowerLeft,
                                          bottomTrailingRadius: lowerRight, topTrailingRadius: 13))
        .frame(height: height, alignment: .bottom)
        .shadow(color: .black.opacity(down ? 0.2 : 0.65), radius: down ? 1 : 5, y: down ? 1 : 5)
        .animation(.easeOut(duration: 0.08), value: down)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed {
                        pressed = true
                        onDown()
                    }
                }
                .updating($touching) { _, touching, _ in touching = true }
                .onEnded { _ in
                    pressed = false
                    if !latched { Haptics.keyUp() }
                    onUp()
                }
        )
        // A touch that is cancelled never ends: let the key up when the
        // finger is gone.
        .onChange(of: touching) { _, touching in
            if !touching, pressed {
                pressed = false
                onUp()
            }
        }
        .onDisappear { pressed = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(latched ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            onDown()
            onUp()
        }
    }

    private func topColors(down: Bool) -> [Color] {
        if accent { return down ? skin.accentDown : skin.accentUp }
        if dark {
            return down ? [Color(white: 0.07), Color(white: 0.04)] : [Color(white: 0.17), Color(white: 0.10)]
        }
        return down ? [Color(white: 0.20), Color(white: 0.14)] : [Color(white: 0.36), Color(white: 0.24)]
    }

    private var wallColors: [Color] {
        if accent { return skin.accentWall }
        if dark { return [Color(white: 0.07), Color(white: 0.02)] }
        return [Color(white: 0.16), Color(white: 0.06)]
    }

    private func symbolColor(down: Bool) -> Color {
        // The play key's mark lights up from behind while the tape plays.
        if down, accent { return Self.lit }
        // On the black key the mark is the lighter of the two, or it
        // would not be seen at all.
        return dark ? Color(white: down ? 0.34 : 0.50) : Color.black.opacity(0.78)
    }
}
