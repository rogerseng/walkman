import SwiftUI
import MediaPlayer

/// The player body: cassette door, counter, volume and the row of piano keys.
struct DeckView: View {
    @EnvironmentObject private var model: PlayerModel
    var showShelfButton: Bool
    var openShelf: () -> Void

    private let silver = Color(red: 0.78, green: 0.80, blue: 0.83)

    var body: some View {
        GeometryReader { geo in
            let sideways = geo.size.width > geo.size.height && geo.size.height < 520
            Group {
                if sideways {
                    HStack(spacing: 18) {
                        door.frame(maxWidth: geo.size.width * 0.52)
                        VStack(spacing: 10) {
                            header
                            Spacer(minLength: 0)
                            readouts
                            transport
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        header
                        Spacer(minLength: 0)
                        door
                        readouts
                        Spacer(minLength: 0)
                        transport
                    }
                }
            }
            .padding(18)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(bodyFinish.ignoresSafeArea())
    }

    // MARK: Pieces

    private var bodyFinish: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.25, green: 0.39, blue: 0.69),
                                    Color(red: 0.11, green: 0.18, blue: 0.40)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            // Soft sheen across the metal
            LinearGradient(colors: [Color.white.opacity(0.10), .clear, Color.black.opacity(0.15)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("TAPEDECK")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .italic()
                    .foregroundColor(silver)
                Text("STEREO CASSETTE PLAYER")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(silver.opacity(0.8))
            }
            Spacer()
            // Battery lamp: lit while the tape is moving
            VStack(spacing: 2) {
                Circle()
                    .fill(lampOn ? Color.red : Color(red: 0.3, green: 0.05, blue: 0.05))
                    .frame(width: 9, height: 9)
                    .shadow(color: lampOn ? .red : .clear, radius: 5)
                Text("BATT").font(.system(size: 6, weight: .bold)).foregroundColor(silver.opacity(0.8))
            }
            .accessibilityHidden(true)

            Button {
                model.soundEffectsOn.toggle()
            } label: {
                Image(systemName: model.soundEffectsOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .frame(width: 38, height: 32)
            }
            .buttonStyle(OrangeButtonStyle())
            .accessibilityLabel(model.soundEffectsOn ? "Tape sound effects on" : "Tape sound effects off")

            if showShelfButton {
                Button(action: openShelf) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .frame(width: 38, height: 32)
                }
                .buttonStyle(OrangeButtonStyle())
                .accessibilityLabel("Tape shelf")
            }
        }
    }

    private var lampOn: Bool {
        model.motion != .stopped && model.motion != .paused
    }

    private var door: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.05))
            if model.hasTape {
                CassetteView(title: model.tapeTitle,
                             subtitle: cassetteSubtitle,
                             progress: model.progress,
                             motion: model.motion)
                    .padding(10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "eject.fill").font(.system(size: 26))
                    Text("NO TAPE").font(.system(size: 14, weight: .bold)).tracking(3)
                    Text(showShelfButton ? "Tap to choose one" : "Pick one from the shelf")
                        .font(.system(size: 11))
                }
                .foregroundColor(silver.opacity(0.55))
            }
            // Door glass
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [Color.white.opacity(0.10), .clear, .clear],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .allowsHitTesting(false)
        }
        .aspectRatio(100.0 / 68.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(silver, lineWidth: 3))
        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
        .contentShape(Rectangle())
        .onTapGesture {
            if !model.hasTape { openShelf() }
        }
    }

    private var cassetteSubtitle: String {
        if model.trackTitle.isEmpty { return model.trackArtist }
        if model.trackTitle == model.tapeTitle { return model.trackArtist }
        return model.trackArtist.isEmpty ? model.trackTitle : "\(model.trackTitle) · \(model.trackArtist)"
    }

    private var readouts: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("COUNTER").font(.system(size: 7, weight: .bold)).foregroundColor(silver.opacity(0.8))
                Text(Self.clock(model.elapsed))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.black))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(silver.opacity(0.6), lineWidth: 1))
                    .accessibilityLabel("Elapsed \(Self.clock(model.elapsed))")
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("VOLUME").font(.system(size: 7, weight: .bold)).foregroundColor(silver.opacity(0.8))
                VolumeSlider().frame(height: 30)
            }
        }
    }

    private var transport: some View {
        HStack(spacing: 6) {
            TapeKey(symbol: "backward.fill", label: "REW", latched: model.motion == .rewind,
                    onDown: { model.seekKeyDown(forward: false) },
                    onUp: { model.seekKeyUp(forward: false) })
            TapeKey(symbol: "play.fill", label: "PLAY", accent: true, latched: model.motion == .playing,
                    onDown: { model.playKey() })
            TapeKey(symbol: "forward.fill", label: "FF", latched: model.motion == .fastForward,
                    onDown: { model.seekKeyDown(forward: true) },
                    onUp: { model.seekKeyUp(forward: true) })
            TapeKey(symbol: "pause.fill", label: "PAUSE", latched: model.motion == .paused,
                    onDown: { model.pauseKey() })
            TapeKey(symbol: "stop.fill", label: "STOP/EJECT",
                    onDown: { if model.stopKey() { openShelf() } })
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.35)))
    }

    private static func clock(_ time: TimeInterval) -> String {
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
    var onDown: () -> Void = {}
    var onUp: () -> Void = {}

    @State private var pressed = false

    var body: some View {
        let down = pressed || latched
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 17, weight: .bold))
            Text(label).font(.system(size: 7, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.6)
        }
        .foregroundColor(accent ? .white : Color(white: 0.15))
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(LinearGradient(colors: keyColors(down: down), startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.black.opacity(0.5), lineWidth: 1))
        .offset(y: down ? 4 : 0)
        .shadow(color: .black.opacity(down ? 0.1 : 0.5), radius: down ? 1 : 3, y: down ? 1 : 4)
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

/// The system volume slider, so volume matches the hardware buttons.
/// It only draws on a real device, not in the Simulator.
struct VolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.tintColor = UIColor(red: 0.96, green: 0.48, blue: 0.13, alpha: 1)
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
