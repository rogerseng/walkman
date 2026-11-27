import SwiftUI

/// The open phone's right half: the chosen tape lying in the tray, waiting for
/// the phone to be closed. The keys are here too, the same ones as on the
/// closed phone, for screens that cannot fold.
struct OpenTrayView: View {
    @EnvironmentObject private var model: PlayerModel
    @State private var showSettings = false
    @Environment(\.playerTheme) private var theme

    private var hint: String {
        if !model.hasTape { return "Choose a tape" }
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
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.3),
                                          style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
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
