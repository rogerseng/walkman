import SwiftUI

/// The open phone's right half: a boombox in the colours of the chosen skin.
/// From the top: the maker's name and a power lamp, the cassette door with
/// the tape behind its window, what is playing, the keys, and the speaker.
/// The door swings open and the tape slides out or in whenever a tape is
/// ejected or put in.
struct OpenTrayView: View {
    @EnvironmentObject private var model: PlayerModel
    @Environment(\.playerTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Prefs.player) private var player = "tape"
    @AppStorage(Prefs.skin) private var skinName = Skin.standard.rawValue
    /// The door stands open while a tape is on its way in or out.
    @State private var doorOpen = false

    private var skin: Skin { Theme.current(player: player, skinName: skinName).skin }

    private var hint: String {
        if !model.hasTape { return "Pick a tape from the shelf" }
        if let note = model.endOfSideNote { return note }
        if !model.trackLine.isEmpty, model.motion == .playing || model.motion == .paused {
            return model.trackLine
        }
        return "Close the phone, or press play, to start the music"
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            // The door takes about a third of the height at most, so the
            // keys and speakers always have room under it.
            let doorWidth = min(width - 36, 420, (geo.size.height * 0.36 - 26) / 0.63)
            let doorHeight = doorWidth * 0.63 + 26
            VStack(spacing: 14) {
                topStrip
                door(width: doorWidth, height: doorHeight)
                nowPlaying
                keyBed
                // A pair of speakers where there is the width for them, one
                // large one where the space is tall
                GeometryReader { room in
                    let pair = room.size.width > room.size.height * 1.5
                    HStack(spacing: 18) {
                        Speaker(skin: skin, playing: model.motion == .playing)
                        if pair {
                            Speaker(skin: skin, playing: model.motion == .playing)
                        }
                    }
                    .frame(width: room.size.width, height: room.size.height)
                }
                .padding(.horizontal, 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .frame(width: width, height: geo.size.height)
        }
        .background(bodyShell.ignoresSafeArea())
        .onChange(of: model.hasTape) { _, _ in swingDoor() }
    }

    // MARK: Parts

    /// The moulded body: the skin's case colour, grain, and light from above.
    private var bodyShell: some View {
        ZStack {
            Color.black
            LinearGradient(colors: skin.isWheel ? skin.wheelBody : skin.casing,
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            PlasticGrain(strength: 0.5)
            LinearGradient(colors: [Color.white.opacity(0.10), .clear, Color.black.opacity(0.25)],
                           startPoint: .top, endPoint: .bottom)
            // The seam where this half meets the shelf
            HStack {
                Rectangle().fill(Color.black.opacity(0.7)).frame(width: 2)
                Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1)
                Spacer()
            }
        }
    }

    private var topStrip: some View {
        HStack(spacing: 10) {
            Wordmark(size: 22)
                .foregroundColor(skin.mark.opacity(1))
                .shadow(color: skin.engravingEdge.opacity(0.6), radius: 0.3, y: skin.engravingEdgeOffset)
            Spacer(minLength: 0)
            Text(model.hasTape ? "SIDE \(model.sideLetter)" : "CASSETTE DECK")
                .font(Typeface.displayFixed(9))
                .tracking(1.6)
                .foregroundColor(skin.engraving)
            // Power lamp: lit while the tape is moving
            Circle()
                .fill(model.motion == .playing ? theme.accentColor : Color.black.opacity(0.6))
                .frame(width: 9, height: 9)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.6), lineWidth: 1))
                .shadow(color: model.motion == .playing ? theme.accentColor : .clear, radius: 5)
        }
        .accessibilityHidden(true)
    }

    /// The cassette door: a chrome bezel round a smoked window. Behind it is
    /// the well with its two spindles, and the tape when there is one.
    private func door(width: CGFloat, height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18)
        let tapeWidth = width - 26
        let u = tapeWidth / 100
        return ZStack {
            // The well
            shape.fill(Color(white: 0.04))
            HStack(spacing: 33 * u) {
                DriveSpindle(u: u)
                DriveSpindle(u: u)
            }
            .opacity(model.hasTape ? 0 : 0.28)
            .offset(y: (28.5 - 31.5) * u)
            if !model.hasTape {
                VStack(spacing: 5) {
                    Image(systemName: "eject.fill").font(.system(size: 22))
                    Text("NO TAPE").font(Typeface.display(15)).tracking(3)
                }
                .foregroundColor(Color.white.opacity(0.5))
                .offset(y: 12 * u)
                .transition(.opacity)
            }

            // The tape drops in from above and lifts out the same way
            if model.hasTape {
                DeckCassette()
                    .frame(width: tapeWidth, height: tapeWidth * 0.63)
                    .rotation3DEffect(.degrees(model.flipAngle), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
                    .transition(reduceMotion
                                ? .opacity
                                : .asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                              removal: .move(edge: .top).combined(with: .opacity)))
            }

            // Smoked glass over the lot, and the shadow of the frame
            shape.fill(LinearGradient(colors: [Color.white.opacity(0.13), Color.white.opacity(0.02), .clear],
                                      startPoint: .topLeading, endPoint: .center))
                .allowsHitTesting(false)
            shape.strokeBorder(Color.black.opacity(0.7), lineWidth: 7).blur(radius: 4).clipShape(shape)
                .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        // The bezel: brushed metal with the skin's window edge inside it
        .overlay(
            shape.strokeBorder(LinearGradient(colors: [Color(white: 0.92), Color(white: 0.55), Color(white: 0.78)],
                                              startPoint: .top, endPoint: .bottom), lineWidth: 4)
        )
        .overlay(
            shape.strokeBorder(LinearGradient(colors: skin.windowEdge,
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                .padding(4)
                .shadow(color: skin.hasStripes ? Skin.hotPink.opacity(0.8) : .clear, radius: 5)
        )
        .shadow(color: .black.opacity(0.6), radius: 8, y: 5)
        // Hinged along its foot: it tips toward you to take or give a tape
        .rotation3DEffect(.degrees(doorOpen ? -24 : 0), axis: (x: 1, y: 0, z: 0),
                          anchor: .bottom, perspective: 0.55)
        .onTapGesture(count: 2) { model.flipTape() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.hasTape ? "\(model.tapeTitle), side \(model.sideLetter)" : "No tape")
        .accessibilityAction(named: "Turn the tape over") { model.flipTape() }
    }

    /// What is playing, and the way to turn the tape over.
    private var nowPlaying: some View {
        VStack(spacing: 8) {
            Label {
                Text(hint)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } icon: {
                if model.hasTape {
                    Image(systemName: model.endOfSideNote == nil ? "music.note" : "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .foregroundColor(skin.note)
            .frame(maxWidth: .infinity, minHeight: 36)

            if model.hasTape, model.canFlip {
                Button {
                    model.flipTape()
                } label: {
                    Text("Flip to side \(model.sideLetter == "A" ? "B" : "A")")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(PlainKeyButtonStyle())
            }
        }
    }

    /// The keys, set in a recessed bed of the skin's panel colour: play,
    /// stop, fast forward, rewind and eject. Settings is on the shelf.
    private var keyBed: some View {
        TransportKeys(vertical: false, keyHeight: 78, bare: true, big: true, spacing: 10,
                      ejectRemovesTape: true)
            .frame(maxWidth: 5 * 66 + 4 * 10)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: skin.isWheel ? skin.wheelBody : skin.panel,
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(PlasticGrain(strength: 0.5).clipShape(RoundedRectangle(cornerRadius: 16)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(LinearGradient(colors: [Color.black.opacity(0.8), Color.white.opacity(0.22)],
                                                         startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                    )
            )
    }

    /// Opens the door, lets the tape travel, and shuts it again.
    private func swingDoor() {
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.22)) { doorOpen = true }
        Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { doorOpen = false }
        }
    }
}

/// The boombox's speaker: a perforated grille over a cone, in a trim ring.
/// The cone moves a little in time while a tape plays. It is for show: the
/// app cannot hear what the music service plays.
private struct Speaker: View {
    let skin: Skin
    let playing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                // Trim ring
                Circle()
                    .fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.45), Color(white: 0.70)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().fill(Color(white: 0.06)).padding(size * 0.035)
                // The cone, seen through the grille
                TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !playing || reduceMotion)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let beat = time * 2.05
                    let kick = playing && !reduceMotion ? exp(-(beat - floor(beat)) * 5) : 0
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [Color(white: 0.20), Color(white: 0.09), Color(white: 0.16)],
                                                 center: .center, startRadius: 0, endRadius: size * 0.42))
                            .padding(size * 0.07)
                        Circle()
                            .fill(RadialGradient(colors: [Color(white: 0.34), Color(white: 0.12)],
                                                 center: .init(x: 0.4, y: 0.35), startRadius: 0,
                                                 endRadius: size * 0.14))
                            .frame(width: size * 0.26, height: size * 0.26)
                    }
                    .scaleEffect(1 + 0.012 * kick)
                }
                // Grille: rows of holes punched in the skin's panel colour
                Canvas { context, canvas in
                    let centre = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                    let radius = size / 2 - size * 0.05
                    let pitch = max(5.5, size / 46)
                    var y = centre.y - radius
                    var row = 0
                    while y <= centre.y + radius {
                        var x = centre.x - radius + (row % 2 == 0 ? 0 : pitch / 2)
                        while x <= centre.x + radius {
                            let dx = x - centre.x
                            let dy = y - centre.y
                            if dx * dx + dy * dy <= radius * radius {
                                let hole = CGRect(x: x - pitch * 0.2, y: y - pitch * 0.2,
                                                  width: pitch * 0.4, height: pitch * 0.4)
                                context.fill(Path(ellipseIn: hole.offsetBy(dx: 0, dy: 0.6)),
                                             with: .color(.white.opacity(0.10)))
                                context.fill(Path(ellipseIn: hole), with: .color(.black.opacity(0.85)))
                            }
                            x += pitch
                        }
                        y += pitch * 0.86
                        row += 1
                    }
                }
                .background(
                    Circle()
                        .fill(LinearGradient(colors: skin.isWheel ? skin.wheelBody : skin.panel,
                                             startPoint: .top, endPoint: .bottom))
                        .opacity(0.72)
                        .padding(size * 0.045)
                )
                .clipShape(Circle())
                .padding(size * 0.035)
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.55), radius: 8, y: 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}
