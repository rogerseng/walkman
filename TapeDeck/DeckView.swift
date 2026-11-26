import SwiftUI

/// The closed phone: the outside of a tape player. A glass door on the face
/// shows the cassette standing on end, and a metal strip down the right edge
/// carries the keys.
struct DeckView: View {
    @EnvironmentObject private var model: PlayerModel
    var openShelf: () -> Void

    private let silver = Color(red: 0.80, green: 0.82, blue: 0.85)
    private let stripWidth: CGFloat = 78

    var body: some View {
        GeometryReader { geo in
            let keyHeight = min(64, max(34, (geo.size.height - 130) / 5))
            HStack(spacing: 0) {
                face.padding(16)
                strip(keyHeight: keyHeight).frame(width: stripWidth)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(
                HStack(spacing: 0) {
                    bodyFinish
                    BrushedSilver()
                        .frame(width: stripWidth + geo.safeAreaInsets.trailing)
                        .overlay(alignment: .leading) {
                            // Seam where the strip meets the body
                            LinearGradient(colors: [Color.black.opacity(0.45), .clear],
                                           startPoint: .leading, endPoint: .trailing)
                                .frame(width: 5)
                        }
                }
                .ignoresSafeArea()
            )
        }
    }

    // MARK: Face

    private var bodyFinish: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.27, green: 0.43, blue: 0.70),
                                    Color(red: 0.15, green: 0.27, blue: 0.52)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(colors: [Color.white.opacity(0.12), .clear, Color.black.opacity(0.18)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    private var face: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("TAPEDECK")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .italic()
                        .foregroundColor(silver)
                    Text("CASSETTE PLAYER")
                        .font(.system(size: 7, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(silver.opacity(0.8))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                Button {
                    model.soundEffectsOn.toggle()
                } label: {
                    Image(systemName: model.soundEffectsOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .frame(width: 34, height: 28)
                }
                .accessibilityLabel(model.soundEffectsOn ? "Tape sound effects on" : "Tape sound effects off")
                Button(action: openShelf) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .frame(width: 34, height: 28)
                }
                .accessibilityLabel("Tape shelf")
            }
            .buttonStyle(OrangeButtonStyle())

            Text("STEREO")
                .font(.system(size: 17, weight: .black))
                .tracking(3)
                .foregroundColor(silver)

            door

            HStack(spacing: 8) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .accessibilityHidden(true)
                Text(model.hasTape ? nowPlaying : "NO TAPE")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(silver)
        }
    }

    private var nowPlaying: String {
        let line = model.trackLine
        return line.isEmpty ? model.tapeTitle : line
    }

    /// The cassette door. It takes whatever room is left and stands the
    /// cassette on end when that room is taller than it is wide.
    private var door: some View {
        GeometryReader { geo in
            let upright = geo.size.height > geo.size.width
            let aspect: CGFloat = upright ? 0.66 : 1 / 0.66
            let width = min(geo.size.width, geo.size.height * aspect)
            let height = width / aspect
            ZStack {
                Color(white: 0.05)
                if model.hasTape {
                    CassetteView(title: model.tapeTitle,
                                 subtitle: model.trackLine,
                                 progress: model.progress,
                                 motion: model.motion)
                        .frame(width: (upright ? height : width) - 22,
                               height: (upright ? width : height) - 22)
                        .rotationEffect(.degrees(upright ? -90 : 0))
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "eject.fill").font(.system(size: 26))
                        Text("NO TAPE").font(.system(size: 14, weight: .bold)).tracking(3)
                        Text("Tap to choose one").font(.system(size: 11))
                    }
                    .foregroundColor(silver.opacity(0.55))
                }
                glass
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            // Chrome bezel
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(LinearGradient(colors: [Color.white, Color(white: 0.55),
                                                          Color(white: 0.9), Color(white: 0.45)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                                  lineWidth: 4)
            )
            .shadow(color: .black.opacity(0.45), radius: 7, y: 4)
            .contentShape(Rectangle())
            .onTapGesture {
                if !model.hasTape { openShelf() }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// The door window: smoked glass, a fixed reflection in one corner, a dark
    /// edge where the glass meets the frame, and the moving shimmer.
    private var glass: some View {
        ZStack {
            Color(red: 0.35, green: 0.45, blue: 0.50).opacity(0.10)
            LinearGradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.04), .clear],
                           startPoint: .topLeading, endPoint: .center)
            Rectangle()
                .strokeBorder(Color.black.opacity(0.55), lineWidth: 8)
                .blur(radius: 6)
            GlassShimmer()
        }
        .clipped()
        .allowsHitTesting(false)
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
                Text("BATT").font(.system(size: 6, weight: .bold)).foregroundColor(Color(white: 0.2))
            }
            .accessibilityHidden(true)

            Text(TransportKeys.clock(model.elapsed))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.black))
                .accessibilityLabel("Elapsed \(TransportKeys.clock(model.elapsed))")

            Spacer(minLength: 0)
            TransportKeys(vertical: true, keyHeight: keyHeight, onEject: openShelf)
            Spacer(minLength: 0)
            Screw()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
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
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.07)))
    }

    static func clock(_ time: TimeInterval) -> String {
        let total = Int(max(time, 0))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// One mechanical key. It reports press and release separately so rewind and
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
        .foregroundColor(accent ? .white : Color(white: 0.15))
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(LinearGradient(colors: keyColors(down: down), startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.black.opacity(0.5), lineWidth: 1))
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
                ? [Color(red: 0.75, green: 0.33, blue: 0.06), Color(red: 0.85, green: 0.40, blue: 0.10)]
                : [Color(red: 0.98, green: 0.55, blue: 0.18), Color(red: 0.88, green: 0.40, blue: 0.08)]
        }
        return down
            ? [Color(white: 0.62), Color(white: 0.72)]
            : [Color(white: 0.92), Color(white: 0.70)]
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
