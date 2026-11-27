import SwiftUI

@main
struct TapeDeckApp: App {
    @StateObject private var model = PlayerModel()
    @StateObject private var tour = Tour()

    init() {
        Typeface.styleNavigationBars()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .environmentObject(tour)
                .preferredColorScheme(.dark)
        }
    }
}

/// Picks the layout from the space the app actually has, so it follows the
/// phone as it folds and unfolds.
///  - Closed (cover screen, or any ordinary phone): the outside of the player.
///  - Open (a large, wide screen): the tape shelf on the left and the chosen
///    tape on the right. Closing the phone starts it playing.
struct ContentView: View {
    @EnvironmentObject private var model: PlayerModel
    @EnvironmentObject private var tour: Tour
    @State private var showShelf = false
    @AppStorage(Prefs.introSeen) private var introSeen = false
    @AppStorage(Prefs.skin) private var skinName = Skin.standard.rawValue
    @AppStorage(Prefs.player) private var player = "tape"
    @Environment(\.horizontalSizeClass) private var horizontalSize
    @Environment(\.verticalSizeClass) private var verticalSize

    var body: some View {
        GeometryReader { geo in
            // The Duo's inner display is regular in both directions (reported
            // as 669 x 951 or 626 x 890 points); its outer one is compact.
            let open = (horizontalSize == .regular && verticalSize == .regular)
                || (geo.size.width >= 600 && geo.size.height >= 500)
            Group {
                if open {
                    HStack(spacing: 0) {
                        ShelfView(playOnPick: false, onPick: {})
                            .frame(width: geo.size.width * 0.5)
                        OpenTrayView()
                    }
                } else if Skin.includesClickWheel, Skin(rawValue: skinName)?.isWheel == true {
                    // Personal builds only: the click wheel player.
                    MenuPlayerView(jog: false)
                } else if player == "mp3" {
                    // The MP3 player has its own menus for choosing music.
                    MenuPlayerView(jog: true)
                } else {
                    DeckView(openShelf: { showShelf = true })
                        .fullScreenCover(isPresented: $showShelf) {
                            ShelfView(onPick: { showShelf = false }, onClose: { showShelf = false })
                        }
                }
            }
            .onChange(of: open) { wasOpen, isOpen in
                if wasOpen, !isOpen { model.lidClosed() }
            }
        }
        .environment(\.playerTheme, Theme.current(player: player, skinName: skinName).skin.theme)
        // The introduction, the first time the app is opened
        .fullScreenCover(isPresented: introShown) {
            OnboardingView(done: {
                introSeen = true
                // Then try the keys for real, on the deck
                if player == "tape" { tour.start(hasTape: model.hasTape) }
            })
        }
        .alert("Cassety", isPresented: errorShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var introShown: Binding<Bool> {
        Binding(get: { !introSeen }, set: { if !$0 { introSeen = true } })
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } })
    }
}
