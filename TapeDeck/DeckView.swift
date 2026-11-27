import SwiftUI

/// The closed phone: the whole screen is the body of a tape player in dark
/// plastic with the cassette inside it. The cassette is as large as the screen
/// allows and runs underneath the body and the keys. The smoked body covers
/// most of it, dimly showing what is underneath, and a clear window over the
/// label and reels shows the tape itself.
///
/// Laid out for the iPhone Duo's outer display: 466 x 678 points, with an
/// 84 point column down one side that iOS reports as a safe area inset. The
/// camera, clock and status icons sit at the top of that column, so the keys
/// go in the column underneath them. On a phone without that column the keys
/// get a strip of their own inside the safe area.
struct DeckView: View {
    @EnvironmentObject private var model: PlayerModel
    /// The phone's volume, which the fader on the panel sets.
    @StateObject private var volume = SystemVolume()
    @State private var showSettings = false
    var openShelf: () -> Void

    /// Width of the key column on phones that have no side rail.
    private let stripWidth: CGFloat = 78
    /// Keys in the Duo's rail are 66 points wide, centred 48 points in from
    /// the screen edge like the system's own status pill, and up to 84 tall.
    private let railKeyWidth: CGFloat = 66
    private let railOuterMargin: CGFloat = 15
    private let bigKeyHeight: CGFloat = 84
    private let keyGap: CGFloat = 10
    /// Height kept clear at the top of the rail for the camera, clock and
    /// status icons. Measured from a Duo screenshot, where the status pill
    /// ends about 154 points down; not a published figure.
    private let railStatusHeight: CGFloat = 180

    var body: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let rail = max(insets.leading, insets.trailing) >= 60
            let railLeading = rail && insets.leading > insets.trailing
            let full = CGSize(width: geo.size.width + insets.leading + insets.trailing,
                              height: geo.size.height + insets.top + insets.bottom)
            let window = windowRect(in: full)
            // The solid side of the case starts just past the tape window and
            // runs to the edge, so it carries the volume fader and the keys.
            let column = rail ? max(insets.leading, insets.trailing) : stripWidth + insets.trailing
            let panelWidth = max(column, railLeading ? window.minX - 6 : full.width - window.maxX - 6)
            HStack(spacing: 0) {
                if railLeading { keyColumn(insets: insets, rail: true, leading: true) }
                // The face itself is drawn in the background, full screen.
                // Double-tap the tape to turn it over.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        model.flipTape()
                    }
                    .onTapGesture {
                        if !model.hasTape { openShelf() }
                    }
                if !railLeading { keyColumn(insets: insets, rail: rail, leading: false) }
            }
            .frame(width: full.width, height: full.height)
            .background(
                ZStack {
                    Color(white: 0.03)
                    tapeUnderCasing
                    clearCase
                    casePanel(seamOnLeading: !railLeading)
                        .frame(width: panelWidth)
                        .frame(maxWidth: .infinity, alignment: railLeading ? .leading : .trailing)
                }
            )
            // Under the window: the song that is playing on an album tape
            // (its printed label has no room for it), or word that the tape
            // has run out.
            .overlay(alignment: .topLeading) {
                if let note = underWindowNote {
                    Text(note)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: window.width)
                        .offset(x: window.minX, y: window.maxY + 14)
                        .allowsHitTesting(false)
                }
            }
            // Volume: on the solid panel, level with the window and as tall as it
            .overlay(alignment: .topLeading) {
                let faderX = railLeading ? panelWidth - 70 : full.width - panelWidth + 22
                VolumeFader(volume: volume)
                    .frame(width: 48, height: window.height)
                    .offset(x: faderX, y: window.minY)
                // Engraved under the fader
                Text("VOLUME")
                    .font(.system(size: 6.5, weight: .bold))
                    .tracking(1.6)
                    .foregroundColor(Color.white.opacity(0.5))
                    .shadow(color: .black.opacity(0.8), radius: 0.3, y: -0.7)
                    .frame(width: 48)
                    .offset(x: faderX, y: window.maxY + 9)
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var underWindowNote: String? {
        if let ended = model.endOfSideNote { return ended }
        guard model.hasTape, model.printedLabel, !model.trackTitle.isEmpty else { return nil }
        return model.trackTitle
    }

    // MARK: Tape and casing

    /// The part of the cassette the window shows, in millimetres of its
    /// 100 x 63 shell: the label strip and both reels. Everything else, the
    /// ends, the guide rollers and the head opening, is under the casing.
    private let windowOnCassette = CGRect(x: 19, y: 5.5, width: 62, height: 33.5)

    /// The cassette filling the whole screen (on end when the screen is
    /// taller than wide, head opening toward the keys), with the player's
    /// smoked casing over it and a window cut through the casing.
    private var tapeUnderCasing: some View {
        GeometryReader { geo in
            let size = geo.size
            let upright = size.height > size.width
            let scale = tapeScale(in: size)
            let window = windowRect(in: size)
            let opening = RoundedRectangle(cornerRadius: 20)
            ZStack {
                if model.hasTape {
                    DeckCassette()
                        .frame(width: 100 * scale, height: 63 * scale)
                        .rotationEffect(.degrees(upright ? -90 : 0))
                        // Turning the tape over: it swings round its long edge.
                        .rotation3DEffect(.degrees(model.flipAngle),
                                          axis: (x: upright ? 1 : 0, y: upright ? 0 : 1, z: 0),
                                          perspective: 0.4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    emptyWell(upright: upright, length: 100 * scale)
                }

                // The casing: smoked plastic with the window cut out of it
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: size))
                    path.addRoundedRect(in: window, cornerSize: CGSize(width: 20, height: 20))
                }
                .fill(LinearGradient(colors: [Color(white: 0.16).opacity(0.86),
                                              Color(white: 0.08).opacity(0.86),
                                              Color(white: 0.05).opacity(0.86)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing),
                      style: FillStyle(eoFill: true))

                // The window: shadow where the casing overhangs the tape,
                // a trace of glass, and the bright cut edge of the plastic.
                Group {
                    opening.strokeBorder(Color.black.opacity(0.75), lineWidth: 8).blur(radius: 5)
                        .clipShape(opening)
                    opening.fill(LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.02), .clear],
                                                startPoint: .topLeading, endPoint: .center))
                    opening.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0.18),
                                                                 Color.white.opacity(0.45)],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing),
                                         lineWidth: 2.5)
                    // The cut has thickness: a dark inner face and a second lit lip
                    opening.strokeBorder(Color.black.opacity(0.55), lineWidth: 1.5).padding(2.5)
                    RoundedRectangle(cornerRadius: 17)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                        .padding(4)
                    opening.strokeBorder(Color.white.opacity(0.10), lineWidth: 1).padding(-6)
                }
                .frame(width: window.width, height: window.height)
                .position(x: window.midX, y: window.midY)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    /// How many points one millimetre of cassette takes: as big as the screen
    /// allows. The cassette may run a little past the edges, but never far
    /// enough to lose the label.
    private func tapeScale(in size: CGSize) -> CGFloat {
        let long = max(size.width, size.height)
        let short = min(size.width, size.height)
        let fit = min(long / 100, short / 63)
        let fill = max(long / 100, short / 63)
        return min(fill, fit * 1.04)
    }

    /// Where `windowOnCassette` lands on screen.
    private func windowRect(in size: CGSize) -> CGRect {
        let upright = size.height > size.width
        let scale = tapeScale(in: size)
        let w = windowOnCassette
        if upright {
            // Turned a quarter turn: the cassette's top edge is at the left
            // of the screen and its left end is at the bottom.
            let left = size.width / 2 - 63 * scale / 2
            let bottom = size.height / 2 + 100 * scale / 2
            return CGRect(x: left + w.minY * scale, y: bottom - w.maxX * scale,
                          width: w.height * scale, height: w.width * scale)
        }
        let left = size.width / 2 - 100 * scale / 2
        let top = size.height / 2 - 63 * scale / 2
        return CGRect(x: left + w.minX * scale, y: top + w.minY * scale,
                      width: w.width * scale, height: w.height * scale)
    }

    /// The well with nothing in it: the two drive spindles and a prompt.
    private func emptyWell(upright: Bool, length: CGFloat) -> some View {
        let u = length / 100
        let spindle = ZStack {
            Circle().fill(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.2)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            ForEach(0..<3, id: \.self) { prong in
                Capsule().fill(Color(white: 0.75))
                    .frame(width: 1.6 * u, height: 4.4 * u)
                    .offset(y: -3.4 * u)
                    .rotationEffect(.degrees(Double(prong) * 120))
            }
            Circle().fill(Color(white: 0.12)).frame(width: 2.4 * u, height: 2.4 * u)
        }
        .frame(width: 8 * u, height: 8 * u)
        let layout = upright ? AnyLayout(VStackLayout(spacing: 33 * u)) : AnyLayout(HStackLayout(spacing: 33 * u))
        return ZStack {
            layout {
                spindle
                spindle
            }
            VStack(spacing: 6) {
                Image(systemName: "eject.fill").font(.system(size: 24))
                Text("NO TAPE").font(.system(size: 14, weight: .bold)).tracking(3)
                Text("Tap to choose one").font(.system(size: 11))
            }
            .foregroundColor(Color.white.opacity(0.5))
        }
    }

    /// The surface of the body: a fixed reflection and the glare that follows
    /// the phone as it moves.
    private var clearCase: some View {
        ZStack {
            LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.02), .clear],
                           startPoint: .topLeading, endPoint: .center)
            GlassShimmer()
            // No drawn edge here: the phone's own corners are the edge of
            // the player, and a drawn one never quite matches their curve.
        }
        .allowsHitTesting(false)
    }

    // MARK: Keys

    /// Six keys of one size: play, stop, fast forward, rewind, the tape
    /// library, and settings.
    private func keys(height: CGFloat) -> some View {
        VStack(spacing: keyGap) {
            TransportKeys(vertical: true, keyHeight: height, bare: true, big: true,
                          spacing: keyGap, onEject: openShelf)
            TapeKey(symbol: "gearshape.fill", label: "Settings",
                    height: height, showsLabel: false, corner: 17, symbolSize: 23,
                    onDown: {
                        Haptics.keyDown()
                        showSettings = true
                    })
        }
    }

    private func keyHeight(room: CGFloat) -> CGFloat {
        min(bigKeyHeight, max(36, (room - 5 * keyGap) / 6))
    }

    /// The side of the player that carries the volume fader and the keys:
    /// solid plastic, not see through, with a seam where it meets the clear
    /// part of the case.
    private func casePanel(seamOnLeading: Bool) -> some View {
        let edge = BowedPanel(bow: 26, bowOnLeading: seamOnLeading)
        return ZStack {
            edge.fill(LinearGradient(colors: [Color(white: 0.20), Color(white: 0.13), Color(white: 0.09)],
                                     startPoint: .top, endPoint: .bottom))
            edge.fill(LinearGradient(colors: [Color.white.opacity(0.07), .clear],
                                     startPoint: seamOnLeading ? .leading : .trailing,
                                     endPoint: .center))
            PlasticGrain(strength: 0.5).clipShape(edge)
            // The seam, following the curve: a dark cut with a lit lip
            BowedPanel(bow: 26, bowOnLeading: seamOnLeading, edgeOnly: true)
                .stroke(Color.black.opacity(0.8), lineWidth: 2.5)
            BowedPanel(bow: 26, bowOnLeading: seamOnLeading, edgeOnly: true)
                .stroke(Color.white.opacity(0.30), lineWidth: 1)
                .offset(x: seamOnLeading ? 1.6 : -1.6)
        }
        .shadow(color: .black.opacity(0.65), radius: 7, x: seamOnLeading ? -3 : 3)
    }

    /// The column of keys. In the Duo's rail it starts below the camera and
    /// clock; on other phones it is a strip inside the safe area.
    @ViewBuilder
    private func keyColumn(insets: EdgeInsets, rail: Bool, leading: Bool) -> some View {
        if rail {
            let width = max(insets.leading, insets.trailing)
            let inner = max(0, width - railKeyWidth - railOuterMargin)
            GeometryReader { geo in
                let room = geo.size.height - railStatusHeight - insets.bottom - 12
                VStack(spacing: 0) {
                    Color.clear.frame(height: railStatusHeight)
                    keys(height: keyHeight(room: room))
                    Spacer(minLength: 0)
                }
                .frame(width: railKeyWidth)
                .padding(.leading, leading ? railOuterMargin : inner)
                .padding(.trailing, leading ? inner : railOuterMargin)
            }
            .frame(width: width)
        } else {
            GeometryReader { geo in
                let room = geo.size.height - insets.top - insets.bottom - 24
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    keys(height: keyHeight(room: room))
                    Spacer(minLength: 0)
                }
                .padding(.top, insets.top + 12)
                .padding(.bottom, insets.bottom + 12)
                .padding(.leading, 8)
                .padding(.trailing, 8 + insets.trailing)
                .frame(width: stripWidth + insets.trailing, height: geo.size.height)
            }
            .frame(width: stripWidth + insets.trailing)
        }
    }
}

/// The solid side of the case. Its inner edge is a long shallow curve that
/// bows toward the tape at mid height and falls back at the top and bottom.
struct BowedPanel: Shape {
    /// How far the ends of the edge sit back from its furthest point.
    var bow: CGFloat
    var bowOnLeading: Bool
    /// Just the curved edge, for drawing the seam.
    var edgeOnly = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // A quadratic curve passes a quarter of the way to its control
        // point from the chord, so the control sits a full bow beyond the rect.
        let ends = bowOnLeading ? rect.minX + bow : rect.maxX - bow
        let pull = bowOnLeading ? rect.minX - bow : rect.maxX + bow
        let far = bowOnLeading ? rect.maxX : rect.minX
        path.move(to: CGPoint(x: ends, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: ends, y: rect.maxY),
                          control: CGPoint(x: pull, y: rect.midY))
        if !edgeOnly {
            path.addLine(to: CGPoint(x: far, y: rect.maxY))
            path.addLine(to: CGPoint(x: far, y: rect.minY))
            path.closeSubpath()
        }
        return path
    }
}

/// The cassette that is in the deck, drawn from the player's state.
struct DeckCassette: View {
    @EnvironmentObject private var model: PlayerModel

    var body: some View {
        CassetteView(title: model.tapeTitle,
                     // A printed label carries the album's artist; a handwritten
                     // one has room for whatever is playing.
                     subtitle: model.printedLabel ? model.tapeSubtitle : model.trackLine,
                     progress: model.progress,
                     motion: model.motion,
                     side: model.sideLetter,
                     printed: model.printedLabel,
                     tint: model.labelColor.map { Color(cgColor: $0) },
                     printColor: model.printColor.map { Color(cgColor: $0) })
    }
}

/// The transport keys, in a column for the closed phone or a row for the open
/// one. Stop holds the tape where it is, so pressing play carries on from there.
struct TransportKeys: View {
    @EnvironmentObject private var model: PlayerModel
    var vertical: Bool
    var keyHeight: CGFloat = 62
    /// Without the tray behind the keys, for places that supply their own.
    var bare = false
    /// Large rounded keys, with play and stop as a pair of latching keys.
    var big = false
    var spacing: CGFloat = 6
    /// True where eject should take the tape out; false where it only opens
    /// the shelf to pick another.
    var ejectRemovesTape = false
    /// If set, a settings key is added at the end.
    var onSettings: (() -> Void)?
    var onEject: () -> Void = {}

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: spacing)) : AnyLayout(HStackLayout(spacing: spacing))
        let corner: CGFloat = big ? 17 : 7
        let symbol: CGFloat = big ? 23 : 17
        let labels = !vertical && !big
        layout {
            if big {
                // Play and stop work as a pair: pressing one in lets the
                // other out, so one of them is always down while a tape is in.
                TapeKey(symbol: "play.fill", label: "Play",
                        accent: true, latched: model.motion == .playing,
                        height: keyHeight, showsLabel: false, corner: corner, symbolSize: symbol,
                        onDown: { model.playKey() })
                TapeKey(symbol: "stop.fill", label: "Stop",
                        latched: model.hasTape && (model.motion == .paused || model.motion == .stopped),
                        height: keyHeight, showsLabel: false, corner: corner, symbolSize: symbol,
                        onDown: { model.stopKey() })
            } else {
                TapeKey(symbol: "play.fill", label: "PLAY", accent: true, latched: model.motion == .playing,
                        height: keyHeight, showsLabel: labels, onDown: { model.playKey() })
                TapeKey(symbol: "pause.fill", label: "PAUSE", latched: model.motion == .paused,
                        height: keyHeight, showsLabel: labels, onDown: { model.pauseKey() })
            }
            TapeKey(symbol: "forward.fill", label: "FF", latched: model.motion == .fastForward,
                    height: keyHeight, showsLabel: labels, corner: corner, symbolSize: symbol,
                    onDown: { model.seekKeyDown(forward: true) },
                    onUp: { model.seekKeyUp(forward: true) })
            TapeKey(symbol: "backward.fill", label: "REW", latched: model.motion == .rewind,
                    height: keyHeight, showsLabel: labels, corner: corner, symbolSize: symbol,
                    onDown: { model.seekKeyDown(forward: false) },
                    onUp: { model.seekKeyUp(forward: false) })
            // On the closed phone this key opens the tape library; where it
            // takes the tape out, it is an eject key.
            TapeKey(symbol: ejectRemovesTape ? "eject.fill" : "music.note.list",
                    label: ejectRemovesTape ? "EJECT" : "Tape library",
                    height: keyHeight, showsLabel: labels, corner: corner, symbolSize: symbol,
                    onDown: {
                        model.ejectKey(removeTape: ejectRemovesTape)
                        onEject()
                    })
            if let onSettings {
                TapeKey(symbol: "gearshape.fill", label: "Settings",
                        height: keyHeight, showsLabel: labels, corner: corner, symbolSize: symbol,
                        onDown: {
                            Haptics.keyDown()
                            onSettings()
                        })
            }
        }
        .padding(bare ? 0 : 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(bare ? 0 : 0.28)))
    }

    static func clock(_ time: TimeInterval) -> String {
        let total = Int(max(time, 0))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// One mechanical key, moulded in solid plastic. It reports press and release separately so rewind and
/// fast forward can tell a tap from a hold, and stays down while latched.
struct TapeKey: View {
    var symbol: String
    var label: String
    var accent = false
    var latched = false
    var height: CGFloat = 62
    var showsLabel = true
    var corner: CGFloat = 7
    var symbolSize: CGFloat = 17
    var onDown: () -> Void = {}
    var onUp: () -> Void = {}

    @State private var pressed = false

    /// How far the key moves when pressed.
    private let travel: CGFloat = 5

    var body: some View {
        let down = pressed || latched
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: symbolSize, weight: .bold))
            if showsLabel, height >= 50 {
                Text(label).font(.system(size: 7, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        // The symbol is engraved and filled with paint, so it has a thin
        // edge of shadow or light where the cut catches it.
        .foregroundColor(accent ? Color(white: 0.12) : Color(white: 0.94))
        .shadow(color: accent ? Color.white.opacity(0.65) : Color.black.opacity(0.75),
                radius: 0.4, y: accent ? 0.8 : -0.8)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        // The face is shorter than the key, leaving its side showing below.
        .frame(height: height - travel)
        .background(KeyCap(corner: corner, colors: keyColors(down: down)))
        // Pressed, the face sinks until the side is hidden.
        .offset(y: down ? travel - 1 : 0)
        .frame(height: height, alignment: .top)
        .background(
            // The side of the key
            RoundedRectangle(cornerRadius: corner)
                .fill(LinearGradient(colors: accent ? [Color(white: 0.55), Color(white: 0.36)]
                                                    : [Color(white: 0.17), Color(white: 0.09)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(down ? 0.25 : 0.6), radius: down ? 1.5 : 4, y: down ? 1 : 4)
        )
        .background(
            // The well the key sits in, cut into the panel
            RoundedRectangle(cornerRadius: corner + 3)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: corner + 3)
                        .strokeBorder(LinearGradient(colors: [Color.black.opacity(0.9), Color.white.opacity(0.16)],
                                                     startPoint: .top, endPoint: .bottom),
                                      lineWidth: 1)
                )
                .padding(-3)
        )
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
                .onEnded { _ in
                    pressed = false
                    if !latched { Haptics.keyUp() }
                    onUp()
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onDown()
            onUp()
        }
    }

    private func keyColors(down: Bool) -> [Color] {
        if accent {
            // The play key: plain pale plastic, so it stands out without colour
            return down
                ? [Color(white: 0.74), Color(white: 0.64)]
                : [Color(white: 0.92), Color(white: 0.74)]
        }
        // Dark plastic, like the panel the keys sit in
        return down
            ? [Color(white: 0.30), Color(white: 0.22)]
            : [Color(white: 0.41), Color(white: 0.28)]
    }
}

/// The top face of a key: moulded plastic with a fine grain, a slightly
/// dished middle, and an edge that is lit from above.
private struct KeyCap: View {
    let corner: CGFloat
    let colors: [Color]

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner)
        ZStack {
            shape.fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            PlasticGrain().clipShape(shape)
            // The dish: shaded at the top of the hollow, lit at the bottom
            RoundedRectangle(cornerRadius: max(2, corner - 5))
                .fill(LinearGradient(colors: [Color.black.opacity(0.14), .clear, Color.white.opacity(0.09)],
                                     startPoint: .top, endPoint: .bottom))
                .padding(5)
            shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.62), Color.white.opacity(0.08),
                                                       Color.black.opacity(0.32)],
                                              startPoint: .top, endPoint: .bottom),
                               lineWidth: 1.2)
        }
    }
}

/// Fine moulded grain, laid over a plastic surface.
struct PlasticGrain: View {
    var strength = 0.45

    var body: some View {
        Image("Grain")
            .resizable(resizingMode: .tile)
            .blendMode(.overlay)
            .opacity(strength)
            .allowsHitTesting(false)
    }
}

/// A small round button in the same clear plastic as the case.
struct ClearButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 38, height: 38)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// A plain light button, for the few places that need an ordinary one.
struct PlainKeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(Color(white: 0.10))
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(LinearGradient(colors: [Color(white: 0.96), Color(white: 0.76)],
                                         startPoint: .top, endPoint: .bottom))
                    .brightness(configuration.isPressed ? -0.15 : 0)
            )
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.black.opacity(0.35), lineWidth: 1))
            .offset(y: configuration.isPressed ? 2 : 0)
    }
}
