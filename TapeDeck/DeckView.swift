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
    var openShelf: () -> Void

    /// Width of the key column on phones that have no side rail.
    private let stripWidth: CGFloat = 78
    /// Keys in the Duo's rail are 66 points wide, centred 48 points in from
    /// the screen edge like the system's own status pill, and up to 84 tall.
    private let railKeyWidth: CGFloat = 66
    private let railOuterMargin: CGFloat = 15
    private let bigKeyHeight: CGFloat = 84
    private let keyGap: CGFloat = 16
    /// Height kept clear at the top of the rail for the camera, clock and
    /// status icons. Measured from a Duo screenshot, where the status pill
    /// ends about 154 points down; not a published figure.
    private let railStatusHeight: CGFloat = 180

    var body: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let rail = max(insets.leading, insets.trailing) >= 60
            let railLeading = rail && insets.leading > insets.trailing
            HStack(spacing: 0) {
                if railLeading { keyColumn(insets: insets, rail: true, leading: true) }
                // The face itself is drawn in the background, full screen.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !model.hasTape { openShelf() }
                    }
                if !railLeading { keyColumn(insets: insets, rail: rail, leading: false) }
            }
            .frame(width: geo.size.width + insets.leading + insets.trailing,
                   height: geo.size.height + insets.top + insets.bottom)
            .background(
                ZStack {
                    Color(white: 0.03)
                    tapeUnderCasing
                    clearCase
                }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Tape and casing

    /// The part of the cassette the window shows, in millimetres of its
    /// 100 x 63 shell: the label strip and both reels. Everything else, the
    /// ends, the guide rollers and the head opening, is under the casing.
    private let windowOnCassette = CGRect(x: 19, y: 2.5, width: 62, height: 40)

    /// The cassette filling the whole screen (on end when the screen is
    /// taller than wide, head opening toward the keys), with the player's
    /// smoked casing over it and a window cut through the casing.
    private var tapeUnderCasing: some View {
        GeometryReader { geo in
            let size = geo.size
            let upright = size.height > size.width
            let long = upright ? size.height : size.width
            let short = upright ? size.width : size.height
            // As big as the screen allows. It may run a little past the
            // edges, but never far enough to lose the label.
            let fit = min(long / 100, short / 63)
            let fill = max(long / 100, short / 63)
            let scale = min(fill, fit * 1.04)
            let window = windowRect(in: size, upright: upright, scale: scale)
            let opening = RoundedRectangle(cornerRadius: 20)
            ZStack {
                if model.hasTape {
                    CassetteView(title: model.tapeTitle,
                                 subtitle: model.trackLine,
                                 progress: model.progress,
                                 motion: model.motion)
                        .frame(width: 100 * scale, height: 63 * scale)
                        .rotationEffect(.degrees(upright ? -90 : 0))
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
                    opening.strokeBorder(Color.white.opacity(0.10), lineWidth: 1).padding(-6)
                }
                .frame(width: window.width, height: window.height)
                .position(x: window.midX, y: window.midY)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    /// Where `windowOnCassette` lands on screen.
    private func windowRect(in size: CGSize, upright: Bool, scale: CGFloat) -> CGRect {
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

    /// The surface of the body: a fixed reflection, the glare that follows the
    /// phone as it moves, and bright edges where the plastic curves.
    private var clearCase: some View {
        ZStack {
            LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.02), .clear],
                           startPoint: .topLeading, endPoint: .center)
            GlassShimmer()
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1.5)
                .padding(9)
            RoundedRectangle(cornerRadius: 34)
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.10),
                                                      Color.white.opacity(0.28)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing),
                              lineWidth: 3)
        }
        .allowsHitTesting(false)
    }

    // MARK: Keys

    /// Four big transport keys (play and pause share one), then two small
    /// ones side by side: sound effects and the tape shelf.
    private func keys(height: CGFloat) -> some View {
        VStack(spacing: 14) {
            TransportKeys(vertical: true, keyHeight: height, bare: true, big: true,
                          spacing: keyGap, onEject: openShelf)
            HStack(spacing: 6) {
                TapeKey(symbol: model.soundEffectsOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                        label: model.soundEffectsOn ? "Tape sound effects on" : "Tape sound effects off",
                        height: smallKeyHeight, showsLabel: false, corner: 10, symbolSize: 13,
                        onDown: {
                            Haptics.keyDown()
                            model.soundEffectsOn.toggle()
                        })
                TapeKey(symbol: "square.stack.3d.up.fill", label: "Tape shelf",
                        height: smallKeyHeight, showsLabel: false, corner: 10, symbolSize: 13,
                        onDown: {
                            Haptics.keyDown()
                            openShelf()
                        })
            }
        }
    }

    private let smallKeyHeight: CGFloat = 34
    /// Room the small keys and the gap above them take in the column.
    private var smallKeysRoom: CGFloat { 14 + smallKeyHeight }

    private func keyHeight(room: CGFloat) -> CGFloat {
        min(bigKeyHeight, max(40, (room - smallKeysRoom - 3 * keyGap) / 4))
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

/// The five keys, in a column for the closed phone or a row for the open one.
struct TransportKeys: View {
    @EnvironmentObject private var model: PlayerModel
    var vertical: Bool
    var keyHeight: CGFloat = 62
    /// Without the tray behind the keys, for places that supply their own.
    var bare = false
    /// Four large rounded keys, with play and pause sharing one.
    var big = false
    var spacing: CGFloat = 6
    var onEject: () -> Void = {}

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: spacing)) : AnyLayout(HStackLayout(spacing: spacing))
        let corner: CGFloat = big ? 17 : 7
        let symbol: CGFloat = big ? 23 : 17
        let labels = !vertical && !big
        layout {
            if big {
                // Down and lit while the tape plays; press again to pause.
                TapeKey(symbol: model.motion == .playing ? "pause.fill" : "play.fill",
                        label: model.motion == .playing ? "Pause" : "Play",
                        accent: true, latched: model.motion == .playing,
                        height: keyHeight, showsLabel: false, corner: corner, symbolSize: symbol,
                        onDown: { model.playPauseKey() })
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
            TapeKey(symbol: "eject.fill", label: "STOP/EJECT",
                    height: keyHeight, showsLabel: labels, corner: corner, symbolSize: symbol,
                    onDown: { if model.stopKey() { onEject() } })
        }
        .padding(bare ? 0 : 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(bare ? 0 : 0.28)))
    }

    static func clock(_ time: TimeInterval) -> String {
        let total = Int(max(time, 0))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// One mechanical key, moulded in clear plastic. It reports press and release separately so rewind and
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

    var body: some View {
        let down = pressed || latched
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: symbolSize, weight: .bold))
            if showsLabel, height >= 50 {
                Text(label).font(.system(size: 7, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        .foregroundColor(accent ? Color(white: 0.10) : .white)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: corner)
                .fill(LinearGradient(colors: keyColors(down: down), startPoint: .top, endPoint: .bottom))
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner))
        .overlay(RoundedRectangle(cornerRadius: corner).strokeBorder(Color.white.opacity(0.30), lineWidth: 0.75))
        // Light catching the moulded top edge
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.55))
                .frame(height: 1)
                .padding(.horizontal, corner)
                .padding(.top, 2)
        }
        .offset(y: down ? 3 : 0)
        .shadow(color: .black.opacity(down ? 0.1 : 0.5), radius: down ? 1 : 3, y: down ? 1 : 3)
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
            // The play key: plain bright plastic, so it stands out without colour
            return down
                ? [Color(white: 0.62).opacity(0.95), Color(white: 0.74).opacity(0.95)]
                : [Color(white: 0.96).opacity(0.95), Color(white: 0.74).opacity(0.95)]
        }
        return down
            ? [Color.white.opacity(0.10), Color.white.opacity(0.18)]
            : [Color.white.opacity(0.36), Color.white.opacity(0.14)]
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

struct OrangeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(red: 0.96, green: 0.48, blue: 0.13))
                    .brightness(configuration.isPressed ? -0.15 : 0)
            )
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.black.opacity(0.35), lineWidth: 1))
            .offset(y: configuration.isPressed ? 2 : 0)
    }
}
