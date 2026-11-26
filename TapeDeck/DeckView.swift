import SwiftUI

/// The closed phone: a tape player with a clear case. The cassette fills the
/// whole screen, and the brand plate, buttons and key strip are clear plastic
/// floating over it.
struct DeckView: View {
    @EnvironmentObject private var model: PlayerModel
    var openShelf: () -> Void

    private let stripWidth: CGFloat = 78

    var body: some View {
        GeometryReader { geo in
            let keyHeight = min(64, max(34, (geo.size.height - 130) / 5))
            HStack(spacing: 0) {
                face.padding(14)
                strip(keyHeight: keyHeight).frame(width: stripWidth)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(
                ZStack {
                    // Inside of the player, seen through the case
                    RadialGradient(colors: [Color(white: 0.16), Color(white: 0.04)],
                                   center: .center, startRadius: 20, endRadius: 520)
                    tape
                    clearCase
                }
                .ignoresSafeArea()
            )
        }
    }

    // MARK: Tape

    /// The cassette, scaled to fill the screen. It stands on end when the
    /// screen is taller than wide. It may overflow the edges a little, but
    /// never so far that the label is lost.
    private var tape: some View {
        GeometryReader { geo in
            let upright = geo.size.height > geo.size.width
            let long = upright ? geo.size.height : geo.size.width
            let short = upright ? geo.size.width : geo.size.height
            let fit = min(long / 100, short / 63)
            let fill = max(long / 100, short / 63)
            let scale = min(fill, fit * 1.18)
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
                    VStack(spacing: 8) {
                        Image(systemName: "eject.fill").font(.system(size: 30))
                        Text("NO TAPE").font(.system(size: 16, weight: .bold)).tracking(3)
                        Text("Tap to choose one").font(.system(size: 12))
                    }
                    .foregroundColor(Color.white.opacity(0.5))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    /// The clear shell over everything: a faint tint, a fixed reflection, the
    /// moving shimmer, and bright edges where the plastic curves.
    private var clearCase: some View {
        ZStack {
            Color.white.opacity(0.04)
            LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.03), .clear],
                           startPoint: .topLeading, endPoint: .center)
            GlassShimmer()
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1.5)
                .padding(9)
            RoundedRectangle(cornerRadius: 34)
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.10),
                                                      Color.white.opacity(0.30)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing),
                              lineWidth: 3)
        }
        .allowsHitTesting(false)
    }

    // MARK: Face

    private var face: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("TAPEDECK")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .italic()
                    Text("STEREO CASSETTE PLAYER")
                        .font(.system(size: 6.5, weight: .semibold))
                        .tracking(1.2)
                        .opacity(0.8)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))

                Spacer(minLength: 4)
                Button {
                    model.soundEffectsOn.toggle()
                } label: {
                    Image(systemName: model.soundEffectsOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .accessibilityLabel(model.soundEffectsOn ? "Tape sound effects on" : "Tape sound effects off")
                Button(action: openShelf) {
                    Image(systemName: "square.stack.3d.up.fill")
                }
                .accessibilityLabel("Tape shelf")
            }
            .buttonStyle(ClearButtonStyle())

            Spacer(minLength: 0)

            if model.hasTape {
                Text(nowPlaying)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture {
            if !model.hasTape { openShelf() }
        }
    }

    private var nowPlaying: String {
        let line = model.trackLine
        return line.isEmpty ? model.tapeTitle : line
    }

    // MARK: Key strip

    private func strip(keyHeight: CGFloat) -> some View {
        VStack(spacing: 8) {
            // Battery lamp: lit while the tape is moving
            VStack(spacing: 2) {
                Circle()
                    .fill(lampOn ? Color.red : Color(red: 0.3, green: 0.05, blue: 0.05))
                    .frame(width: 9, height: 9)
                    .shadow(color: lampOn ? .red : .clear, radius: 5)
                Text("BATT").font(.system(size: 6, weight: .bold)).foregroundColor(.white.opacity(0.8))
            }
            .accessibilityHidden(true)

            Text(TransportKeys.clock(model.elapsed))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.7)))
                .accessibilityLabel("Elapsed \(TransportKeys.clock(model.elapsed))")

            Spacer(minLength: 0)
            TransportKeys(vertical: true, keyHeight: keyHeight, onEject: openShelf)
            Spacer(minLength: 0)
            Screw()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
        // A frosted clear panel: the tape shows through underneath the keys.
        .background(
            ZStack(alignment: .leading) {
                Rectangle().fill(.ultraThinMaterial)
                Color.white.opacity(0.05)
                Color.white.opacity(0.35).frame(width: 1)
            }
            .ignoresSafeArea()
        )
    }

    private var lampOn: Bool {
        model.motion != .stopped && model.motion != .paused
    }
}

/// The five keys, in a column for the closed phone or a row for the open one.
struct TransportKeys: View {
    @EnvironmentObject private var model: PlayerModel
    var vertical: Bool
    var keyHeight: CGFloat = 62
    var onEject: () -> Void = {}

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        layout {
            TapeKey(symbol: "play.fill", label: "PLAY", accent: true, latched: model.motion == .playing,
                    height: keyHeight, onDown: { model.playKey() })
            TapeKey(symbol: "pause.fill", label: "PAUSE", latched: model.motion == .paused,
                    height: keyHeight, onDown: { model.pauseKey() })
            TapeKey(symbol: "forward.fill", label: "FF", latched: model.motion == .fastForward,
                    height: keyHeight,
                    onDown: { model.seekKeyDown(forward: true) },
                    onUp: { model.seekKeyUp(forward: true) })
            TapeKey(symbol: "backward.fill", label: "REW", latched: model.motion == .rewind,
                    height: keyHeight,
                    onDown: { model.seekKeyDown(forward: false) },
                    onUp: { model.seekKeyUp(forward: false) })
            TapeKey(symbol: "eject.fill", label: "STOP/EJECT",
                    height: keyHeight, onDown: { if model.stopKey() { onEject() } })
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.28)))
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
    var onDown: () -> Void = {}
    var onUp: () -> Void = {}

    @State private var pressed = false

    var body: some View {
        let down = pressed || latched
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 17, weight: .bold))
            if height >= 50 {
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
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
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
