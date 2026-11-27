import MusicKit
import SwiftUI

/// The closed phone as a click-wheel player. A small screen shows menus or
/// what is playing; below it is a wheel. Run a thumb round the wheel to
/// scroll (or, while a song shows, to change the volume). Press the middle to
/// choose. The wheel's four edges are MENU (back), previous, next and
/// play/pause; hold previous or next to wind the tape.
///
/// Underneath it is the same tape deck: the same sides, flipping and mixtapes.
struct WheelPlayerView: View {
    @EnvironmentObject private var model: PlayerModel
    @StateObject private var volume = SystemVolume()
    @AppStorage(Prefs.skin) private var skinName = Skin.wheelBlack.rawValue
    @State private var showSettings = false

    // Where you are in the menus: each level and the row chosen on it.
    @State private var stack: [Screen] = [.root]
    @State private var chosen: [Int] = [0]
    @State private var tops: [Int] = [0]

    // The wheel gesture in progress
    @State private var zone: Zone?
    @State private var lastAngle = 0.0
    @State private var turned = 0.0
    @State private var pending = 0.0
    @State private var scrolling = false

    private var skin: Skin { Skin(rawValue: skinName) ?? .wheelBlack }
    private let rowsShown = 7
    /// Degrees of turn for one step down a list.
    private let step = 24.0

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

    private enum Zone { case centre, top, bottom, left, right }

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

    var body: some View {
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
                    // On a pale body, a dark plate behind the Duo's clock and
                    // status icons, which the system draws in white.
                    if rail, skin.needsStatusPlate {
                        RoundedRectangle(cornerRadius: 26)
                            .fill(Color.black.opacity(0.78))
                            .frame(width: 66, height: 140)
                            .padding(railLeading ? .leading : .trailing, 15)
                            .padding(.top, 16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                   alignment: railLeading ? .topLeading : .topTrailing)
                    }
                }
                .ignoresSafeArea()
            )
            // Keeps the system volume control in the window so the wheel can set it.
            .background(
                VolumeHost(view: volume.volumeView)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .allowsHitTesting(false)
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
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

    /// One step round the wheel. In a menu it moves the highlight; while a
    /// song is showing it changes the volume.
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

    /// The middle button.
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

    /// MENU: back one level.
    private func back() {
        Haptics.keyDown()
        guard stack.count > 1 else { return }
        stack.removeLast()
        chosen.removeLast()
        tops.removeLast()
    }

    // MARK: Screen

    private var screen: some View {
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
            .foregroundColor(Color(white: 0.15))
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(LinearGradient(colors: [Color(white: 0.96), Color(white: 0.80)],
                                       startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottom) { Color(white: 0.55).frame(height: 0.5) }

            if current == .nowPlaying {
                nowPlaying
            } else {
                menu
            }
        }
        .background(Color.white)
        .clipShape(glass)
        .overlay(glass.strokeBorder(Color.black, lineWidth: 3))
        .overlay(
            // A little light on the glass
            LinearGradient(colors: [Color.white.opacity(0.22), .clear, .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(glass)
                .allowsHitTesting(false)
        )
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black))
        .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
        .accessibilityElement(children: .combine)
    }

    private var menu: some View {
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
                    .foregroundColor(lit ? .white : Color(white: 0.1))
                    .padding(.horizontal, 9)
                    .frame(height: rowHeight)
                    .background(
                        // Cassety's orange for the highlight
                        LinearGradient(colors: [Color(red: 0.99, green: 0.60, blue: 0.22),
                                                Color(red: 0.88, green: 0.40, blue: 0.08)],
                                       startPoint: .top, endPoint: .bottom)
                            .opacity(lit ? 1 : 0)
                    )
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var nowPlaying: some View {
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
                                .foregroundColor(Color(white: 0.5))
                                .frame(width: art, height: art)
                                .background(Color(white: 0.88))
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
                    .foregroundColor(Color(white: 0.1))
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                // Where the current song has got to
                GeometryReader { bar in
                    let done = model.duration > 0 ? min(1, model.elapsed / model.duration) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(white: 0.84))
                        Capsule()
                            .fill(Color(red: 0.93, green: 0.48, blue: 0.13))
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
                .foregroundColor(Color(white: 0.2))
            }
            .padding(9)
        }
    }

    // MARK: Wheel

    private func wheel(diameter: CGFloat) -> some View {
        let lettering = skin.wheelLettering
        return ZStack {
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
            // The middle button
            Circle()
                .fill(LinearGradient(colors: skin.wheelCentre, startPoint: .top, endPoint: .bottom))
                .overlay(Circle().strokeBorder(Color.black.opacity(0.3), lineWidth: 1))
                .frame(width: diameter * 0.36, height: diameter * 0.36)
                .brightness(zone == .centre ? -0.08 : 0)
        }
        .foregroundColor(lettering)
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { touch in wheelMoved(touch, diameter: diameter) }
                .onEnded { _ in wheelReleased() }
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

    private func angle(of point: CGPoint, diameter: CGFloat) -> Double {
        Double(atan2(point.y - diameter / 2, point.x - diameter / 2)) * 180 / .pi
    }

    private func wheelMoved(_ touch: DragGesture.Value, diameter: CGFloat) {
        let here = angle(of: touch.location, diameter: diameter)
        guard let zone else {
            // The touch has just landed: work out where.
            let start = touch.startLocation
            let dx = start.x - diameter / 2
            let dy = start.y - diameter / 2
            let landed: Zone
            if (dx * dx + dy * dy).squareRoot() < diameter * 0.19 {
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
            // Previous and next act like the deck's keys: a hold winds the tape.
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

        if !scrolling, abs(turned) > 14 {
            scrolling = true
            // It is a turn of the wheel, not a press of a button.
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

    private func wheelReleased() {
        defer { zone = nil }
        guard let zone else { return }
        if zone == .centre {
            select()
            return
        }
        guard !scrolling else { return }
        switch zone {
        case .top: back()
        case .bottom: model.playPauseKey()
        case .left: model.seekKeyUp(forward: false)
        case .right: model.seekKeyUp(forward: true)
        case .centre: break
        }
    }
}
