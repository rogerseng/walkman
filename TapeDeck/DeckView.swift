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
    @EnvironmentObject private var tour: Tour
    /// The phone's volume, which the fader on the panel sets.
    @StateObject private var volume = SystemVolume()
    @State private var showSettings = false
    @AppStorage(Prefs.skin) private var skinName = Skin.standard.rawValue
    var openShelf: () -> Void

    private var skin: Skin {
        let stored = Skin(rawValue: skinName) ?? Skin.standard
        return stored.isWheel ? Skin.standard : stored
    }

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
                    // For VoiceOver, which cannot double-tap the tape itself
                    .accessibilityElement()
                    .accessibilityLabel(model.hasTape
                                        ? "\(model.tapeTitle), side \(model.sideLetter)"
                                        : "No tape")
                    .accessibilityHint(model.hasTape ? "" : "Opens the tape shelf")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        if !model.hasTape { openShelf() }
                    }
                    .accessibilityAction(named: "Turn the tape over") { model.flipTape() }
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
                    // On a pale case, a dark plate behind the Duo's clock and
                    // status icons, which the system draws in white.
                    if rail, skin.needsStatusPlate {
                        RoundedRectangle(cornerRadius: 26)
                            .fill(Color.black.opacity(0.78))
                            .frame(width: railKeyWidth, height: 140)
                            .padding(railLeading ? .leading : .trailing, railOuterMargin)
                            .padding(.top, 16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                   alignment: railLeading ? .topLeading : .topTrailing)
                    }
                }
            )
            // The maker's name, moulded faintly into the top corner of the case
            .overlay(alignment: .topLeading) {
                Wordmark()
                    .foregroundColor(skin.mark)
                    .shadow(color: skin.engravingEdge.opacity(0.6), radius: 0.3, y: skin.engravingEdgeOffset)
                    .offset(x: 22 + (railLeading ? panelWidth : insets.leading), y: insets.top + 16)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            // A word in outline lettering above the window, on cases that have one
            .overlay(alignment: .topLeading) {
                if let word = skin.caseWord {
                    OutlinedWord(text: word, fill: skin.casing[1].opacity(1))
                        .frame(width: window.width)
                        .offset(x: window.minX, y: window.minY - 34)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            // Under the window: the song that is playing on an album tape
            // (its printed label has no room for it), or word that the tape
            // has run out.
            .overlay(alignment: .topLeading) {
                if let note = underWindowNote {
                    // The song, in plain type with a note beside it, so it
                    // reads on every case colour.
                    Label {
                        Text(note)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    } icon: {
                        Image(systemName: model.endOfSideNote == nil ? "music.note" : "stop.circle")
                            .font(.system(size: 13, weight: .bold))
                    }
                        .foregroundColor(skin.note)
                        .shadow(color: .black.opacity(skin == .yellow ? 0 : 0.6), radius: 2)
                        .frame(width: window.width)
                        .offset(x: window.minX, y: window.maxY + 14)
                        .allowsHitTesting(false)
                }
            }
            // Volume: on the solid panel, level with the window and as tall as it
            .overlay(alignment: .topLeading) {
                // Never under the keys, however narrow the phone
                let keysLeft = full.width - column
                let faderX = railLeading ? panelWidth - 70
                    : min(full.width - panelWidth + 22, keysLeft - 48 - 4)
                VolumeFader(volume: volume, playing: model.motion == .playing,
                            tempo: model.beatsPerMinute,
                            engraving: skin.engraving, engravingEdge: skin.engravingEdge,
                            engravingEdgeOffset: skin.engravingEdgeOffset)
                    .frame(width: 48, height: window.height)
                    .offset(x: faderX, y: window.minY)
                // Engraved under the fader
                Text("VOLUME")
                    .font(Typeface.displayFixed(7.5))
                    .tracking(1.6)
                    .foregroundColor(skin.engraving)
                    .shadow(color: skin.engravingEdge, radius: 0.3, y: skin.engravingEdgeOffset)
                    .frame(width: 48)
                    .offset(x: faderX, y: window.maxY + 9)
                    .accessibilityHidden(true)
            }
            // The tape has run out: say so in the window, with the way on
            .overlay(alignment: .topLeading) {
                if model.hasTape, model.sideEnded {
                    EndOfSideCard()
                        .frame(width: window.width - 28)
                        .position(x: window.midX, y: window.midY)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.sideEnded)
            // The tour: the tape lit up when it is the thing to touch, and
            // the card saying what to do
            .overlay(alignment: .topLeading) {
                if tour.step?.onTape == true {
                    TourPulse(corner: 20)
                        .frame(width: window.width, height: window.height)
                        .offset(x: window.minX, y: window.minY)
                }
            }
            .overlay(alignment: .bottomLeading) {
                TourCard(tour: tour)
                    .frame(width: max(240, window.width + 20))
                    .offset(x: max(10, window.minX - 10), y: -(insets.bottom + 14))
            }
            .environment(\.tourKey, tour.step?.key)
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        // The tour moves on when the listener has really done what it asked
        .onReceive(model.events) { event in
            switch event {
            case .inserted: tour.completed(.chooseTape)
            case .played: tour.completed(.play)
            case .stopped: tour.completed(.stop)
            case .skipped: tour.completed(.skip)
            case .wound: tour.completed(.wind)
            case .flipped: tour.completed(.flip)
            }
        }
        // A step that is already done when it comes up is passed over: a tape
        // picked from the shelf starts playing by itself, so play is done.
        .onChange(of: tour.step) { _, _ in catchUpTour() }
        .onAppear { catchUpTour() }
    }

    /// Moves the tour past whatever the deck is already doing.
    private func catchUpTour() {
        switch tour.step {
        case .chooseTape where model.hasTape: tour.completed(.chooseTape)
        case .play where model.motion == .playing: tour.completed(.play)
        default: break
        }
    }

    private var underWindowNote: String? {
        // The end of a side has its own card in the window.
        guard model.endOfSideNote == nil else { return nil }
        guard model.hasTape, model.printedLabel, !model.trackTitle.isEmpty else { return nil }
        return model.trackTitle
    }

    // MARK: Tape and casing

    /// The part of the cassette the window shows, in millimetres of its
    /// 100 x 63 shell: the label strip and both reels, and most of the shell
    /// at either end of them, out to the corner screws. The guide rollers
    /// and the head opening stay under the casing, next to the keys.
    private let windowOnCassette = CGRect(x: 17, y: 2.5, width: 72, height: 36.5)

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
                        // The turned cassette is longer than the screen is
                        // wide. Held to the screen's size here so it cannot
                        // widen this layer and push the casing and its window
                        // off centre.
                        .frame(width: size.width, height: size.height)
                } else {
                    emptyWell(upright: upright, length: 100 * scale)
                    // The prompt sits in the middle of the window, not of
                    // the well behind it.
                    VStack(spacing: 6) {
                        Image(systemName: "eject.fill").font(.system(size: 24))
                        Text("NO TAPE").font(Typeface.display(16)).tracking(3)
                        Text("Tap to choose one").font(.system(size: 11))
                    }
                    .foregroundColor(Color.white.opacity(0.5))
                    .position(x: window.midX, y: window.midY)
                }

                // The casing: smoked plastic with the window cut out of it
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: size))
                    path.addRoundedRect(in: window, cornerSize: CGSize(width: 20, height: 20))
                }
                .fill(LinearGradient(colors: skin.casing,
                                     startPoint: .topLeading, endPoint: .bottomTrailing),
                      style: FillStyle(eoFill: true))

                // Eighties stripes across the foot of the case
                if skin.hasStripes {
                    RetroStripes()
                        .frame(width: size.width, height: 30)
                        // Low on the case, clear of the song line under the window
                        .position(x: size.width / 2, y: min(size.height - 22, window.maxY + 92))
                        .allowsHitTesting(false)
                }

                // The window: shadow where the casing overhangs the tape,
                // a trace of glass, and the bright cut edge of the plastic.
                Group {
                    opening.strokeBorder(Color.black.opacity(0.75), lineWidth: 8).blur(radius: 5)
                        .clipShape(opening)
                    opening.fill(LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.02), .clear],
                                                startPoint: .topLeading, endPoint: .center))
                    opening.strokeBorder(LinearGradient(colors: skin.windowEdge,
                                                        startPoint: .topLeading, endPoint: .bottomTrailing),
                                         lineWidth: 2.5)
                        .shadow(color: skin.hasStripes ? Skin.hotPink.opacity(0.8) : .clear, radius: 6)
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
        // Faint in the empty well; they show properly once a tape is on them.
        let spindle = DriveSpindle(u: u).opacity(0.28)
        let layout = upright ? AnyLayout(VStackLayout(spacing: 33 * u)) : AnyLayout(HStackLayout(spacing: 33 * u))
        return ZStack {
            layout {
                spindle
                spindle
            }
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
            TapeKey(symbol: "gearshape.fill", label: "Settings", dark: true,
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
            edge.fill(LinearGradient(colors: skin.panel, startPoint: .top, endPoint: .bottom))
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

/// Five bands of colour, the stripe that ran across everything in the 1980s.
struct RetroStripes: View {
    private let bands: [Color] = [
        Color(red: 0.11, green: 0.60, blue: 0.67),
        Color(red: 0.96, green: 0.91, blue: 0.76),
        Color(red: 0.95, green: 0.62, blue: 0.02),
        Color(red: 0.89, green: 0.34, blue: 0.18),
        Color(red: 0.65, green: 0.15, blue: 0.22)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                band
            }
        }
        .accessibilityHidden(true)
    }
}

/// The name of the app, as lettering.
struct Wordmark: View {
    var size: CGFloat = 22

    var body: some View {
        Text("Cassety")
            .font(Typeface.displayFixed(size))
            .tracking(size * 0.02)
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
                     printColor: model.printColor.map { Color(cgColor: $0) },
                     onSpindles: true)
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
            // The two-note mark is the one Apple Music itself goes by.
            TapeKey(symbol: ejectRemovesTape ? "eject.fill" : BeamedNotes.symbol,
                    label: ejectRemovesTape ? "EJECT" : "Apple Music library",
                    height: keyHeight, showsLabel: labels, corner: corner, symbolSize: symbol,
                    onDown: {
                        model.ejectKey(removeTape: ejectRemovesTape)
                        onEject()
                    })
            if let onSettings {
                TapeKey(symbol: "gearshape.fill", label: "Settings", dark: true,
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
    /// A black key, for one that should sit apart from the transport keys.
    var dark = false
    var latched = false
    var height: CGFloat = 62
    var showsLabel = true
    var corner: CGFloat = 7
    var symbolSize: CGFloat = 17
    var onDown: () -> Void = {}
    var onUp: () -> Void = {}

    @State private var pressed = false
    @AppStorage(Prefs.skin) private var skinName = Skin.standard.rawValue
    /// The tour lights up the key it wants pressed.
    @Environment(\.tourKey) private var tourKey

    private var skin: Skin { Skin(rawValue: skinName) ?? Skin.standard }

    /// How far the key moves when pressed.
    private let travel: CGFloat = 8

    var body: some View {
        let down = pressed || latched
        VStack(spacing: 4) {
            if symbol == BeamedNotes.symbol {
                // The library key: a pair of joined notes, drawn here
                BeamedNotes().frame(width: symbolSize * 1.05, height: symbolSize * 1.1)
            } else {
                Image(systemName: symbol).font(.system(size: symbolSize, weight: .bold))
            }
            if showsLabel, height >= 50 {
                Text(label).font(Typeface.displayFixed(8)).lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        // The symbol is engraved and filled with paint, so it has a thin
        // edge of shadow or light where the cut catches it. Pressed in, the
        // paint goes black, except on the play key, which lights up from
        // behind while the tape plays.
        .foregroundColor(symbolColor(down: down))
        .shadow(color: Color.black.opacity(accent ? 0.45 : 0.75), radius: 0.4, y: -0.8)
        .shadow(color: down && accent ? Self.lit : .clear, radius: 5)
        .shadow(color: down && accent ? Self.lit.opacity(0.7) : .clear, radius: 12)
        .scaleEffect(down ? 0.92 : 1)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        // The face is shorter than the key, leaving its side showing below.
        .frame(height: height - travel)
        .background(KeyCap(corner: corner, colors: keyColors(down: down), sunk: down))
        // Pressed, the face sinks until the side is hidden.
        .offset(y: down ? travel : 0)
        .frame(height: height, alignment: .top)
        .background(
            // The side of the key
            RoundedRectangle(cornerRadius: corner)
                .fill(LinearGradient(colors: wallColors, startPoint: .top, endPoint: .bottom))
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
        .overlay {
            if tourKey == symbol { TourPulse(corner: corner + 3) }
        }
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
        .accessibilityLabel(spokenLabel)
        .accessibilityAddTraits(latched ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            onDown()
            onUp()
        }
    }

    private var wallColors: [Color] {
        if accent { return skin.accentWall }
        if dark { return [Color(white: 0.05), Color(white: 0.02)] }
        return [Color(white: 0.17), Color(white: 0.09)]
    }

    /// The short legends on the keys, said in full.
    private var spokenLabel: String {
        switch label {
        case "FF": return "Fast forward"
        case "REW": return "Rewind"
        default: return label.count > 1 && label == label.uppercased() ? label.capitalized : label
        }
    }

    /// The glow of the lamp behind the play key while it is in.
    private static let lit = Color(red: 1.0, green: 0.88, blue: 0.42)

    private func symbolColor(down: Bool) -> Color {
        guard down else { return Color(white: 0.96) }
        if accent { return Self.lit }
        // Black paint on a black key would vanish, so it only dims there.
        return dark ? Color(white: 0.38) : Color(white: 0.04)
    }

    private func keyColors(down: Bool) -> [Color] {
        if accent {
            // The play key: orange as on the decks this is modelled on, or
            // hot pink on the neon skin
            return down ? skin.accentDown : skin.accentUp
        }
        if dark {
            return down
                ? [Color(white: 0.06), Color(white: 0.03)]
                : [Color(white: 0.15), Color(white: 0.08)]
        }
        // Dark grey plastic, like the panel the keys sit in
        return down
            ? [Color(white: 0.22), Color(white: 0.16)]
            : [Color(white: 0.41), Color(white: 0.28)]
    }
}

/// The top face of a key: moulded plastic with a fine grain, a slightly
/// dished middle, and an edge that is lit from above.
private struct KeyCap: View {
    let corner: CGFloat
    let colors: [Color]
    /// Pressed in: the face sits down inside its well, so the well's upper
    /// wall throws a shadow across it and its top edge is no longer lit.
    var sunk = false

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
            shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(sunk ? 0.10 : 0.62),
                                                       Color.white.opacity(0.08),
                                                       Color.black.opacity(0.32)],
                                              startPoint: .top, endPoint: .bottom),
                               lineWidth: 1.2)
            if sunk {
                shape.fill(LinearGradient(stops: [
                    .init(color: Color.black.opacity(0.72), location: 0),
                    .init(color: Color.black.opacity(0.30), location: 0.25),
                    .init(color: .clear, location: 0.55)
                ], startPoint: .top, endPoint: .bottom))
                // The sides of the well shade the edges too
                shape.strokeBorder(Color.black.opacity(0.35), lineWidth: 3).blur(radius: 2).clipShape(shape)
            }
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

/// The app's ordinary button, eighties style: hot pink with a hard yellow
/// shadow that it sinks onto when pressed.
struct PlainKeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PlainKey(label: configuration.label, down: configuration.isPressed)
    }

    /// Drawn in the chosen skin's colours: its accent for the face and its
    /// second colour for the hard shadow.
    private struct PlainKey<Label: View>: View {
        let label: Label
        let down: Bool
        @Environment(\.playerTheme) private var theme

        var body: some View {
            label
                .font(Typeface.display(16))
                .foregroundColor(theme.accentInkColor)
                .background(RoundedRectangle(cornerRadius: 10).fill(theme.accentColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(theme.accentInkColor, lineWidth: 1.5)
                )
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.secondaryColor)
                        .offset(x: down ? 0 : 4, y: down ? 0 : 4)
                )
                .offset(x: down ? 4 : 0, y: down ? 4 : 0)
                .animation(.easeOut(duration: 0.08), value: down)
        }
    }
}

/// Lettering drawn as a white outline, as if printed on painted metal. The
/// outline is the word in white nudged each way, with the word in the case
/// colour laid over the middle.
struct OutlinedWord: View {
    let text: String
    let fill: Color

    private var word: some View {
        Text(text)
            .font(Typeface.displayFixed(23))
            .tracking(1.5)
    }

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { step in
                let angle = Double(step) * .pi / 4
                word.foregroundColor(.white.opacity(0.9))
                    .offset(x: CGFloat(cos(angle)) * 1.1, y: CGFloat(sin(angle)) * 1.1)
            }
            word.foregroundColor(fill)
        }
    }
}

/// Shown over the tape when a side has run out: which side ended, and a key
/// to turn the tape over (or word that the other side is blank).
struct EndOfSideCard: View {
    @EnvironmentObject private var model: PlayerModel
    @Environment(\.playerTheme) private var theme

    var body: some View {
        let other = model.sideLetter == "A" ? "B" : "A"
        VStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.accentColor)
            Text("End of side \(model.sideLetter)")
                .font(Typeface.display(20))
                .foregroundColor(.white)
            if model.canFlip {
                Text("Turn the tape over to keep listening.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                Button {
                    model.flipTape()
                } label: {
                    Text("Flip to side \(other)")
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                }
                .buttonStyle(PlainKeyButtonStyle())
                .padding(.top, 2)
            } else {
                Text("The other side is blank. Rewind, or choose another tape.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.84))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.accentColor.opacity(0.7), lineWidth: 1.5))
        )
        .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
    }
}

/// Two notes joined by a beam: the mark on the key that opens the library.
/// It takes the colour of the text around it.
struct BeamedNotes: View {
    /// The name the library key goes by where keys are told apart by symbol.
    nonisolated static let symbol = "cassety.notes"

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let head = CGSize(width: w * 0.36, height: h * 0.25)
            let stem = w * 0.085
            ZStack {
                // Stems and the beam across their tops
                Path { path in
                    path.addRect(CGRect(x: w * 0.36 - stem, y: h * 0.17, width: stem, height: h * 0.66))
                    path.addRect(CGRect(x: w * 0.98 - stem, y: h * 0.05, width: stem, height: h * 0.66))
                    path.move(to: CGPoint(x: w * 0.36 - stem, y: h * 0.14))
                    path.addLine(to: CGPoint(x: w * 0.98, y: h * 0.02))
                    path.addLine(to: CGPoint(x: w * 0.98, y: h * 0.20))
                    path.addLine(to: CGPoint(x: w * 0.36 - stem, y: h * 0.32))
                    path.closeSubpath()
                }
                // Heads, tilted as on a stave
                Ellipse()
                    .frame(width: head.width, height: head.height)
                    .rotationEffect(.degrees(-22))
                    .position(x: w * 0.19, y: h * 0.85)
                Ellipse()
                    .frame(width: head.width, height: head.height)
                    .rotationEffect(.degrees(-22))
                    .position(x: w * 0.81, y: h * 0.73)
            }
        }
        .accessibilityHidden(true)
    }
}

