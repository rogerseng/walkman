import SwiftUI

/// The closed phone: the whole screen is the body of a tape player in dark
/// clear plastic. The cassette sits inside it, seated in a recessed
/// compartment behind a clear door, with the body wrapping around it.
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
    /// The key column on the Duo is 48 points wide inside the 84 point rail:
    /// 24 points from the screen edge and 12 from the content.
    private let railKeyWidth: CGFloat = 48
    private let railOuterMargin: CGFloat = 24
    /// Height kept clear at the top of the rail for the camera, clock and
    /// status icons. Not a published figure: tune it on a real Duo.
    private let railStatusHeight: CGFloat = 176

    var body: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let rail = max(insets.leading, insets.trailing) >= 60
            let railLeading = rail && insets.leading > insets.trailing
            HStack(spacing: 0) {
                if railLeading { keyColumn(insets: insets, rail: true, leading: true) }
                face
                    .padding(.top, insets.top + 14)
                    .padding(.bottom, insets.bottom + 14)
                    .padding(.leading, (railLeading ? 0 : insets.leading) + 14)
                    .padding(.trailing, 14)
                if !railLeading { keyColumn(insets: insets, rail: rail, leading: false) }
            }
            .frame(width: geo.size.width + insets.leading + insets.trailing,
                   height: geo.size.height + insets.top + insets.bottom)
            .background(
                ZStack {
                    // The body of the player: dark smoked plastic
                    LinearGradient(colors: [Color(white: 0.20), Color(white: 0.11), Color(white: 0.07)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    clearCase
                }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Cassette compartment

    /// The compartment the cassette sits in: a recessed well, the cassette
    /// seated in it (on end when the space is taller than wide, head opening
    /// toward the keys), and the clear door over the top with its hinges.
    private var compartment: some View {
        GeometryReader { geo in
            let upright = geo.size.height > geo.size.width
            let aspect: CGFloat = upright ? 0.63 : 1 / 0.63
            let rim: CGFloat = 9
            let width = max(10, min(geo.size.width - 2 * rim, (geo.size.height - 2 * rim - 8) * aspect))
            let height = width / aspect
            let shape = RoundedRectangle(cornerRadius: 16)
            ZStack {
                // The well, with shadow falling in from its edges
                shape.fill(LinearGradient(colors: [Color.black, Color(white: 0.06)],
                                          startPoint: .top, endPoint: .bottom))
                if model.hasTape {
                    CassetteView(title: model.tapeTitle,
                                 subtitle: model.trackLine,
                                 progress: model.progress,
                                 motion: model.motion)
                        .frame(width: upright ? height : width, height: upright ? width : height)
                        .rotationEffect(.degrees(upright ? -90 : 0))
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    emptyWell(upright: upright, length: upright ? height : width)
                }
                shape.strokeBorder(Color.black.opacity(0.85), lineWidth: 9).blur(radius: 6)

                // The clear door
                shape.fill(Color.white.opacity(0.035))
                shape.fill(LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.02), .clear],
                                          startPoint: .topLeading, endPoint: .center))
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    .padding(5)
            }
            .frame(width: width + 2 * rim, height: height + 2 * rim)
            .clipShape(shape)
            // Bright moulded edge of the door
            .overlay(
                shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0.18),
                                                           Color.white.opacity(0.45)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing),
                                   lineWidth: 2.5)
            )
            // Hinges along the bottom edge
            .overlay(alignment: .bottom) {
                HStack(spacing: (width + 2 * rim) * 0.42) {
                    hinge
                    hinge
                }
                .offset(y: 5)
            }
            .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .onTapGesture {
                if !model.hasTape { openShelf() }
            }
        }
    }

    private var hinge: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(LinearGradient(colors: [Color(white: 0.75), Color(white: 0.35)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.black.opacity(0.6), lineWidth: 0.75))
            .frame(width: 36, height: 10)
            .accessibilityHidden(true)
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

    // MARK: Face

    private var face: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Screw()
                Spacer(minLength: 4)
                Button {
                    Haptics.keyDown()
                    model.soundEffectsOn.toggle()
                } label: {
                    Image(systemName: model.soundEffectsOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .accessibilityLabel(model.soundEffectsOn ? "Tape sound effects on" : "Tape sound effects off")
                Button {
                    Haptics.keyDown()
                    openShelf()
                } label: {
                    Image(systemName: "square.stack.3d.up.fill")
                }
                .accessibilityLabel("Tape shelf")
            }
            .buttonStyle(ClearButtonStyle())

            compartment

            HStack {
                Screw()
                Spacer()
                Screw()
            }
        }
    }

    // MARK: Keys

    /// The column of keys. In the Duo's rail it is a slim smoked bar that
    /// starts below the camera and clock; elsewhere it is a frosted strip.
    @ViewBuilder
    private func keyColumn(insets: EdgeInsets, rail: Bool, leading: Bool) -> some View {
        if rail {
            let width = max(insets.leading, insets.trailing)
            let inner = max(0, width - railKeyWidth - railOuterMargin)
            GeometryReader { geo in
                let room = geo.size.height - railStatusHeight - insets.bottom - 12
                let keyHeight = min(76, max(34, (room - 4 * 6) / 5))
                VStack(spacing: 0) {
                    Color.clear.frame(height: railStatusHeight)
                    TransportKeys(vertical: true, keyHeight: keyHeight, bare: true, onEject: openShelf)
                    Spacer(minLength: 0)
                }
                .frame(width: railKeyWidth)
                // Smoked bar behind the camera, the clock and the keys
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.black.opacity(0.55))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                        .padding(.horizontal, -6)
                        .padding(.top, 8)
                        .padding(.bottom, insets.bottom + 4)
                )
                .padding(.leading, leading ? railOuterMargin : inner)
                .padding(.trailing, leading ? inner : railOuterMargin)
            }
            .frame(width: width)
        } else {
            GeometryReader { geo in
                let room = geo.size.height - insets.top - insets.bottom - 24 - 12
                let keyHeight = min(64, max(34, (room - 4 * 6) / 5))
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    TransportKeys(vertical: true, keyHeight: keyHeight, onEject: openShelf)
                    Spacer(minLength: 0)
                }
                .padding(.top, insets.top + 12)
                .padding(.bottom, insets.bottom + 12)
                .padding(.leading, 8)
                .padding(.trailing, 8 + insets.trailing)
                .frame(width: stripWidth + insets.trailing, height: geo.size.height)
                .background(
                    ZStack(alignment: .leading) {
                        Rectangle().fill(.ultraThinMaterial)
                        Color.black.opacity(0.35)
                        Color.white.opacity(0.25).frame(width: 1)
                    }
                )
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
    var onEject: () -> Void = {}

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        layout {
            TapeKey(symbol: "play.fill", label: "PLAY", accent: true, latched: model.motion == .playing,
                    height: keyHeight, showsLabel: !vertical, onDown: { model.playKey() })
            TapeKey(symbol: "pause.fill", label: "PAUSE", latched: model.motion == .paused,
                    height: keyHeight, showsLabel: !vertical, onDown: { model.pauseKey() })
            TapeKey(symbol: "forward.fill", label: "FF", latched: model.motion == .fastForward,
                    height: keyHeight, showsLabel: !vertical,
                    onDown: { model.seekKeyDown(forward: true) },
                    onUp: { model.seekKeyUp(forward: true) })
            TapeKey(symbol: "backward.fill", label: "REW", latched: model.motion == .rewind,
                    height: keyHeight, showsLabel: !vertical,
                    onDown: { model.seekKeyDown(forward: false) },
                    onUp: { model.seekKeyUp(forward: false) })
            TapeKey(symbol: "eject.fill", label: "STOP/EJECT",
                    height: keyHeight, showsLabel: !vertical, onDown: { if model.stopKey() { onEject() } })
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
    var onDown: () -> Void = {}
    var onUp: () -> Void = {}

    @State private var pressed = false

    var body: some View {
        let down = pressed || latched
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 17, weight: .bold))
            if showsLabel, height >= 50 {
                Text(label).font(.system(size: 7, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(LinearGradient(colors: keyColors(down: down), startPoint: .top, endPoint: .bottom))
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.white.opacity(0.30), lineWidth: 0.75))
        // Light catching the moulded top edge
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.55))
                .frame(height: 1)
                .padding(.horizontal, 7)
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
            return down
                ? [Color(red: 0.80, green: 0.36, blue: 0.08).opacity(0.90), Color(red: 0.90, green: 0.44, blue: 0.12).opacity(0.90)]
                : [Color(red: 0.99, green: 0.58, blue: 0.20).opacity(0.85), Color(red: 0.92, green: 0.42, blue: 0.08).opacity(0.85)]
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
