import SwiftUI

/// The open phone's right half: the chosen tape lying in the tray, waiting for
/// the phone to be closed. The keys are here too, the same ones as on the
/// closed phone, for screens that cannot fold.
struct OpenTrayView: View {
    @EnvironmentObject private var model: PlayerModel
    @State private var showSettings = false
    @Environment(\.playerTheme) private var theme
    @AppStorage(Prefs.player) private var player = "tape"
    @AppStorage(Prefs.skin) private var skinName = Skin.standard.rawValue

    private var hint: String {
        if !model.hasTape { return "Pick a tape from the shelf" }
        if let note = model.endOfSideNote { return note }
        if model.motion == .playing { return model.trackLine.isEmpty ? " " : model.trackLine }
        return "Close the phone, or press PLAY, to start the music"
    }

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                // Lying flat in the tray, long side across, as big as fits
                let width = min(geo.size.width, geo.size.height / 0.63)
                let height = width * 0.63
                ZStack {
                    if model.hasTape {
                        DeckCassette()
                            .frame(width: width, height: height)
                            // Turning it over swings it round its long edge.
                            .rotation3DEffect(.degrees(model.flipAngle), axis: (x: 1, y: 0, z: 0),
                                              perspective: 0.4)
                            .onTapGesture(count: 2) { model.flipTape() }
                            .transition(.opacity)
                    } else {
                        EmptyTray(skin: Theme.current(player: player, skinName: skinName).skin,
                                  width: width)
                            .frame(width: width, height: height)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            Text(hint)
                .font(Typeface.display(15))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.85))
            if model.hasTape {
                Button {
                    model.flipTape()
                } label: {
                    Text("Flip to side \(model.sideLetter == "A" ? "B" : "A")")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(PlainKeyButtonStyle())
            }
            // The same keys as the closed phone, laid in a row: play, stop,
            // fast forward, rewind, eject and settings.
            TransportKeys(vertical: false, keyHeight: 82, bare: true, big: true, spacing: 12,
                          ejectRemovesTape: true, onSettings: { showSettings = true })
                .frame(maxWidth: 6 * 66 + 5 * 12)
        }
        .padding(20)
        .background(
            // A dusk sky in the chosen skin's colours, warming at the foot
            LinearGradient(colors: theme.duskColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

/// The empty tray on the open phone, drawn like the empty well on the closed
/// one: a dark window cut in the case, the two drive spindles faint inside,
/// and the same prompt.
private struct EmptyTray: View {
    let skin: Skin
    let width: CGFloat

    var body: some View {
        let u = width / 100
        let opening = RoundedRectangle(cornerRadius: 20)
        ZStack {
            opening.fill(Color(white: 0.04))
            opening.strokeBorder(Color.black.opacity(0.75), lineWidth: 8).blur(radius: 5).clipShape(opening)
            opening.fill(LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.02), .clear],
                                        startPoint: .topLeading, endPoint: .center))
            // The spindles, where a tape's hubs would sit on them
            HStack(spacing: 33 * u) {
                DriveSpindle(u: u)
                DriveSpindle(u: u)
            }
            .opacity(0.28)
            .offset(y: (28.5 - 31.5) * u)
            VStack(spacing: 6) {
                Image(systemName: "eject.fill").font(.system(size: 24))
                Text("NO TAPE").font(Typeface.display(16)).tracking(3)
            }
            .foregroundColor(Color.white.opacity(0.5))
            .offset(y: 10 * u)
            opening.strokeBorder(LinearGradient(colors: skin.windowEdge,
                                                startPoint: .topLeading, endPoint: .bottomTrailing),
                                 lineWidth: 2.5)
                .shadow(color: skin.hasStripes ? Skin.hotPink.opacity(0.8) : .clear, radius: 6)
            opening.strokeBorder(Color.black.opacity(0.55), lineWidth: 1.5).padding(2.5)
        }
    }
}

