import MusicKit
import SwiftUI

/// The closed phone as an MP3 player: a small display of menus, and a dial to
/// scroll them with. Underneath it is the same tape deck, with the same two
/// sides, flipping and mixtapes.
///
/// It comes in two forms.
///
/// The jog dial player is the one people choose in the app. A knurled metal
/// dial turns to scroll and presses to select, the keys sit apart from it in
/// the same column as the tape player's, and the display is amber on black.
///
/// The click wheel player is kept for personal builds only (see
/// `Skin.includesClickWheel`): a ring with its four buttons on it and a
/// white display. It is left out of the App Store build.
struct MenuPlayerView: View {
    /// True for the jog dial player, false for the click wheel one.
    var jog = true

    @EnvironmentObject private var model: PlayerModel
    @StateObject private var volume = SystemVolume()
    @AppStorage(Prefs.skin) private var skinName = Skin.smoke.rawValue
    @State private var showSettings = false

    // Where you are in the menus: each level and the row chosen on it.
    @State private var stack: [Screen] = [.root]
    @State private var chosen: [Int] = [0]
    @State private var tops: [Int] = [0]

    // The turn in progress
    @State private var zone: Zone?
    @State private var lastAngle = 0.0
    @State private var turned = 0.0
    @State private var pending = 0.0
    @State private var scrolling = false
    /// How far the dial has been turned in all, so it can be drawn turned.
    @State private var dialAngle = 0.0

    private let rowsShown = 7
    /// Degrees of turn for one step down a list.
    private let step = 24.0

    // The Duo's rail, as in the tape player
    private let railKeyWidth: CGFloat = 66
    private let railOuterMargin: CGFloat = 15
    private let railStatusHeight: CGFloat = 180
    private let stripWidth: CGFloat = 78
    private let keyGap: CGFloat = 10

    private var skin: Skin {
        let stored = Skin(rawValue: skinName) ?? .smoke
        if jog { return stored.isWheel ? .smoke : stored }
        return stored.isWheel ? stored : .wheelBlack
    }

    enum Screen: Equatable {
        case root, music, mixtapes, playlists, albums, nowPlaying

        var title: String {
            switch self {
            case .root: return "Cassety"
            case .music: return "Music"
            case .mixtapes: return "Mixtapes"
            case .playlists: return "Playlists"
            case .albums: return "Albums"
            case .nowPlaying: return "Now Playing"
            }
        }
    }

    private enum Zone { case centre, top, bottom, left, right, dial }

    /// One line of a menu.
    private struct Row: Identifiable {
        enum Action {
            case open(Screen)
            case play(Tape)
            case flip
            case settings
            case connect
            case nothing
        }

        let id: String
        let title: String
        var detail = ""
        let action: Action

        var opens: Bool {
            if case .open = action { return true }
            return false
        }
    }

    /// The colours of the display.
    private struct Display {
        var paper: Color
        var ink: Color
        var barTop: Color
        var barBottom: Color
        var barInk: Color
        var litTop: Color
        var litBottom: Color
        var litInk: Color
        var track: Color
        var glow: Color
    }

    private var display: Display {
        let amber = Color(red: 1.0, green: 0.70, blue: 0.20)
        if jog {
            // Amber on black, like the display of an old hi-fi
            return Display(paper: Color(red: 0.05, green: 0.04, blue: 0.03), ink: amber,
                           barTop: Color(red: 0.12, green: 0.09, blue: 0.05),
                           barBottom: Color(red: 0.08, green: 0.06, blue: 0.03), barInk: amber,
                           litTop: Color(red: 1.0, green: 0.76, blue: 0.28),
                           litBottom: Color(red: 0.95, green: 0.60, blue: 0.12),
                           litInk: Color(red: 0.10, green: 0.07, blue: 0.02),
                           track: amber.opacity(0.22), glow: amber.opacity(0.55))
        }
        return Display(paper: .white, ink: Color(white: 0.1),
                       barTop: Color(white: 0.96), barBottom: Color(white: 0.80), barInk: Color(white: 0.15),
                       litTop: Color(red: 0.99, green: 0.60, blue: 0.22),
                       litBottom: Color(red: 0.88, green: 0.40, blue: 0.08), litInk: .white,
                       track: Color(white: 0.84), glow: .clear)
    }

    var body: some View {
        Group {
            if jog {
                jogPlayer
            } else {
                wheelPlayer
            }
        }
        // Keeps the system volume control in the window so the dial can set it.
        .background(
            VolumeHost(view: volume.volumeView)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
        )
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: Jog dial player

    private var jogPlayer: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let rail = max(insets.leading, insets.trailing) >= 60
            let railLeading = rail && insets.leading > insets.trailing
            let full = CGSize(width: geo.size.width + insets.leading + insets.trailing,
                              height: geo.size.height + insets.top + insets.bottom)
            let column = rail ? max(insets.leading, insets.trailing) : stripWidth + insets.trailing
            let faceWidth = full.width - column - (railLeading ? 0 : insets.leading)
            let top = insets.top + 22
            let screenWidth = max(120, faceWidth - 40)
            let screenHeight = screenWidth * 0.70
            let room = full.height - top - screenHeight - insets.bottom - 70
            let dialSize = max(110, min(faceWidth * 0.64, room))
            HStack(spacing: 0) {
                if railLeading { keyColumn(insets: insets, rail: true, leading: true, height: full.height) }
                VStack(spacing: 0) {
                    screen
                        .frame(width: screenWidth, height: screenHeight)
                        .padding(.top, top)
                    Spacer(minLength: 10)
                    dial(diameter: dialSize)
                    Text("TURN  ·  PRESS")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(1.8)
                        .foregroundColor(skin.engraving)
                        .shadow(color: skin.engravingEdge, radius: 0.3, y: skin.engravingEdgeOffset)
                        .padding(.top, 14)
                        .accessibilityHidden(true)
                    Spacer(minLength: 10)
                }
                .padding(.bottom, insets.bottom)
                .frame(maxWidth: .infinity)
                if !railLeading { keyColumn(insets: insets, rail: rail, leading: false, height: full.height) }
            }
            .frame(width: full.width, height: full.height)
            .background(
                ZStack {
                    LinearGradient(colors: skin.panel, startPoint: .top, endPoint: .bottom)
                    PlasticGrain(strength: 0.5)
                    // Light falling across the moulding from the top left
                    LinearGradient(colors: [Color.white.opacity(0.10), .clear, Color.black.opacity(0.22)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    GlassShimmer(strength: 0.5)
                    statusPlate(rail: rail, leading: railLeading)
                }
            )
            .ignoresSafeArea()
        }
    }

    /// On a pale case, a dark plate behind the Duo's clock and status icons,
    /// which the system draws in white.
    @ViewBuilder
    private func statusPlate(rail: Bool, leading: Bool) -> some View {
        if rail, skin.needsStatusPlate {
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.black.opacity(0.78))
                .frame(width: railKeyWidth, height: 140)
                .padding(leading ? .leading : .trailing, railOuterMargin)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: leading ? .topLeading : .topTrailing)
        }
    }

    /// The keys, in the same place and the same moulding as the tape
    /// player's: back, play/pause, previous, next and settings.
    private func keyColumn(insets: EdgeInsets, rail: Bool, leading: Bool, height: CGFloat) -> some View {
        let top = rail ? railStatusHeight : insets.top + 12
        let bottom = insets.bottom + 12
        let width = rail ? max(insets.leading, insets.trailing) : stripWidth + insets.trailing
        let keyHeight = min(84, max(36, (height - top - bottom - 4 * keyGap) / 5))
        let inner = max(0, width - railKeyWidth - railOuterMargin)
        return VStack(spacing: keyGap) {
            if !rail { Spacer(minLength: 0) }
            TapeKey(symbol: "arrow.uturn.backward", label: "Back",
                    height: keyHeight, showsLabel: false, corner: 17, symbolSize: 21,
                    onDown: { back() })
            TapeKey(symbol: "playpause.fill", label: model.motion == .playing ? "Pause" : "Play",
                    accent: true, latched: model.motion == .playing,
                    height: keyHeight, showsLabel: false, corner: 17, symbolSize: 23,
                    onDown: { model.playPauseKey() })
            TapeKey(symbol: "backward.fill", label: "Previous", latched: model.motion == .rewind,
                    height: keyHeight, showsLabel: false, corner: 17, symbolSize: 23,
                    onDown: { model.seekKeyDown(forward: false) },
                    onUp: { model.seekKeyUp(forward: false) })
            TapeKey(symbol: "forward.fill", label: "Next", latched: model.motion == .fastForward,
                    height: keyHeight, showsLabel: false, corner: 17, symbolSize: 23,
                    onDown: { model.seekKeyDown(forward: true) },
                    onUp: { model.seekKeyUp(forward: true) })
            TapeKey(symbol: "gearshape.fill", label: "Settings", dark: true,
                    height: keyHeight, showsLabel: false, corner: 17, symbolSize: 23,
                    onDown: {
                        Haptics.keyDown()
                        showSettings = true
                    })
            Spacer(minLength: 0)
        }
        .frame(width: rail ? railKeyWidth : stripWidth - 16)
        .padding(.top, top)
        .padding(.bottom, bottom)
        .padding(.leading, rail ? (leading ? railOuterMargin : inner) : 8)
        .padding(.trailing, rail ? (leading ? inner : railOuterMargin) : 8 + insets.trailing)
        .frame(width: width, height: height)
    }

    /// The jog dial: a metal knob with a knurled edge that turns under the
    /// thumb. Turning scrolls; a press selects.
    private func dial(diameter: CGFloat) -> some View {
        ZStack {
            // The recess the dial sits in, and the shadow it throws
            Circle()
                .fill(Color.black.opacity(0.55))
                .padding(-7)
                .overlay(
                    Circle().strokeBorder(LinearGradient(colors: [Color.black.opacity(0.9), Color.white.opacity(0.22)],
                                                         startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                        .padding(-7)
                )
            Circle()
                .fill(Color.black.opacity(0.6))
                .blur(radius: 9)
                .offset(y: 9)

            // Knurled skirt: fine ridges that turn with the dial
            Canvas { context, size in
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = size.width / 2
                let ridges = 96
                for ridge in 0..<ridges {
                    let angle = (Double(ridge) / Double(ridges)) * 2 * .pi + dialAngle * .pi / 180
                    // Lit from the top left: ridges facing the light are brighter
                    let facing = 0.5 + 0.5 * cos(angle + 2.2)
                    var line = Path()
                    line.move(to: CGPoint(x: centre.x + cos(angle) * radius * 0.86,
                                          y: centre.y + sin(angle) * radius * 0.86))
                    line.addLine(to: CGPoint(x: centre.x + cos(angle) * radius * 0.995,
                                             y: centre.y + sin(angle) * radius * 0.995))
                    context.stroke(line, with: .color(Color(white: 0.30 + 0.62 * facing)),
                                   lineWidth: radius * 0.034)
                }
            }
            .background(Circle().fill(LinearGradient(colors: [Color(white: 0.34), Color(white: 0.10)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
            .clipShape(Circle())

            // The chamfer between the skirt and the top
            Circle()
                .fill(LinearGradient(colors: [Color(white: 1.0), Color(white: 0.62), Color(white: 0.36)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(diameter * 0.066)

            // The top: spun metal, which shows as light and dark sectors
            Circle()
                .fill(AngularGradient(colors: [Color(white: 0.90), Color(white: 0.60), Color(white: 0.94),
                                               Color(white: 0.56), Color(white: 0.88), Color(white: 0.62),
                                               Color(white: 0.95), Color(white: 0.58), Color(white: 0.90)],
                                      center: .center))
                .overlay(
                    // Fine turning marks
                    ZStack {
                        ForEach(1..<7, id: \.self) { ring in
                            Circle()
                                .strokeBorder(Color.black.opacity(0.07), lineWidth: 0.6)
                                .padding(diameter * 0.055 * CGFloat(ring))
                        }
                    }
                )
                .overlay(Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 0.75))
                .padding(diameter * 0.085)
                .brightness(zone == .dial && !scrolling ? -0.05 : 0)

            // The finger dimple, which goes round as the dial is turned
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.36), Color(white: 0.66)],
                                     center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0,
                                     endRadius: diameter * 0.08))
                .overlay(Circle().strokeBorder(LinearGradient(colors: [Color.black.opacity(0.6), Color.white.opacity(0.9)],
                                                              startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .frame(width: diameter * 0.15, height: diameter * 0.15)
                .offset(y: -diameter * 0.27)
                .rotationEffect(.degrees(dialAngle))
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { touch in turnMoved(touch, diameter: diameter) }
                .onEnded { _ in turnReleased() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Jog dial")
        .accessibilityHint("Swipe up or down to scroll. Double tap to select.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: scroll(by: -1)
            case .decrement: scroll(by: 1)
            @unknown default: break
            }
        }
        .accessibilityAction { select() }
    }

    // MARK: Click wheel player (personal builds only)

    private var wheelPlayer: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let rail = max(insets.leading, insets.trailing) >= 60
            let railLeading = rail && insets.leading > insets.trailing
            let width = geo.size.width
            let screenWidth = min(width - 44, (geo.size.height - 40) * 0.62)
            let screenHeight = screenWidth * 0.74
            let wheelSize = max(120, min(width * 0.66, geo.size.height - screenHeight - 86))
            VStack(spacing: 0) {
                screen
                    .frame(width: screenWidth, height: screenHeight)
                    .padding(.top, 26)
                Spacer(minLength: 12)
                wheel(diameter: wheelSize)
                Spacer(minLength: 12)
            }
            .frame(width: width, height: geo.size.height)
            .background(
                ZStack {
                    LinearGradient(colors: skin.wheelBody, startPoint: .top, endPoint: .bottom)
                    PlasticGrain(strength: 0.3)
                    statusPlate(rail: rail, leading: railLeading)
                }
                .ignoresSafeArea()
            )
        }
    }

    private func wheel(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: skin.wheelRing, startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            Text("MENU")
                .font(.system(size: diameter * 0.062, weight: .bold))
                .tracking(1)
                .offset(y: -diameter * 0.37)
            Image(systemName: "backward.end.alt.fill")
                .font(.system(size: diameter * 0.06))
                .offset(x: -diameter * 0.37)
            Image(systemName: "forward.end.alt.fill")
                .font(.system(size: diameter * 0.06))
                .offset(x: diameter * 0.37)
            Image(systemName: "playpause.fill")
                .font(.system(size: diameter * 0.06))
                .offset(y: diameter * 0.37)
            Circle()
                .fill(LinearGradient(colors: skin.wheelCentre, startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(Color.black.opacity(0.3), lineWidth: 1))
                .frame(width: diameter * 0.36, height: diameter * 0.36)
                .brightness(zone == .centre ? -0.08 : 0)
        }
        .foregroundColor(skin.wheelLettering)
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { touch in turnMoved(touch, diameter: diameter) }
                .onEnded { _ in turnReleased() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Click wheel")
        .accessibilityHint("Swipe up or down to scroll. Double tap to select.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: scroll(by: -1)
            case .decrement: scroll(by: 1)
            @unknown default: break
            }
        }
        .accessibilityAction { select() }
        .accessibilityAction(named: "Menu") { back() }
        .accessibilityAction(named: "Play or pause") { model.playPauseKey() }
    }

    // MARK: Menus

    private var current: Screen { stack.last ?? .root }
    private var level: Int { stack.count - 1 }

    private func rows(for screen: Screen) -> [Row] {
        switch screen {
        case .root:
            var list = [Row(id: "music", title: "Music", action: .open(.music))]
            if model.hasTape {
                list.append(Row(id: "now", title: "Now Playing", action: .open(.nowPlaying)))
                list.append(Row(id: "flip", title: "Flip Tape",
                                detail: "Side \(model.sideLetter)", action: .flip))
            }
            if model.authStatus != .authorized {
                list.append(Row(id: "connect", title: "Connect Apple Music", action: .connect))
            }
            list.append(Row(id: "settings", title: "Settings", action: .settings))
            return list
        case .music:
            return [Row(id: "mixtapes", title: "Mixtapes", action: .open(.mixtapes)),
                    Row(id: "playlists", title: "Playlists", action: .open(.playlists)),
                    Row(id: "albums", title: "Albums", action: .open(.albums))]
        case .mixtapes:
            return tapeRows(model.mixtapes.map { Tape.mixtape($0) })
        case .playlists:
            return tapeRows(model.libraryPlaylists)
        case .albums:
            return tapeRows(model.libraryAlbums)
        case .nowPlaying:
            return []
        }
    }

    private func tapeRows(_ tapes: [Tape]) -> [Row] {
        if tapes.isEmpty {
            return [Row(id: "empty", title: "Nothing here yet", action: .nothing)]
        }
        return tapes.map { Row(id: $0.id, title: $0.title, detail: $0.subtitle, action: .play($0)) }
    }

    /// One step of the dial. In a menu it moves the highlight; while a song
    /// is showing it changes the volume.
    private func scroll(by amount: Int) {
        if current == .nowPlaying {
            volume.set(volume.level + Double(amount) / 20)
            Haptics.detent()
            return
        }
        let count = rows(for: current).count
        guard count > 0, level < chosen.count else { return }
        let next = min(max(chosen[level] + amount, 0), count - 1)
        guard next != chosen[level] else { return }
        chosen[level] = next
        // Keep the highlighted row on screen.
        if next < tops[level] { tops[level] = next }
        if next >= tops[level] + rowsShown { tops[level] = next - rowsShown + 1 }
        Haptics.detent()
    }

    private func open(_ screen: Screen) {
        stack.append(screen)
        chosen.append(0)
        tops.append(0)
    }

    /// A press of the dial, or of the click wheel's middle button.
    private func select() {
        Haptics.keyDown()
        if current == .nowPlaying {
            model.playPauseKey()
            return
        }
        let list = rows(for: current)
        guard level < chosen.count, list.indices.contains(chosen[level]) else { return }
        switch list[chosen[level]].action {
        case .open(let screen):
            open(screen)
        case .play(let tape):
            model.insert(tape)
            open(.nowPlaying)
        case .flip:
            model.flipTape()
        case .settings:
            showSettings = true
        case .connect:
            Task { await model.requestAccess() }
        case .nothing:
            break
        }
    }

    /// Back one level.
    private func back() {
        Haptics.keyDown()
        guard stack.count > 1 else { return }
        stack.removeLast()
        chosen.removeLast()
        tops.removeLast()
    }

    // MARK: Display

    private var screen: some View {
        let look = display
        let glass = RoundedRectangle(cornerRadius: 6)
        return VStack(spacing: 0) {
            // Title bar
            HStack(spacing: 6) {
                Text(current.title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if model.hasTape {
                    Image(systemName: model.motion == .playing ? "play.fill" : "pause.fill")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundColor(look.barInk)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(LinearGradient(colors: [look.barTop, look.barBottom], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottom) { look.ink.opacity(0.45).frame(height: 0.75) }

            if current == .nowPlaying {
                nowPlaying(look)
            } else {
                menu(look)
            }
        }
        // Lit lettering glows a little on the amber display
        .shadow(color: look.glow, radius: 2.5)
        .background(look.paper)
        .clipShape(glass)
        .overlay(
            // The display sits behind glass, below the surface of the case:
            // shadow falls in from the top edge and light slides across.
            ZStack {
                glass.strokeBorder(Color.black.opacity(0.75), lineWidth: 5).blur(radius: 4)
                LinearGradient(colors: [Color.white.opacity(jog ? 0.14 : 0.22), .clear, .clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .clipShape(glass)
            .allowsHitTesting(false)
        )
        .padding(6)
        .background(
            // The bezel: a dark frame with a lit lower lip
            RoundedRectangle(cornerRadius: 11)
                .fill(LinearGradient(colors: [Color(white: 0.02), Color(white: 0.10)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(LinearGradient(colors: [Color.black, Color.white.opacity(0.35)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                )
        )
        .shadow(color: .black.opacity(0.55), radius: 6, y: 3)
        .accessibilityElement(children: .combine)
    }

    private func menu(_ look: Display) -> some View {
        let list = rows(for: current)
        let top = level < tops.count ? tops[level] : 0
        let picked = level < chosen.count ? chosen[level] : 0
        let shown = Array(list.dropFirst(top).prefix(rowsShown))
        return GeometryReader { geo in
            let rowHeight = geo.size.height / CGFloat(rowsShown)
            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { offset, row in
                    let lit = top + offset == picked
                    HStack(spacing: 6) {
                        Text(row.title)
                            .font(.system(size: min(15, rowHeight * 0.55), weight: .bold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if !row.detail.isEmpty {
                            Text(row.detail)
                                .font(.system(size: min(11, rowHeight * 0.42)))
                                .lineLimit(1)
                                .opacity(0.75)
                                .frame(maxWidth: geo.size.width * 0.4, alignment: .trailing)
                        }
                        if row.opens {
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .heavy))
                        }
                    }
                    .foregroundColor(lit ? look.litInk : look.ink)
                    .padding(.horizontal, 9)
                    .frame(height: rowHeight)
                    .background(
                        LinearGradient(colors: [look.litTop, look.litBottom], startPoint: .top, endPoint: .bottom)
                            .opacity(lit ? 1 : 0)
                    )
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func nowPlaying(_ look: Display) -> some View {
        GeometryReader { geo in
            let art = min(geo.size.height - 44, geo.size.width * 0.42)
            VStack(spacing: 6) {
                HStack(alignment: .top, spacing: 10) {
                    Group {
                        if let artwork = model.tapeArtwork {
                            ArtworkImage(artwork, width: art, height: art)
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: art * 0.4))
                                .foregroundColor(look.ink.opacity(0.6))
                                .frame(width: art, height: art)
                                .background(look.track)
                        }
                    }
                    .frame(width: art, height: art)
                    .clipped()
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.trackTitle.isEmpty ? model.tapeTitle : model.trackTitle)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(2)
                        Text(model.trackArtist)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(model.tapeTitle)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .opacity(0.7)
                        Text(model.sideEnded ? "End of side \(model.sideLetter)" : "Side \(model.sideLetter)")
                            .font(.system(size: 11, weight: .semibold))
                            .opacity(0.7)
                    }
                    .foregroundColor(look.ink)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                // Where the current song has got to
                GeometryReader { bar in
                    let done = model.duration > 0 ? min(1, model.elapsed / model.duration) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(look.track)
                        Capsule()
                            .fill(look.litBottom)
                            .frame(width: bar.size.width * CGFloat(done))
                    }
                }
                .frame(height: 8)
                HStack {
                    Text(TransportKeys.clock(model.elapsed))
                    Spacer()
                    Text("-" + TransportKeys.clock(max(0, model.duration - model.elapsed)))
                }
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundColor(look.ink.opacity(0.85))
            }
            .padding(9)
        }
    }

    // MARK: Turning

    private func angle(of point: CGPoint, diameter: CGFloat) -> Double {
        Double(atan2(point.y - diameter / 2, point.x - diameter / 2)) * 180 / .pi
    }

    private func turnMoved(_ touch: DragGesture.Value, diameter: CGFloat) {
        let here = angle(of: touch.location, diameter: diameter)
        guard let zone else {
            // The touch has just landed: work out where.
            let start = touch.startLocation
            let dx = start.x - diameter / 2
            let dy = start.y - diameter / 2
            let landed: Zone
            if jog {
                landed = .dial
            } else if (dx * dx + dy * dy).squareRoot() < diameter * 0.19 {
                landed = .centre
            } else if abs(dx) > abs(dy) {
                landed = dx < 0 ? .left : .right
            } else {
                landed = dy < 0 ? .top : .bottom
            }
            self.zone = landed
            lastAngle = here
            turned = 0
            pending = 0
            scrolling = false
            // On the click wheel, previous and next act like the deck's
            // keys: a hold winds the tape.
            if landed == .left { model.seekKeyDown(forward: false) }
            if landed == .right { model.seekKeyDown(forward: true) }
            return
        }
        guard zone != .centre else { return }

        // How far round the thumb has gone since the last report, the short way.
        var delta = here - lastAngle
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        lastAngle = here
        turned += delta
        pending += delta
        if zone == .dial { dialAngle += delta }

        if !scrolling, abs(turned) > 14 {
            scrolling = true
            // It is a turn, not a press of a button.
            if zone == .left || zone == .right { model.seekKeyCancel() }
        }
        guard scrolling else { return }
        while pending >= step {
            scroll(by: 1)
            pending -= step
        }
        while pending <= -step {
            scroll(by: -1)
            pending += step
        }
    }

    private func turnReleased() {
        defer { zone = nil }
        guard let zone else { return }
        if zone == .centre {
            select()
            return
        }
        guard !scrolling else { return }
        switch zone {
        case .dial: select()
        case .top: back()
        case .bottom: model.playPauseKey()
        case .left: model.seekKeyUp(forward: false)
        case .right: model.seekKeyUp(forward: true)
        case .centre: break
        }
    }
}
