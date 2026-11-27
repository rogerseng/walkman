import SwiftUI

/// The open phone's right half: a boombox in the colours of the chosen skin.
/// From the top: the maker's name and a power lamp, the cassette door with
/// the tape behind its window, what is playing and how far through it is, and
/// the speakers. The keys stand in a column down the right, on a panel of
/// their own under the clock, as they do on the closed phone.
/// The door swings open and the tape slides out or in whenever a tape is
/// ejected or put in.
struct OpenTrayView: View {
    /// The open phone held upright: the player fills the screen, with a
    /// carrying handle at the top, the same keys as the closed phone along
    /// the foot, and the shelf behind the music key.
    var upright = false

    @EnvironmentObject private var model: PlayerModel
    @StateObject private var volume = SystemVolume()
    @State private var showShelf = false
    @State private var showSettings = false
    @Environment(\.playerTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Prefs.player) private var player = "tape"
    @AppStorage(Prefs.skin) private var skinName = Skin.standard.rawValue
    /// The door stands open while a tape is on its way in or out.
    @State private var doorOpen = false
    /// Flashes when the empty door is pressed.
    @State private var doorKnocked = false
    /// The height the speakers have with the keyboard down. They keep it
    /// when the keyboard comes up, and the door gives way instead.
    @State private var speakerRest: CGFloat = 0

    private var skin: Skin { Theme.current(player: player, skinName: skinName).skin }
    /// The MP3 player is chosen: the open phone wears its case and shows
    /// its display where the tape deck has its cassette door.
    private var isMP3: Bool { player == "mp3" || skin.isWheel }
    /// The case colours of whichever player is chosen.
    private var bodyColors: [Color] {
        skin.isWheel ? skin.wheelBody : (isMP3 ? skin.panel : skin.casing)
    }

    private var hint: String {
        if !model.hasTape { return upright ? "Tap the door, or the music key, to choose a tape" : "Pick a tape from the shelf" }
        if model.tapeChurn == .winding { return "Winding the tape back in" }
        if model.tapeEaten { return "The deck ate your tape. It happens to the best decks." }
        if let note = model.endOfSideNote { return note }
        if !model.trackLine.isEmpty, model.motion == .playing || model.motion == .paused {
            return model.trackLine
        }
        return "Close the phone, or press play, to start the music"
    }

    var body: some View {
        if upright {
            uprightPlayer
        } else {
            besideShelf
        }
    }

    // MARK: Upright

    private var uprightPlayer: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let keyHeight: CGFloat = 84
            // The handle stands in the space beside the clock, above the
            // safe area, so it costs the player no room.
            let handleHeight = max(64, geo.safeAreaInsets.top)
            // The tape is the thing to look at: the door is as wide as the
            // case allows, and the speakers take what is left under it.
            let doorWidth = min(width - 40, 640, (geo.size.height * 0.52 - 26) / 0.63)
            let doorHeight = doorWidth * 0.63 + 26
            VStack(spacing: 12) {
                topStrip
                if isMP3 {
                    playerScreen(width: doorWidth, height: doorHeight)
                } else {
                    door(width: doorWidth, height: doorHeight)
                }
                nowPlaying
                // A speaker either side of the volume fader
                HStack(spacing: 14) {
                    Speaker(skin: skin, playing: model.motion == .playing, tempo: model.beatsPerMinute)
                    VolumeFader(volume: volume, playing: model.motion == .playing,
                                tempo: model.beatsPerMinute,
                                engraving: skin.engraving, engravingEdge: skin.engravingEdge,
                                engravingEdgeOffset: skin.engravingEdgeOffset)
                        .frame(width: 64)
                        .padding(.vertical, 6)
                    Speaker(skin: skin, playing: model.motion == .playing, tempo: model.beatsPerMinute)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
                uprightKeys(height: keyHeight, below: geo.safeAreaInsets.bottom)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .frame(width: width, height: geo.size.height)
            .background(
                ZStack(alignment: .top) {
                    bodyShell(railWidth: 0, seam: false)
                    CarryHandle(skin: skin)
                        .frame(width: min(320, width * 0.46), height: max(40, handleHeight - 40))
                        .padding(.top, 22)
                }
                .ignoresSafeArea()
            )
        }
        // Keeps the system volume control in the window so the fader can set it.
        .background(
            VolumeHost(view: volume.volumeView)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
        )
        .onChange(of: model.hasTape) { _, _ in swingDoor() }
        .fullScreenCover(isPresented: $showShelf) {
            ShelfView(onPick: { showShelf = false }, onClose: { showShelf = false })
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
    }

    /// The closed phone's keys in a row: play, stop, fast forward, rewind,
    /// the music library, and settings. They are set into a panel that is
    /// the whole foot of the case, from edge to edge and down to the bottom
    /// of the screen, as on the closed phone.
    private func uprightKeys(height: CGFloat, below: CGFloat) -> some View {
        TransportKeys(vertical: false, keyHeight: height, bare: true, big: true, spacing: 12,
                      onSettings: { showSettings = true },
                      onEject: { showShelf = true })
            .padding(.top, 16)
            .padding(.bottom, max(10, 18 - below))
            .frame(maxWidth: .infinity)
            .background(
                ZStack(alignment: .top) {
                    LinearGradient(colors: skin.isWheel ? skin.wheelBody : skin.panel,
                                   startPoint: .top, endPoint: .bottom)
                    if isMP3 { Color.black.opacity(0.22) }
                    PlasticGrain(strength: 0.5)
                    // The seam where the panel meets the body
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.black.opacity(0.75)).frame(height: 2)
                        Rectangle().fill(Color.white.opacity(0.16)).frame(height: 1)
                    }
                }
                // Out to the edges of the screen and down past the safe area
                .padding(.horizontal, -20)
                .padding(.bottom, -below)
                .shadow(color: .black.opacity(0.45), radius: 8, y: -3)
            )
    }

    // MARK: Beside the shelf

    private var besideShelf: some View {
        GeometryReader { geo in
            let width = geo.size.width
            // The Duo keeps a rail clear down the right for its camera and
            // clock. The keys go in it, below them.
            let railWidth = geo.safeAreaInsets.trailing
            let rail = railWidth >= 60
            // The door takes part of the height at most, so the speakers
            // (and the keys, where they sit below) always have room.
            // With the keyboard up there is far less height. The door
            // shrinks to about half of what is left; the speakers keep
            // their size, and the keyboard slides up over their feet.
            let squeezed = geo.safeAreaInsets.bottom > 120 && speakerRest > 0
            let doorWidth = min(width - 36 - (rail ? 12 : 0), 420,
                                (geo.size.height * (squeezed ? 0.5 : rail ? 0.42 : 0.36) - 26) / 0.63)
            let doorHeight = doorWidth * 0.63 + 26
            VStack(spacing: 14) {
                topStrip
                if isMP3 {
                    playerScreen(width: doorWidth, height: doorHeight)
                } else {
                    door(width: doorWidth, height: doorHeight)
                }
                nowPlaying
                if !rail { keyBed }
                // A pair of speakers where there is the width for them, one
                // large one where the space is tall
                GeometryReader { room in
                    let pair = room.size.width > room.size.height * 1.15
                    HStack(spacing: 18) {
                        Speaker(skin: skin, playing: model.motion == .playing, tempo: model.beatsPerMinute)
                        if pair {
                            Speaker(skin: skin, playing: model.motion == .playing, tempo: model.beatsPerMinute)
                        }
                    }
                    .frame(width: room.size.width, height: room.size.height)
                    .onChange(of: room.size.height, initial: true) { _, height in
                        if geo.safeAreaInsets.bottom <= 120 { speakerRest = height }
                    }
                }
                .frame(height: squeezed ? speakerRest : nil)
                .padding(.horizontal, 6)
            }
            .padding(.leading, 16)
            // Clear of the panel the keys stand on, which comes a little
            // way in from the rail
            .padding(.trailing, rail ? 16 + railPanelReach : 16)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .frame(width: width, height: geo.size.height, alignment: .top)
            .clipped()
            .overlay(alignment: .topTrailing) {
                if rail {
                    keyRail(height: geo.size.height,
                            statusHeight: max(0, railStatusHeight - geo.safeAreaInsets.top))
                        // Out of the safe area and into the rail
                        .offset(x: railWidth - railOuterMargin)
                }
            }
            .background(bodyShell(railWidth: rail ? railWidth : 0).ignoresSafeArea())
        }
        .onChange(of: model.hasTape) { _, _ in swingDoor() }
    }

    // MARK: Parts

    /// Height kept clear at the top of the rail for the camera, clock and
    /// status icons, measured from the top of the screen.
    private let railStatusHeight: CGFloat = 116
    private let railKeyWidth: CGFloat = 66
    private let railOuterMargin: CGFloat = 15
    /// How far the key panel comes in past the rail, so the keys have as
    /// much panel on their left as on their right.
    private let railPanelReach: CGFloat = 12

    /// The column of keys in the rail: play, stop, fast forward, rewind and
    /// eject. Settings is on the shelf.
    private func keyRail(height: CGFloat, statusHeight: CGFloat) -> some View {
        let gap: CGFloat = 10
        let room = height - statusHeight - 12
        let keyHeight = min(84, max(36, (room - 4 * gap) / 5))
        return VStack(spacing: 0) {
            Color.clear.frame(height: statusHeight)
            TransportKeys(vertical: true, keyHeight: keyHeight, bare: true, big: true, spacing: gap,
                          ejectRemovesTape: true)
            Spacer(minLength: 0)
        }
        .frame(width: railKeyWidth, height: height)
    }

    /// The solid panel the keys stand on, down the right edge.
    private func keyPanel(width: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: skin.isWheel ? skin.wheelBody : skin.panel,
                           startPoint: .top, endPoint: .bottom)
            // Where the body is already the panel colour, the panel is
            // a shade darker so it still reads as a part of its own.
            if isMP3 { Color.black.opacity(0.22) }
            PlasticGrain(strength: 0.5)
            // The seam where the panel meets the body
            HStack(spacing: 0) {
                Rectangle().fill(Color.black.opacity(0.75)).frame(width: 2)
                Rectangle().fill(Color.white.opacity(0.16)).frame(width: 1)
                Spacer(minLength: 0)
            }
            // On a pale case, a dark plate behind the clock and status
            // icons, which the system draws in white.
            if skin.needsStatusPlate {
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color.black.opacity(0.78))
                    .frame(width: railKeyWidth, height: railStatusHeight - 16)
                    .padding(.trailing, railOuterMargin)
                    .padding(.top, 8)
            }
        }
        .frame(width: width)
        .shadow(color: .black.opacity(0.5), radius: 8, x: -3)
    }

    /// The moulded body: the skin's case colour, grain, and light from above.
    private func bodyShell(railWidth: CGFloat, seam: Bool = true) -> some View {
        ZStack {
            Color.black
            LinearGradient(colors: bodyColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            PlasticGrain(strength: 0.5)
            LinearGradient(colors: [Color.white.opacity(0.10), .clear, Color.black.opacity(0.25)],
                           startPoint: .top, endPoint: .bottom)
            // The seam where this half meets the shelf
            if seam {
            HStack {
                Rectangle().fill(Color.black.opacity(0.7)).frame(width: 2)
                Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1)
                Spacer()
            }
            }
            if railWidth > 0 {
                keyPanel(width: railWidth + railPanelReach)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var topStrip: some View {
        HStack(spacing: 10) {
            Wordmark(size: 22)
                .foregroundColor(skin.mark.opacity(1))
                .shadow(color: skin.engravingEdge.opacity(0.6), radius: 0.3, y: skin.engravingEdgeOffset)
            Spacer(minLength: 0)
            Text(model.hasTape ? "SIDE \(model.sideLetter)" : (isMP3 ? "MP3 PLAYER" : "CASSETTE DECK"))
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
    /// the dark well, and the tape when there is one.
    private func door(width: CGFloat, height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18)
        let tapeWidth = width - 26
        let u = tapeWidth / 100
        return ZStack {
            // The well
            shape.fill(Color(white: 0.04))
            // Upright, the deck's works show faintly in the empty well:
            // the two spindles that turn a tape.
            if upright, !model.hasTape {
                HStack(spacing: 33 * u) {
                    DriveSpindle(u: u).frame(width: 8 * u, height: 8 * u)
                    DriveSpindle(u: u).frame(width: 8 * u, height: 8 * u)
                }
                .opacity(0.16)
                .offset(y: (28.5 - 31.5) * u)
                .transition(.opacity)
            }
            if !model.hasTape {
                VStack(spacing: 5) {
                    Image(systemName: "eject.fill").font(.system(size: 22))
                    Text("NO TAPE").font(Typeface.display(15)).tracking(3)
                    if upright { Text("Tap to choose one").font(.system(size: 11)) }
                }
                .foregroundColor(Color.white.opacity(doorKnocked ? 0.95 : 0.5))
                .scaleEffect(doorKnocked ? 0.92 : 1)
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
        .onTapGesture {
            if model.tapeJammed {
                model.windTapeBack()
            } else if !model.hasTape {
                // Nothing to press on: the door knocks and gives a little.
                // Upright there is no shelf beside it, so it opens the shelf.
                model.knockEmptyDeck()
                if upright { showShelf = true }
                withAnimation(.easeOut(duration: 0.08)) { doorKnocked = true }
                Task {
                    try? await Task.sleep(nanoseconds: 160_000_000)
                    withAnimation(.easeOut(duration: 0.2)) { doorKnocked = false }
                }
            }
        }
        // Lean on a reel and the deck eats the tape.
        .overlay {
            if model.hasTape, !model.tapeJammed {
                HStack(spacing: 17 * u) {
                    ForEach(0..<2, id: \.self) { _ in
                        Color.clear
                            .frame(width: 24 * u, height: 24 * u)
                            .contentShape(Circle())
                            .onTapGesture(count: 2) { model.flipTape() }
                            .onLongPressGesture(minimumDuration: 0.7) { model.eatTape() }
                    }
                }
                .offset(y: -3 * u)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.hasTape ? "\(model.tapeTitle), side \(model.sideLetter)" : "No tape")
        .accessibilityAction(named: "Turn the tape over") { model.flipTape() }
    }

    /// What is playing, and the way to turn the tape over.
    private var nowPlaying: some View {
        VStack(spacing: 8) {
            // The MP3 player's display already names the song.
            if !(isMP3 && hint == model.trackLine) {
            Label {
                Text(hint)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } icon: {
                if model.hasTape {
                    Image(systemName: model.tapeChurn == .winding ? "arrow.triangle.2.circlepath"
                          : model.tapeEaten ? "exclamationmark.triangle.fill"
                          : model.endOfSideNote == nil ? "music.note" : "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .foregroundColor(skin.note)
            .frame(maxWidth: .infinity, minHeight: 36)
            }

            // The MP3 player's display has a bar of its own.
            if model.hasTape, model.duration > 0, !model.tapeJammed, !isMP3 { timeline }

            if model.hasTape, model.tapeChurn == .winding {
                WindingReel().frame(width: 30, height: 30).foregroundColor(theme.accentColor)
            } else if model.hasTape, model.tapeEaten {
                Button {
                    model.windTapeBack()
                } label: {
                    Text("Wind it back in")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(PlainKeyButtonStyle())
            } else if model.hasTape, model.canFlip {
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

    /// The MP3 player's display, in the colours it has on the closed phone:
    /// what is playing, whose it is, the tape it is on, and how far through.
    private func playerScreen(width: CGFloat, height: CGFloat) -> some View {
        let look = MenuPlayerView.display(jog: !skin.isWheel, skin: skin)
        let shape = RoundedRectangle(cornerRadius: 14)
        let done = model.duration > 0 ? min(1, max(0, model.elapsed / model.duration)) : 0
        return VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(model.hasTape ? "Now Playing" : "Cassety")
                    .font(.system(size: 13, weight: .bold))
                Spacer(minLength: 0)
                Image(systemName: model.motion == .playing ? "play.fill" : "pause.fill")
                    .font(.system(size: 11, weight: .bold))
                    .opacity(model.hasTape ? 1 : 0)
            }
            .foregroundColor(look.barInk)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(LinearGradient(colors: [look.barTop, look.barBottom], startPoint: .top, endPoint: .bottom))

            VStack(alignment: .leading, spacing: 4) {
                if model.hasTape {
                    Text(model.trackTitle.isEmpty ? model.tapeTitle : model.trackTitle)
                        .font(.system(size: 19, weight: .bold))
                        .lineLimit(2)
                    Text(model.trackArtist)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(model.tapeTitle)
                        .font(Typeface.markerFixed(15))
                        .lineLimit(1)
                        .opacity(0.7)
                    Spacer(minLength: 4)
                    GeometryReader { bar in
                        ZStack(alignment: .leading) {
                            Capsule().fill(look.track)
                            Capsule().fill(look.litBottom).frame(width: bar.size.width * CGFloat(done))
                        }
                    }
                    .frame(height: 8)
                    HStack {
                        Text(TransportKeys.clock(model.elapsed))
                        Spacer()
                        Text("Side \(model.sideLetter)")
                        Spacer()
                        Text("-" + TransportKeys.clock(max(0, model.duration - model.elapsed)))
                    }
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .opacity(0.85)
                } else {
                    Spacer(minLength: 0)
                    Text("No tape")
                        .font(.system(size: 19, weight: .bold))
                        .frame(maxWidth: .infinity)
                    Text("Pick one from the shelf")
                        .font(.system(size: 13, weight: .semibold))
                        .opacity(0.7)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
            }
            .foregroundColor(look.ink)
            .shadow(color: look.glow, radius: 4)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(look.paper)
        .clipShape(shape)
        // The bezel the display sits in
        .overlay(shape.strokeBorder(Color.black.opacity(0.9), lineWidth: 5))
        .overlay(shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.3)],
                                                   startPoint: .top, endPoint: .bottom), lineWidth: 1))
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.6), radius: 8, y: 5)
        .onTapGesture(count: 2) { model.flipTape() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.hasTape ? "\(model.trackTitle), \(model.trackArtist)" : "No tape")
        .accessibilityAction(named: "Turn the tape over") { model.flipTape() }
    }

    /// How far through the song the tape is: a bar, with the time gone and
    /// the time left under its ends.
    private var timeline: some View {
        let done = min(1, max(0, model.elapsed / model.duration))
        return VStack(spacing: 5) {
            GeometryReader { bar in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.45))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                    Capsule()
                        .fill(theme.accentColor)
                        .frame(width: max(6, bar.size.width * CGFloat(done)))
                        .shadow(color: theme.accentColor.opacity(0.6), radius: 4)
                }
            }
            .frame(height: 6)
            HStack {
                Text(TransportKeys.clock(model.elapsed))
                Spacer()
                Text("-" + TransportKeys.clock(max(0, model.duration - model.elapsed)))
            }
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundColor(skin.note.opacity(0.85))
        }
        .frame(maxWidth: 360)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Song position")
        .accessibilityValue("\(TransportKeys.clock(model.elapsed)) of \(TransportKeys.clock(model.duration))")
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

/// The boombox's carrying handle: a hand hole cut clean through the top of
/// the case, dark inside, with the wall of the cut catching the light along
/// its lower lip.
private struct CarryHandle: View {
    let skin: Skin

    var body: some View {
        GeometryReader { geo in
            let slot = RoundedRectangle(cornerRadius: min(22, geo.size.height * 0.4))
            ZStack {
                // Through the hole: the dark behind the case
                slot.fill(LinearGradient(colors: [Color.black, Color(white: 0.07)],
                                         startPoint: .top, endPoint: .bottom))
                // The case has thickness: its upper wall is in shadow
                slot.strokeBorder(Color.black.opacity(0.9), lineWidth: 10)
                    .blur(radius: 6)
                    .offset(y: 5)
                    .clipShape(slot)
                // and its lower wall faces the light
                slot.strokeBorder(LinearGradient(colors: [.clear, .clear, Color.white.opacity(0.22)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 3)
                // The edge of the cut, dark above and lit below
                slot.strokeBorder(LinearGradient(colors: [Color.black.opacity(0.85), Color.white.opacity(0.28)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
            }
            // A soft roll of the case round the hole
            .background(
                slot.stroke(Color.white.opacity(0.10), lineWidth: 2).blur(radius: 1.5).offset(y: 1.5)
            )
        }
        .accessibilityHidden(true)
    }
}

/// The boombox's speaker: a perforated grille over a cone, in a trim ring.
/// The cone moves a little in time with the song's tempo while a tape
/// plays: a small push on each beat, and nothing more. It is for show: the
/// app cannot hear what the music service plays.
private struct Speaker: View {
    let skin: Skin
    let playing: Bool
    var tempo = PlayerModel.defaultTempo
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
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !playing || reduceMotion)) { timeline in
                    let kick = Self.kick(at: timeline.date, tempo: tempo, moving: playing && !reduceMotion)
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
                    .scaleEffect(1 + 0.028 * kick)
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
            .modifier(Thump(playing: playing && !reduceMotion, tempo: tempo))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    /// How far out the cone is, from 0 to 1: out on each beat of the
    /// song's tempo, and settling back before the next.
    static func kick(at date: Date, tempo: Double, moving: Bool) -> Double {
        guard moving else { return 0 }
        let beat = date.timeIntervalSinceReferenceDate * tempo / 60
        let phase = beat - floor(beat)
        return exp(-phase * 5)
    }

    /// The whole speaker swelling a little with each push of the cone.
    private struct Thump: ViewModifier {
        let playing: Bool
        let tempo: Double

        func body(content: Content) -> some View {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !playing)) { timeline in
                content.scaleEffect(1 + 0.004 * Speaker.kick(at: timeline.date, tempo: tempo, moving: playing))
            }
        }
    }
}
