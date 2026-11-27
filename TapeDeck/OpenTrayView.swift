import SwiftUI

/// The open phone's right half: the chosen tape lying in the tray, waiting for
/// the phone to be closed. The keys are here too, the same ones as on the
/// closed phone, for screens that cannot fold.
struct OpenTrayView: View {
    @EnvironmentObject private var model: PlayerModel
    @State private var showSettings = false

    private var hint: String {
        if !model.hasTape { return "Choose a tape" }
        if let note = model.endOfSideNote { return note }
        if model.motion == .playing { return model.trackLine.isEmpty ? " " : model.trackLine }
        return "Close the phone, or press PLAY, to start the music"
    }

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                let width = min(geo.size.width, geo.size.height * 0.63)
                let height = width / 0.63
                ZStack {
                    if model.hasTape {
                        DeckCassette()
                            .frame(width: height, height: width)
                            .rotationEffect(.degrees(-90))
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
                .font(.system(size: 14, weight: .semibold))
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
            // The same keys as the closed phone, laid in a row: play/pause,
            // fast forward, rewind, eject and settings.
            TransportKeys(vertical: false, keyHeight: 82, bare: true, big: true, spacing: 12,
                          ejectRemovesTape: true, onSettings: { showSettings = true })
                .frame(maxWidth: 5 * 66 + 4 * 12)
        }
        .padding(20)
        .background(
            RadialGradient(colors: [Color(white: 0.20), Color(white: 0.04)],
                           center: .center, startRadius: 20, endRadius: 520)
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
