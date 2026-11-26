import SwiftUI

/// The open phone's right half: the chosen tape lying in the tray, waiting for
/// the phone to be closed. The keys are here too, for screens that cannot fold.
struct OpenTrayView: View {
    @EnvironmentObject private var model: PlayerModel

    private var hint: String {
        if !model.hasTape { return "Choose a tape" }
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
                        CassetteView(title: model.tapeTitle,
                                     subtitle: model.trackLine,
                                     progress: model.progress,
                                     motion: model.motion)
                            .frame(width: height, height: width)
                            .rotationEffect(.degrees(-90))
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
            TransportKeys(vertical: false)
        }
        .padding(20)
        .background(
            RadialGradient(colors: [Color(white: 0.20), Color(white: 0.04)],
                           center: .center, startRadius: 20, endRadius: 520)
                .ignoresSafeArea()
        )
    }
}
