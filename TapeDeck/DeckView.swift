import SwiftUI

/// The closed phone: the whole screen is the body of a tape player in dark
/// plastic with the cassette inside it. The cassette stands on end and runs
/// underneath the body and the keys. The smoked body covers most of it,
/// dimly showing what is underneath, and a clear window over the label and
/// reels shows the tape itself.
///
/// On an iPhone the keys run in a row along a solid panel at the foot of the
/// screen, with the volume fader lying across the panel over them, so the
/// window can take the whole width above them.
///
/// The iPhone Duo's outer display (466 x 678 points) has an 84 point column
/// down one side that iOS reports as a safe area inset, with the camera,
/// clock and status icons at its top. There the keys go in that column
/// underneath them, the fader stands on the solid side of the case beside
/// the window, and the cassette fills the screen.
struct DeckView: View {
    @EnvironmentObject private var model: PlayerModel
    @EnvironmentObject private var tour: Tour
    /// The phone's volume, which the fader on the panel sets.
    @StateObject private var volume = SystemVolume()
    @State private var showSettings = false
    @State private var showSongs = false
    /// True while a finger is on the tape window.
    @GestureState private var touchingWindow = false
    @Environment(\.playerTheme) private var theme
    @AppStorage(Prefs.skin) private var skinName = Skin.standard.rawValue
    var openShelf: () -> Void
    /// An ordinary iPhone wearing the Duo's look: the keys in a column
    /// down the right, with the tape as big as the rest of the screen
    /// allows. The phone has no rail of its own, so one is made for it.
    var sideKeys = false
    /// The width of the column made for the keys on such a phone.
    private let phoneRail: CGFloat = 104
    /// On such a phone, the width of the keys in that column.
    private let phoneKeyWidth: CGFloat = 72

    private var skin: Skin {
        let stored = Skin(rawValue: skinName) ?? Skin.standard
        return stored.isWheel ? Skin.standard : stored
    }

    /// The status pill in the Duo's rail is 66 points wide, centred 48
    /// points in from the screen edge.
    private let railKeyWidth: CGFloat = 66
    private let railOuterMargin: CGFloat = 15
    /// Keys in the rail are up to 84 points tall.
    private let railKeyMaxHeight: CGFloat = 84
    private let keyGap: CGFloat = 10
    /// Height kept clear at the top of the rail for the camera, clock and
    /// status icons. Measured from a Duo screenshot, where the status pill
    /// ends about 154 points down; not a published figure.
    private let railStatusHeight: CGFloat = 180
    /// How far the panel's top edge falls back at the screen edges.
    private let panelBow: CGFloat = 14
    /// Height of the row the fader lies in, on phones without a rail.
    private let faderRow: CGFloat = 44
    /// Margin from the screen edges to the row of keys.
    private let keysMargin: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let real = geo.safeAreaInsets
            // A column for the keys is made on a phone that has no rail.
            let phone = sideKeys && max(real.leading, real.trailing) < 60
            let insets = phone ? EdgeInsets(top: real.top, leading: real.leading,
                                            bottom: real.bottom, trailing: phoneRail) : real
            let full = CGSize(width: geo.size.width + real.leading + real.trailing,
                              height: geo.size.height + real.top + real.bottom)
            let plan = layout(full: full, insets: insets, phone: phone)
            // The part of the window that shows: on a phone the window runs
            // on under the side panel.
            let window = plan.seen ?? plan.window
            ZStack(alignment: .topLeading) {
                // The face itself is drawn in the background, full screen.
                // Double-tap the tape to turn it over.
                Color.clear
                    .frame(width: full.width, height: plan.panelTop)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        model.flipTape()
                    }
                    .onTapGesture {
                        if model.tapeEaten {
                            model.windTapeBack()
                        } else if !model.hasTape {
                            openShelf()
                        }
                    }
                    // The empty deck answers a press as it lands, before
                    // the tap is over.
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .updating($touchingWindow) { _, touching, _ in touching = true }
                    )
                    .onChange(of: touchingWindow) { _, touching in
                        if touching { model.knockEmptyDeck() }
                    }
                    // For VoiceOver, which cannot double-tap the tape itself
                    .accessibilityElement()
                    .accessibilityLabel(model.hasTape
                                        ? "\(model.tapeTitle), side \(model.sideLetter)"
                                        : "No tape")
                    .accessibilityHint(model.hasTape ? "" : "Opens the tape shelf")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        if !model.hasTape { openShelf() }
                    }
                    .accessibilityAction(named: "Turn the tape over") { model.flipTape() }

                // Lean on a reel and the deck eats the tape.
                if model.hasTape, !model.tapeJammed {
                    ForEach([-20.5, 20.5], id: \.self) { along in
                        Color.clear
                            .frame(width: 24 * plan.scale, height: 24 * plan.scale)
                            .contentShape(Circle())
                            .onTapGesture(count: 2) { model.flipTape() }
                            .onLongPressGesture(minimumDuration: 0.7) { model.eatTape() }
                            .position(x: plan.cassetteCenter.x - 3 * plan.scale,
                                      y: plan.cassetteCenter.y + along * plan.scale)
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(width: full.width, height: full.height, alignment: .topLeading)
            .background(
                ZStack {
                    Color(white: 0.03)
                    tapeUnderCasing(plan)
                    clearCase
                    if plan.rail {
                        // On the Duo, the solid side of the case starts just
                        // past the tape window and runs to the edge, so it
                        // carries the volume fader and the keys.
                        // On a phone the panel bows only a little, and reaches
                        // far enough in that the keys sit inside it top to
                        // bottom.
                        casePanel(seam: plan.railLeading ? .trailing : .leading, bow: phone ? 10 : nil)
                            .frame(width: phone ? plan.panelWidth + 4 : plan.panelWidth)
                            .frame(maxWidth: .infinity, alignment: plan.railLeading ? .leading : .trailing)
                    } else {
                        // Along the foot, the panel the keys sit in
                        casePanel(seam: .top)
                            .frame(height: full.height - plan.panelTop)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    // On a pale case, a dark plate behind the Duo's clock and
                    // status icons, which the system draws in white.
                    if plan.rail, !phone, skin.needsStatusPlate {
                        RoundedRectangle(cornerRadius: 26)
                            .fill(Color.black.opacity(0.78))
                            .frame(width: railKeyWidth, height: 156)
                            .padding(plan.railLeading ? .leading : .trailing, railOuterMargin)
                            .padding(.top, 16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                   alignment: plan.railLeading ? .topLeading : .topTrailing)
                    }
                }
            )
            // The maker's name, moulded faintly into the top corner of the case
            .overlay(alignment: .topLeading) {
                Wordmark()
                    .foregroundColor(skin.mark)
                    .shadow(color: skin.engravingEdge.opacity(0.6), radius: 0.3, y: skin.engravingEdgeOffset)
                    .offset(x: plan.contentLeft + 8, y: insets.top + 16 + headLift(plan, insets))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            // Level with the name, at the window's far corner: the songs on
            // the tape that is in the deck
            .overlay(alignment: .topLeading) {
                if hasSongList {
                    Button {
                        Haptics.detent()
                        showSongs = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(skin.note.opacity(0.7))
                            .frame(width: 46, height: 38)
                            // Cut out of the case: flush with it, with only
                            // the fine gap round the key to show where it is
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                                    .offset(y: 1.2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.black.opacity(0.78), lineWidth: 1.6)
                            )
                            .frame(width: 46, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Songs on this tape")
                    .offset(x: window.maxX - (plan.seen == nil ? 46 : 54), y: insets.top + 6 + headLift(plan, insets))
                }
            }
            // A word in outline lettering above the window, on cases that have one
            .overlay(alignment: .topLeading) {
                if let word = skin.caseWord {
                    OutlinedWord(text: word, fill: skin.casing[1].opacity(1))
                        .frame(width: window.width)
                        .offset(x: window.minX, y: window.minY - 34)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            // Under the window: the song that is playing on an album tape
            // (its printed label has no room for it), or word that the tape
            // has run out.
            .overlay(alignment: .topLeading) {
                if let note = underWindowNote {
                    // The song, in plain type with a note beside it, so it
                    // reads on every case colour.
                    Label {
                        Text(note)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    } icon: {
                        Image(systemName: model.endOfSideNote == nil ? "music.note" : "stop.circle")
                            .font(.system(size: 13, weight: .bold))
                    }
                        .foregroundColor(skin.note)
                        .shadow(color: .black.opacity(skin == .yellow ? 0 : 0.6), radius: 2)
                        .frame(width: window.width)
                        .offset(x: window.minX, y: window.maxY + (plan.rail ? footGap(plan, full) : 8))
                        .allowsHitTesting(false)
                }
            }
            // On the Duo: the volume fader on the solid side, level with the
            // window and as tall as it, and the keys in the rail
            .overlay(alignment: .topLeading) {
                if phone {
                    // On a phone the fader stands in the column, over the keys.
                    EmptyView()
                } else if plan.rail {
                    // Never under the keys
                    let keysLeft = full.width - plan.railWidth
                    let faderX = plan.railLeading ? plan.panelWidth - 70
                        : min(full.width - plan.panelWidth + 22, keysLeft - 48 - 4)
                    VStack(spacing: 9) {
                        fader
                            .frame(width: 48, height: window.height)
                        // Engraved under the fader
                        volumeWord
                            .fixedSize()
                            .frame(width: 48)
                    }
                    .offset(x: faderX, y: window.minY)
                }
            }
            .overlay(alignment: plan.railLeading ? .topLeading : .topTrailing) {
                if plan.rail {
                    // On a phone the keys sit at the foot, under the thumb;
                    // on the Duo they start a little below the clock.
                    railKeyColumn(insets: insets, leading: plan.railLeading,
                                  statusHeight: phone ? real.top + 10 : railStatusHeight + 14,
                                  fromFoot: phone)
                }
            }
            // On other phones, the panel along the foot: the fader lying
            // across it, and the row of keys under that
            .overlay(alignment: .topLeading) {
                if !plan.rail {
                    let rowWidth = full.width - 2 * keysMargin
                    let length = rowWidth - 56 - 10
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            volumeWord.frame(width: 56, alignment: .leading)
                            // Laid on its side: the loud end is on the right.
                            fader
                                .frame(width: 48, height: length)
                                .rotationEffect(.degrees(90))
                                .frame(width: length, height: faderRow)
                        }
                        .frame(width: rowWidth, height: faderRow)
                        TransportKeys(vertical: false, keyHeight: plan.keyHeight, bare: true, big: true,
                                      spacing: keyGap,
                                      onSettings: { showSettings = true },
                                      onEject: openShelf)
                            .frame(width: rowWidth)
                    }
                    .offset(x: keysMargin, y: plan.panelTop + panelBow + 8)
                }
            }
            // The tape has run out: say so in the window, with the way on
            .overlay(alignment: .topLeading) {
                if model.hasTape, model.sideEnded {
                    EndOfSideCard()
                        .frame(width: window.width - 28)
                        .position(x: window.midX, y: window.midY)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.sideEnded)
            // The deck has eaten the tape: own up, and offer to wind it back
            .overlay(alignment: .topLeading) {
                if model.hasTape, model.tapeEaten || model.tapeChurn == .winding {
                    TapeEatenCard()
                        .frame(width: window.width - 28)
                        .position(x: window.midX, y: window.minY + window.height * 0.74)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            // The card waits for the tape to finish spilling, and goes at once.
            .animation(model.tapeJammed ? .spring(response: 0.35, dampingFraction: 0.8).delay(1.3)
                                        : .easeOut(duration: 0.15),
                       value: model.tapeJammed)
            // The tour: the tape lit up when it is the thing to touch, and
            // the card saying what to do
            .overlay(alignment: .topLeading) {
                if tour.step?.onTape == true {
                    TourPulse(corner: 20)
                        .frame(width: window.width, height: window.height)
                        .offset(x: window.minX, y: window.minY)
                }
            }
            // The card sits just above the panel, clear of the keys it asks for
            .overlay(alignment: .bottomLeading) {
                if plan.rail {
                    // On the Duo the keys are at the side, so the card
                    // sits at the foot of the window.
                    TourCard(tour: tour)
                        .frame(width: max(240, window.width + 20))
                        .offset(x: max(10, window.minX - 10), y: -(insets.bottom + 14))
                } else {
                    let cardWidth = min(full.width - 20, max(240, window.width + 20))
                    TourCard(tour: tour)
                        .frame(width: cardWidth)
                        .offset(x: max(10, window.midX - cardWidth / 2),
                                y: -(full.height - plan.panelTop + 8))
                }
            }
            .environment(\.tourKey, tour.step?.key)
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showSongs) {
            CurrentTapeView(onClose: { showSongs = false })
        }
        // The tour moves on when the listener has really done what it asked
        .onReceive(model.events) { event in
            switch event {
            case .inserted: tour.completed(.chooseTape)
            case .played: tour.completed(.play)
            case .stopped: tour.completed(.stop)
            case .skipped: tour.completed(.skip)
            case .wound: tour.completed(.wind)
            case .flipped: tour.completed(.flip)
            }
        }
        // A step that is already done when it comes up is passed over: a tape
        // picked from the shelf starts playing by itself, so play is done.
        .onChange(of: tour.step) { _, _ in catchUpTour() }
        .onAppear { catchUpTour() }
    }

    /// An album or playlist is in the deck, so there is a list of its songs.
    private var hasSongList: Bool {
        switch model.currentTape {
        case .album?, .playlist?: return model.hasTape
        default: return false
        }
    }

    /// Moves the tour past whatever the deck is already doing.
    private func catchUpTour() {
        switch tour.step {
        case .chooseTape where model.hasTape: tour.completed(.chooseTape)
        case .play where model.motion == .playing: tour.completed(.play)
        default: break
        }
    }

    /// On the Duo, how far down the name and the songs key move so they
    /// sit just above the window, as the song line sits just below it.
    private func headLift(_ plan: Layout, _ insets: EdgeInsets) -> CGFloat {
        guard plan.rail else { return 0 }
        // The songs key is 38 points tall and starts 9 below its offset.
        return max(0, plan.window.minY - 6 - 47 - 6 - insets.top)
    }

    /// On the Duo, how far under the window the song line starts.
    private func footGap(_ plan: Layout, _ full: CGSize) -> CGFloat { 10 }

    private var underWindowNote: String? {
        // The end of a side has its own card in the window.
        guard model.endOfSideNote == nil else { return nil }
        guard model.hasTape, model.printedLabel, !model.trackTitle.isEmpty else { return nil }
        return model.trackTitle
    }

    // MARK: Tape and casing

    /// Where everything on the deck goes, worked out from the screen.
    struct Layout {
        /// Points per millimetre of cassette.
        var scale: CGFloat
        /// The window in the casing, on screen.
        var window: CGRect
        /// The middle of the cassette, on screen.
        var cassetteCenter: CGPoint
        /// The top of the panel along the foot, at its highest point.
        var panelTop: CGFloat
        var keyHeight: CGFloat
        /// The left edge of the clear part of the case.
        var contentLeft: CGFloat
        /// The Duo's side column, if there is one.
        var rail: Bool
        var railLeading: Bool
        var railWidth: CGFloat
        /// On the Duo, the width of the solid side of the case.
        var panelWidth: CGFloat = 0
        /// On a phone, the part of the window left uncovered by the panel.
        var seen: CGRect? = nil
    }

    /// The length of the cassette the window always shows, in millimetres of
    /// its 100 mm shell: both reels and the shell out to the corner screws,
    /// from 17 mm to 89 mm along it.
    private let windowLength: CGFloat = 72
    private let windowFarEnd: CGFloat = 89
    /// How much of the cassette's 63 mm width the window shows at most,
    /// starting 2.5 mm in from the label edge: the label, the reels, and the
    /// shell down to the guide rollers. Never less than 36.5 mm.
    private let windowMaxWidth: CGFloat = 58
    private let windowMinWidth: CGFloat = 36.5
    private let windowEdgeInset: CGFloat = 2.5

    private func layout(full: CGSize, insets: EdgeInsets, phone: Bool = false) -> Layout {
        let railWidth = max(insets.leading, insets.trailing)
        let rail = railWidth >= 60
        let railLeading = rail && insets.leading > insets.trailing
        if rail {
            return railLayout(full: full, insets: insets, railWidth: railWidth, leading: railLeading, phone: phone)
        }

        // The row of keys along the foot: six keys across the width
        let rowWidth = full.width - 2 * keysMargin
        let keyWidth = (rowWidth - 5 * keyGap) / 6
        let keyHeight = min(rail ? 64 : 72, max(52, keyWidth * 1.15))
        let bottomPad = insets.bottom > 0 ? max(14, insets.bottom - 6) : 14
        let panelContent = (rail ? 0 : faderRow + 10) + keyHeight
        let panelTop = full.height - bottomPad - panelContent - 8 - panelBow

        // The clear part of the case, beside the rail if there is one
        let left = (rail && railLeading ? railWidth : insets.leading) + 14
        let right = full.width - (rail && !railLeading ? railWidth : insets.trailing) - 14
        // Room above for the name, and below for the song line (and the
        // stripes, on the case that has them)
        let top = insets.top + 58 + (skin.caseWord == nil ? 0 : 34)
        let bottom = panelTop - 48 - (skin.hasStripes ? 32 : 0)
        let roomW = max(100, right - left)
        let roomH = max(100, bottom - top)

        // As large as the height allows, but never so large that the window
        // shows less of the width than it always has
        let scale = min(roomH / windowLength, roomW / windowMinWidth)
        let width = min(roomW, windowMaxWidth * scale)
        let height = windowLength * scale
        let window = CGRect(x: (left + right) / 2 - width / 2,
                            y: top + (roomH - height) / 2,
                            width: width, height: height)
        // The cassette stands on end: its label edge is at the left of the
        // screen and its far end at the top.
        let cassetteLeft = window.minX - windowEdgeInset * scale
        let cassetteTop = window.minY - (100 - windowFarEnd) * scale
        let center = CGPoint(x: cassetteLeft + 31.5 * scale, y: cassetteTop + 50 * scale)
        return Layout(scale: scale, window: window, cassetteCenter: center,
                      panelTop: panelTop, keyHeight: keyHeight, contentLeft: left,
                      rail: rail, railLeading: railLeading, railWidth: railWidth)
    }

    /// The Duo's outer screen: the cassette as large as the screen allows,
    /// in the middle of it, with the keys in the rail at the side.
    private func railLayout(full: CGSize, insets: EdgeInsets, railWidth: CGFloat, leading: Bool,
                            phone: Bool = false) -> Layout {
        if phone {
            // The window starts near the left edge and runs on under the
            // side panel. It shows nearly the whole length of the tape, as
            // tall as the screen allows under the name and over the song.
            // The name above it and the song under it go with it, and the
            // three together sit in the middle of the screen.
            let lengthMM: CGFloat = 86
            let farMM: CGFloat = 94
            let nameBand: CGFloat = 58
            let songBand: CGFloat = 48
            let foot: CGFloat = skin.hasStripes ? 34 : 0
            // The panel's seam at its furthest in, and where its ends are
            let seam = full.width - railWidth - 4
            let windowX: CGFloat = 11 + insets.leading
            let seenWidth = seam - windowX
            let usable = full.height - insets.top - insets.bottom - foot
            let roomTall = usable - nameBand - songBand - 8
            let scale = min(seenWidth / windowMinWidth, roomTall / lengthMM)
            let height = lengthMM * scale
            let free = usable - (nameBand + height + songBand)
            let windowY = insets.top + max(0, free / 2) + nameBand
            let left = windowX - windowEdgeInset * scale
            let bottom = windowY + farMM * scale
            let window = CGRect(x: windowX, y: windowY, width: seam + 18 - windowX, height: height)
            let seen = CGRect(x: windowX, y: windowY, width: seenWidth, height: height)
            return Layout(scale: scale, window: window,
                          cassetteCenter: CGPoint(x: left + 31.5 * scale, y: bottom - 50 * scale),
                          panelTop: full.height, keyHeight: 0,
                          contentLeft: 14 + insets.leading,
                          rail: true, railLeading: false, railWidth: railWidth,
                          panelWidth: railWidth, seen: seen)
        }
        // As big as the screen allows. The cassette may run a little past
        // the edges, but never far enough to lose the label.
        let long = max(full.width, full.height)
        let short = min(full.width, full.height)
        let fit = min(long / 100, short / 63)
        let fill = max(long / 100, short / 63)
        let scale = min(fill, fit * 1.04)
        // The window shows the label strip and both reels; the guide
        // rollers and the head opening stay under the casing, by the keys.
        let left = full.width / 2 - 63 * scale / 2
        // The window is not in the middle of the cassette, so the cassette
        // sits a little low: that leaves as much case above the window, for
        // the name, as below it, for the song.
        let middle = full.height / 2 + (windowFarEnd - windowLength / 2 - 50) * scale
        let bottom = middle + 100 * scale / 2
        let window = CGRect(x: left + windowEdgeInset * scale, y: bottom - windowFarEnd * scale,
                            width: windowMinWidth * scale, height: windowLength * scale)
        let panelWidth = max(railWidth, leading ? window.minX - 6 : full.width - window.maxX - 6)
        return Layout(scale: scale, window: window,
                      cassetteCenter: CGPoint(x: full.width / 2, y: middle),
                      panelTop: full.height, keyHeight: 0,
                      contentLeft: 14 + (leading ? panelWidth : insets.leading),
                      rail: true, railLeading: leading, railWidth: railWidth,
                      panelWidth: panelWidth)
    }

    /// The cassette on end, head opening toward the keys, with the player's
    /// smoked casing over it and a window cut through the casing.
    private func tapeUnderCasing(_ plan: Layout) -> some View {
        GeometryReader { geo in
            let size = geo.size
            let scale = plan.scale
            let window = plan.window
            let opening = RoundedRectangle(cornerRadius: 20)
            ZStack {
                if model.hasTape {
                    DeckCassette()
                        .frame(width: 100 * scale, height: 63 * scale)
                        .rotationEffect(.degrees(-90))
                        // Turning the tape over: it swings round its long edge.
                        .rotation3DEffect(.degrees(model.flipAngle),
                                          axis: (x: 1, y: 0, z: 0),
                                          perspective: 0.4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        // Placed by its middle, inside a layer held to the
                        // screen's size, so the turned cassette cannot widen
                        // this layer and push the casing and its window
                        // off centre.
                        .position(plan.cassetteCenter)
                        .frame(width: size.width, height: size.height)
                } else {
                    // The empty well is left dark; the drive spindles show
                    // only through a tape. The prompt sits in the middle of
                    // the window.
                    // Pressed, the well lights up a little and the prompt
                    // sinks in, like a door giving under a thumb.
                    opening
                        .fill(RadialGradient(colors: [theme.accentColor.opacity(0.28), .clear],
                                             center: .center, startRadius: 0, endRadius: window.width * 0.7))
                        .frame(width: window.width, height: window.height)
                        .position(x: window.midX, y: window.midY)
                        .opacity(touchingWindow ? 1 : 0)
                    VStack(spacing: 6) {
                        Image(systemName: "eject.fill").font(.system(size: 24))
                        Text("NO TAPE").font(Typeface.display(16)).tracking(3)
                        Text("Tap to choose one").font(.system(size: 11))
                    }
                    .foregroundColor(Color.white.opacity(touchingWindow ? 0.95 : 0.5))
                    .scaleEffect(touchingWindow ? 0.92 : 1)
                    .position(x: window.midX, y: window.midY)
                    .animation(.easeOut(duration: 0.1), value: touchingWindow)
                }

                // The casing: smoked plastic with the window cut out of it
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: size))
                    path.addRoundedRect(in: window, cornerSize: CGSize(width: 20, height: 20))
                }
                .fill(LinearGradient(colors: skin.casing,
                                     startPoint: .topLeading, endPoint: .bottomTrailing),
                      style: FillStyle(eoFill: true))

                // Eighties stripes across the foot of the case
                if skin.hasStripes {
                    RetroStripes()
                        .frame(width: size.width, height: 30)
                        // Low on the case, clear of the song line under the window
                        .position(x: size.width / 2,
                                  // On the Duo they run along the very foot of the screen
                                  y: plan.rail ? size.height - 15 : window.maxY + 48 + 15)
                        .allowsHitTesting(false)
                }

                // The window: shadow where the casing overhangs the tape,
                // a trace of glass, and the bright cut edge of the plastic.
                Group {
                    opening.strokeBorder(Color.black.opacity(0.75), lineWidth: 8).blur(radius: 5)
                        .clipShape(opening)
                    opening.fill(LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.02), .clear],
                                                startPoint: .topLeading, endPoint: .center))
                    opening.strokeBorder(LinearGradient(colors: skin.windowEdge,
                                                        startPoint: .topLeading, endPoint: .bottomTrailing),
                                         lineWidth: 2.5)
                        .shadow(color: skin.hasStripes ? Skin.hotPink.opacity(0.8) : .clear, radius: 6)
                    // The cut has thickness: a dark inner face and a second lit lip
                    opening.strokeBorder(Color.black.opacity(0.55), lineWidth: 1.5).padding(2.5)
                    RoundedRectangle(cornerRadius: 17)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                        .padding(4)
                    opening.strokeBorder(Color.white.opacity(0.10), lineWidth: 1).padding(-6)
                }
                .frame(width: window.width, height: window.height)
                .position(x: window.midX, y: window.midY)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    /// The surface of the body: a fixed reflection and the glare that follows
    /// the phone as it moves.
    private var clearCase: some View {
        ZStack {
            LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.02), .clear],
                           startPoint: .topLeading, endPoint: .center)
            GlassShimmer()
            // No drawn edge here: the phone's own corners are the edge of
            // the player, and a drawn one never quite matches their curve.
        }
        .allowsHitTesting(false)
    }

    // MARK: Keys

    /// The volume fader, standing upright; laid on its side where it runs
    /// across the panel.
    private var fader: some View {
        VolumeFader(volume: volume, playing: model.motion == .playing,
                    tempo: model.beatsPerMinute,
                    engraving: skin.engraving, engravingEdge: skin.engravingEdge,
                    engravingEdgeOffset: skin.engravingEdgeOffset)
    }

    /// Six keys of one size in a column: play, stop, fast forward, rewind,
    /// the tape library, and settings.
    private func railKeys(height: CGFloat) -> some View {
        VStack(spacing: keyGap) {
            TransportKeys(vertical: true, keyHeight: height, bare: true, big: true,
                          spacing: keyGap, onEject: openShelf)
            TapeKey(symbol: "gearshape.fill", label: "Settings", dark: true,
                    height: height, showsLabel: false, corner: 17, symbolSize: 23,
                    onDown: {
                        model.keyClick()
                        TransportKeys.afterKeyGoesDown { showSettings = true }
                    })
        }
    }

    /// The column of keys in the Duo's rail, starting below the camera and clock.
    private func railKeyColumn(insets: EdgeInsets, leading: Bool, statusHeight: CGFloat,
                               fromFoot: Bool = false) -> some View {
        let width = max(insets.leading, insets.trailing)
        // On a phone the panel reaches further in, so the keys sit in its middle
        let keyWidth = fromFoot ? phoneKeyWidth : railKeyWidth
        let outer: CGFloat = fromFoot ? 14 : railOuterMargin
        let inner = max(0, width - keyWidth - outer)
        // The gap kept under the last key
        let foot: CGFloat = fromFoot ? (insets.bottom > 0 ? insets.bottom - 3 : 16) : insets.bottom + 4
        return GeometryReader { geo in
            let room = geo.size.height - statusHeight - foot
            // On a phone the keys take what the fader leaves, keeping room
            // for a fader of a fair height.
            let keyHeight = fromFoot
                ? min(84, max(44, (room - 150 - 5 * keyGap) / 6))
                : min(railKeyMaxHeight, max(36, (room - 5 * keyGap) / 6))
            VStack(spacing: 0) {
                if fromFoot {
                    // At the top of the column, under the clock, the volume
                    // fader stands upright; the keys run down to the foot.
                    Color.clear.frame(height: statusHeight)
                    VStack(spacing: 8) {
                        fader
                            .frame(width: 48)
                            .frame(minHeight: 80, maxHeight: 200)
                        volumeWord.fixedSize()
                    }
                    .frame(maxWidth: .infinity)
                    Spacer(minLength: 16)
                } else {
                    // Fixed size and fixed distance from the foot, shared
                    // with the open phone, so the keys do not move when the
                    // phone is unfolded.
                    Spacer(minLength: statusHeight)
                }
                railKeys(height: fromFoot ? keyHeight : DuoRail.keyHeight)
                if fromFoot {
                    Color.clear.frame(height: foot)
                } else {
                    Color.clear.frame(height: DuoRail.bottomGap)
                }
            }
            .frame(width: keyWidth)
            .padding(.leading, leading ? outer : inner)
            .padding(.trailing, leading ? inner : outer)
        }
        .frame(width: width)
    }

    /// The word engraved beside the fader.
    private var volumeWord: some View {
        Text("VOLUME")
            .font(Typeface.displayFixed(7.5))
            .tracking(1.6)
            .foregroundColor(skin.engraving)
            .shadow(color: skin.engravingEdge, radius: 0.3, y: skin.engravingEdgeOffset)
            .accessibilityHidden(true)
    }

    /// A solid part of the player: the panel along the foot that carries the
    /// keys, or the Duo's side column that carries the fader. Solid plastic,
    /// not see through, with a seam where it meets the clear part of the case.
    private func casePanel(seam: BowedPanel.Seam, bow wanted: CGFloat? = nil) -> some View {
        let bow = wanted ?? (seam == .top ? panelBow : 26)
        let edge = BowedPanel(bow: bow, seam: seam)
        let lit: UnitPoint = seam == .top ? .top : (seam == .leading ? .leading : .trailing)
        let lip: CGSize = switch seam {
        case .top: CGSize(width: 0, height: 1.6)
        case .leading: CGSize(width: 1.6, height: 0)
        case .trailing: CGSize(width: -1.6, height: 0)
        }
        return ZStack {
            edge.fill(LinearGradient(colors: skin.panel, startPoint: .top, endPoint: .bottom))
            edge.fill(LinearGradient(colors: [Color.white.opacity(0.07), .clear],
                                     startPoint: lit, endPoint: .center))
            PlasticGrain(strength: 0.5).clipShape(edge)
            // The seam, following the curve: a dark cut with a lit lip
            BowedPanel(bow: bow, seam: seam, edgeOnly: true)
                .stroke(Color.black.opacity(0.8), lineWidth: 2.5)
            BowedPanel(bow: bow, seam: seam, edgeOnly: true)
                .stroke(Color.white.opacity(0.30), lineWidth: 1)
                .offset(lip)
        }
        .shadow(color: .black.opacity(0.65), radius: 7, x: -lip.width * 2, y: -lip.height * 2)
    }
}

/// Five bands of colour, the stripe that ran across everything in the 1980s.
struct RetroStripes: View {
    private let bands: [Color] = [
        Color(red: 0.11, green: 0.60, blue: 0.67),
        Color(red: 0.96, green: 0.91, blue: 0.76),
        Color(red: 0.95, green: 0.62, blue: 0.02),
        Color(red: 0.89, green: 0.34, blue: 0.18),
        Color(red: 0.65, green: 0.15, blue: 0.22)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                band
            }
        }
        .accessibilityHidden(true)
    }
}

/// The name of the app, as lettering.
struct Wordmark: View {
    var size: CGFloat = 22

    var body: some View {
        Text("Casseti")
            .font(Typeface.displayFixed(size))
            .tracking(size * 0.02)
    }
}

/// A solid part of the case. Its inner edge is a long shallow curve that
/// bows toward the tape in the middle and falls back at the ends.
struct BowedPanel: Shape {
    /// Which side of the panel meets the clear part of the case.
    enum Seam { case top, leading, trailing }

    /// How far the ends of the edge sit back from its furthest point.
    var bow: CGFloat
    var seam: Seam
    /// Just the curved edge, for drawing the seam.
    var edgeOnly = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // A quadratic curve passes a quarter of the way to its control
        // point from the chord, so the control sits a full bow beyond the rect.
        switch seam {
        case .top:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + bow))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + bow),
                              control: CGPoint(x: rect.midX, y: rect.minY - bow))
            if !edgeOnly {
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.closeSubpath()
            }
        case .leading, .trailing:
            let onLeading = seam == .leading
            let ends = onLeading ? rect.minX + bow : rect.maxX - bow
            let pull = onLeading ? rect.minX - bow : rect.maxX + bow
            let far = onLeading ? rect.maxX : rect.minX
            path.move(to: CGPoint(x: ends, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: ends, y: rect.maxY),
                              control: CGPoint(x: pull, y: rect.midY))
            if !edgeOnly {
                path.addLine(to: CGPoint(x: far, y: rect.maxY))
                path.addLine(to: CGPoint(x: far, y: rect.minY))
                path.closeSubpath()
            }
        }
        return path
    }
}

/// The cassette that is in the deck, drawn from the player's state.
struct DeckCassette: View {
    @EnvironmentObject private var model: PlayerModel
    /// The whole cassette is on show, not a part of it through a window.
    var whole = false

    var body: some View {
        CassetteView(title: model.tapeTitle,
                     // A printed label carries the album's artist; a handwritten
                     // one has room for whatever is playing.
                     subtitle: model.printedLabel ? model.tapeSubtitle : model.trackLine,
                     progress: model.progress,
                     // The reels race while the deck chews the tape or
                     // it is wound back in
                     motion: model.tapeChurn == .eating ? .fastForward
                         : model.tapeChurn == .winding ? .rewind : model.motion,
                     side: model.sideLetter,
                     printed: model.printedLabel,
                     tint: model.labelColor.map { Color(cgColor: $0) },
                     printColor: model.printColor.map { Color(cgColor: $0) },
                     onSpindles: true,
                     eaten: model.tapeEaten,
                     wholeLabel: whole)
    }
}

/// The transport keys, in a column for the closed phone or a row for the open
/// one. Stop holds the tape where it is, so pressing play carries on from there.
struct TransportKeys: View {
    @EnvironmentObject private var model: PlayerModel
    var vertical: Bool
    var keyHeight: CGFloat = 62
    /// Without the tray behind the keys, for places that supply their own.
    var bare = false
    /// Large rounded keys, with play and stop as a pair of latching keys.
    var big = false
    var spacing: CGFloat = 6
    /// True where eject should take the tape out; false where it only opens
    /// the shelf to pick another.
    var ejectRemovesTape = false
    /// If set, a settings key is added at the end.
    var onSettings: (() -> Void)?
    var onEject: () -> Void = {}

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: spacing)) : AnyLayout(HStackLayout(spacing: spacing))
        let corner: CGFloat = big ? 17 : 7
        let symbol: CGFloat = big ? 23 : 17
        let labels = !vertical && !big
        layout {
            if big {
                // Play and stop work as a pair: pressing one in lets the
                // other out, so one of them is always down while a tape is in.
                TapeKey(symbol: "play.fill", label: "Play",
                        accent: true, latched: model.motion == .playing,
                        height: keyHeight, showsLabel: false, corner: corner, symbolSize: symbol,
                        onDown: { model.playKey() })
                TapeKey(symbol: "stop.fill", label: "Stop",
                        latched: model.hasTape && (model.motion == .paused || model.motion == .stopped),
                        height: keyHeight, showsLabel: false, corner: corner, symbolSize: symbol,
                        onDown: { model.stopKey() })
            } else {
                TapeKey(symbol: "play.fill", label: "PLAY", accent: true, latched: model.motion == .playing,
                        height: keyHeight, showsLabel: labels, onDown: { model.playKey() })
                TapeKey(symbol: "pause.fill", label: "PAUSE", latched: model.motion == .paused,
                        height: keyHeight, showsLabel: labels, onDown: { model.pauseKey() })
            }
            // Rewind sits before fast forward, as back comes before on
            TapeKey(symbol: "backward.fill", label: "REW", latched: model.motion == .rewind,
                    height: keyHeight, showsLabel: labels, corner: corner, symbolSize: symbol,
                    onDown: { model.seekKeyDown(forward: false) },
                    onUp: { model.seekKeyUp(forward: false) })
            TapeKey(symbol: "forward.fill", label: "FF", latched: model.motion == .fastForward,
                    height: keyHeight, showsLabel: labels, corner: corner, symbolSize: symbol,
                    onDown: { model.seekKeyDown(forward: true) },
                    onUp: { model.seekKeyUp(forward: true) })
            // On the closed phone this key opens the tape library; where it
            // takes the tape out, it is an eject key.
            // The two-note mark is the one Apple Music itself goes by.
            TapeKey(symbol: ejectRemovesTape ? "eject.fill" : BeamedNotes.symbol,
                    label: ejectRemovesTape ? "EJECT" : "Music library",
                    height: keyHeight, showsLabel: labels, corner: corner, symbolSize: symbol,
                    onDown: {
                        model.ejectKey(removeTape: ejectRemovesTape)
                        Self.afterKeyGoesDown(onEject)
                    })
            if let onSettings {
                TapeKey(symbol: "gearshape.fill", label: "Settings", dark: true,
                        height: keyHeight, showsLabel: labels, corner: corner, symbolSize: symbol,
                        onDown: {
                            model.keyClick()
                            Self.afterKeyGoesDown(onSettings)
                        })
            }
        }
        .padding(bare ? 0 : 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(bare ? 0 : 0.28)))
    }

    /// Runs what a key opens a moment after the press, so the key is seen
    /// going down before a page slides up over it.
    static func afterKeyGoesDown(_ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.17, execute: action)
    }

    static func clock(_ time: TimeInterval) -> String {
        let total = Int(max(time, 0))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// One mechanical key, moulded in solid plastic. It reports press and release separately so rewind and
/// fast forward can tell a tap from a hold, and stays down while latched.
struct TapeKey: View {
    var symbol: String
    var label: String
    var accent = false
    /// A black key, for one that should sit apart from the transport keys.
    var dark = false
    var latched = false
    var height: CGFloat = 62
    var showsLabel = true
    var corner: CGFloat = 7
    var symbolSize: CGFloat = 17
    var onDown: () -> Void = {}
    var onUp: () -> Void = {}

    @State private var pressed = false
    /// True only while a finger is on the key. Unlike `pressed`, the system
    /// puts this back by itself when a touch is taken away without ending,
    /// as when a page slides up over the key.
    @GestureState private var touching = false
    @AppStorage(Prefs.skin) private var skinName = Skin.standard.rawValue
    /// The tour lights up the key it wants pressed.
    @Environment(\.tourKey) private var tourKey

    private var skin: Skin { Skin(rawValue: skinName) ?? Skin.standard }

    /// How far the key moves when pressed.
    private let travel: CGFloat = 8

    var body: some View {
        let down = pressed || latched
        VStack(spacing: 4) {
            if symbol == BeamedNotes.symbol {
                // The library key: a pair of joined notes, drawn here
                BeamedNotes().frame(width: symbolSize * 1.05, height: symbolSize * 1.1)
            } else {
                Image(systemName: symbol).font(.system(size: symbolSize, weight: .bold))
            }
            if showsLabel, height >= 50 {
                Text(label).font(Typeface.displayFixed(8)).lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        // The symbol is engraved and filled with paint, so it has a thin
        // edge of shadow or light where the cut catches it. Pressed in, the
        // paint goes black, except on the play key, which lights up from
        // behind while the tape plays.
        .foregroundColor(symbolColor(down: down))
        .shadow(color: Color.black.opacity(accent ? 0.45 : 0.75), radius: 0.4, y: -0.8)
        .shadow(color: down && accent ? Self.lit : .clear, radius: 5)
        .shadow(color: down && accent ? Self.lit.opacity(0.7) : .clear, radius: 12)
        .scaleEffect(down ? 0.92 : 1)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        // The face is shorter than the key, leaving its side showing below.
        .frame(height: height - travel)
        .background(KeyCap(corner: corner, colors: keyColors(down: down), sunk: down))
        // Pressed, the face sinks until the side is hidden.
        .offset(y: down ? travel : 0)
        .frame(height: height, alignment: .top)
        .background(
            // The side of the key
            RoundedRectangle(cornerRadius: corner)
                .fill(LinearGradient(colors: wallColors, startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(down ? 0.25 : 0.6), radius: down ? 1.5 : 4, y: down ? 1 : 4)
        )
        .background(
            // The well the key sits in, cut into the panel
            RoundedRectangle(cornerRadius: corner + 3)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: corner + 3)
                        .strokeBorder(LinearGradient(colors: [Color.black.opacity(0.9), Color.white.opacity(0.16)],
                                                     startPoint: .top, endPoint: .bottom),
                                      lineWidth: 1)
                )
                .padding(-3)
        )
        .overlay {
            if tourKey == symbol { TourPulse(corner: corner + 3) }
        }
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
                .updating($touching) { _, touching, _ in touching = true }
                .onEnded { _ in
                    pressed = false
                    if !latched { Haptics.keyUp() }
                    onUp()
                }
        )
        // A touch that is cancelled never ends, so the key would stay down
        // (and a wind would never stop). Let it up when the finger is gone.
        .onChange(of: touching) { _, touching in
            if !touching, pressed {
                pressed = false
                onUp()
            }
        }
        .onDisappear { pressed = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
        .accessibilityAddTraits(latched ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            onDown()
            onUp()
        }
    }

    private var wallColors: [Color] {
        if accent { return skin.accentWall }
        if dark { return [Color(white: 0.05), Color(white: 0.02)] }
        return [Color(white: 0.17), Color(white: 0.09)]
    }

    /// The short legends on the keys, said in full.
    private var spokenLabel: String {
        switch label {
        case "FF": return "Fast forward"
        case "REW": return "Rewind"
        default: return label.count > 1 && label == label.uppercased() ? label.capitalized : label
        }
    }

    /// The glow of the lamp behind the play key while it is in.
    private static let lit = Color(red: 1.0, green: 0.88, blue: 0.42)

    private func symbolColor(down: Bool) -> Color {
        guard down else { return Color(white: 0.96) }
        if accent { return Self.lit }
        // Black paint on a black key would vanish, so it only dims there.
        return dark ? Color(white: 0.38) : Color(white: 0.04)
    }

    private func keyColors(down: Bool) -> [Color] {
        if accent {
            // The play key: orange as on the decks this is modelled on, or
            // hot pink on the neon skin
            return down ? skin.accentDown : skin.accentUp
        }
        if dark {
            return down
                ? [Color(white: 0.06), Color(white: 0.03)]
                : [Color(white: 0.15), Color(white: 0.08)]
        }
        // Dark grey plastic, like the panel the keys sit in
        return down
            ? [Color(white: 0.22), Color(white: 0.16)]
            : [Color(white: 0.41), Color(white: 0.28)]
    }
}

/// The top face of a key: moulded plastic with a fine grain, a slightly
/// dished middle, and an edge that is lit from above.
private struct KeyCap: View {
    let corner: CGFloat
    let colors: [Color]
    /// Pressed in: the face sits down inside its well, so the well's upper
    /// wall throws a shadow across it and its top edge is no longer lit.
    var sunk = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner)
        ZStack {
            shape.fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            PlasticGrain().clipShape(shape)
            // The dish: shaded at the top of the hollow, lit at the bottom
            RoundedRectangle(cornerRadius: max(2, corner - 5))
                .fill(LinearGradient(colors: [Color.black.opacity(0.14), .clear, Color.white.opacity(0.09)],
                                     startPoint: .top, endPoint: .bottom))
                .padding(5)
            shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(sunk ? 0.10 : 0.62),
                                                       Color.white.opacity(0.08),
                                                       Color.black.opacity(0.32)],
                                              startPoint: .top, endPoint: .bottom),
                               lineWidth: 1.2)
            if sunk {
                shape.fill(LinearGradient(stops: [
                    .init(color: Color.black.opacity(0.72), location: 0),
                    .init(color: Color.black.opacity(0.30), location: 0.25),
                    .init(color: .clear, location: 0.55)
                ], startPoint: .top, endPoint: .bottom))
                // The sides of the well shade the edges too
                shape.strokeBorder(Color.black.opacity(0.35), lineWidth: 3).blur(radius: 2).clipShape(shape)
            }
        }
    }
}

/// Fine moulded grain, laid over a plastic surface: faint light and dark
/// speckles cut from the grain texture. It is drawn as plain, nearly clear
/// white and black, not with a blend mode, so it reads the same wherever it
/// is used and never greys the colour beneath.
struct PlasticGrain: View {
    var strength = 0.45

    var body: some View {
        ZStack {
            Color.white.opacity(0.20 * strength)
                .mask(tile.luminanceToAlpha())
            Color.black.opacity(0.34 * strength)
                .mask(tile.colorInvert().luminanceToAlpha())
        }
        .allowsHitTesting(false)
    }

    private var tile: some View {
        Image("Grain").resizable(resizingMode: .tile)
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

/// The app's ordinary button, eighties style: hot pink with a hard yellow
/// shadow that it sinks onto when pressed.
struct PlainKeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PlainKey(label: configuration.label, down: configuration.isPressed)
    }

    /// Drawn in the chosen skin's colours: its accent for the face and its
    /// second colour for the hard shadow.
    private struct PlainKey<Label: View>: View {
        let label: Label
        let down: Bool
        @Environment(\.playerTheme) private var theme

        var body: some View {
            label
                .font(Typeface.display(16))
                .foregroundColor(theme.accentInkColor)
                .background(RoundedRectangle(cornerRadius: 10).fill(theme.accentColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(theme.accentInkColor, lineWidth: 1.5)
                )
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.secondaryColor)
                        .offset(x: down ? 0 : 4, y: down ? 0 : 4)
                )
                .offset(x: down ? 4 : 0, y: down ? 4 : 0)
                .animation(.easeOut(duration: 0.08), value: down)
        }
    }
}

/// Lettering drawn as a white outline, as if printed on painted metal. The
/// outline is the word in white nudged each way, with the word in the case
/// colour laid over the middle.
struct OutlinedWord: View {
    let text: String
    let fill: Color

    private var word: some View {
        Text(text)
            .font(Typeface.displayFixed(23))
            .tracking(1.5)
    }

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { step in
                let angle = Double(step) * .pi / 4
                word.foregroundColor(.white.opacity(0.9))
                    .offset(x: CGFloat(cos(angle)) * 1.1, y: CGFloat(sin(angle)) * 1.1)
            }
            word.foregroundColor(fill)
        }
    }
}

/// Shown over the tape when a side has run out: which side ended, and a key
/// to turn the tape over (or word that the other side is blank).
struct EndOfSideCard: View {
    @EnvironmentObject private var model: PlayerModel
    @Environment(\.playerTheme) private var theme

    var body: some View {
        let other = model.sideLetter == "A" ? "B" : "A"
        VStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.accentColor)
            Text("End of side \(model.sideLetter)")
                .font(Typeface.display(20))
                .foregroundColor(.white)
            if model.canFlip {
                Text("Turn the tape over to keep listening.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                Button {
                    model.flipTape()
                } label: {
                    Text("Flip to side \(other)")
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                }
                .buttonStyle(PlainKeyButtonStyle())
                .padding(.top, 2)
            } else {
                Text("The other side is blank. Rewind, or choose another tape.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.84))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.accentColor.opacity(0.7), lineWidth: 1.5))
        )
        .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
    }
}

/// A small reel hub that turns, to show the tape being wound.
struct WindingReel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let turn = timeline.date.timeIntervalSinceReferenceDate * -540
            ZStack {
                Circle().strokeBorder(lineWidth: 3)
                ForEach(0..<3, id: \.self) { spoke in
                    Capsule().frame(width: 3.5, height: 11).offset(y: -7.5)
                        .rotationEffect(.degrees(Double(spoke) * 120))
                }
                Circle().frame(width: 6, height: 6)
            }
            .rotationEffect(.degrees(reduceMotion ? 0 : turn))
        }
        .accessibilityLabel("Winding")
    }
}

/// Shown in the tape window when the deck has chewed the tape.
struct TapeEatenCard: View {
    @EnvironmentObject private var model: PlayerModel
    @Environment(\.playerTheme) private var theme

    var body: some View {
        let winding = model.tapeChurn == .winding
        VStack(spacing: 10) {
            if winding {
                // A reel turning while the tape is drawn back in
                WindingReel()
                    .frame(width: 34, height: 34)
                    .foregroundColor(theme.accentColor)
                Text("Winding it back in")
                    .font(Typeface.display(20))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.accentColor)
                Text("The deck ate your tape")
                    .font(Typeface.display(20))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("It happens to the best decks. Wind it back in and carry on.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                Button {
                    model.windTapeBack()
                } label: {
                    Text("Wind it back in")
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                }
                .buttonStyle(PlainKeyButtonStyle())
                .padding(.top, 2)
            }
        }
        .animation(.easeOut(duration: 0.15), value: winding)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.84))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.accentColor.opacity(0.7), lineWidth: 1.5))
        )
        .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
    }
}

/// Two notes joined by a beam: the mark on the key that opens the library.
/// It takes the colour of the text around it.
struct BeamedNotes: View {
    /// The name the library key goes by where keys are told apart by symbol.
    nonisolated static let symbol = "casseti.notes"

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let head = CGSize(width: w * 0.36, height: h * 0.25)
            let stem = w * 0.085
            ZStack {
                // Stems and the beam across their tops
                Path { path in
                    path.addRect(CGRect(x: w * 0.36 - stem, y: h * 0.17, width: stem, height: h * 0.66))
                    path.addRect(CGRect(x: w * 0.98 - stem, y: h * 0.05, width: stem, height: h * 0.66))
                    path.move(to: CGPoint(x: w * 0.36 - stem, y: h * 0.14))
                    path.addLine(to: CGPoint(x: w * 0.98, y: h * 0.02))
                    path.addLine(to: CGPoint(x: w * 0.98, y: h * 0.20))
                    path.addLine(to: CGPoint(x: w * 0.36 - stem, y: h * 0.32))
                    path.closeSubpath()
                }
                // Heads, tilted as on a stave
                Ellipse()
                    .frame(width: head.width, height: head.height)
                    .rotationEffect(.degrees(-22))
                    .position(x: w * 0.19, y: h * 0.85)
                Ellipse()
                    .frame(width: head.width, height: head.height)
                    .rotationEffect(.degrees(-22))
                    .position(x: w * 0.81, y: h * 0.73)
            }
        }
        .accessibilityHidden(true)
    }
}
