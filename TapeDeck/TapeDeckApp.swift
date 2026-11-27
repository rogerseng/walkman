import SwiftUI

@main
struct TapeDeckApp: App {
    @StateObject private var model = PlayerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
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
    @State private var showShelf = false
    @AppStorage(Prefs.introSeen) private var introSeen = false
    @AppStorage(Prefs.skin) private var skinName = Skin.smoke.rawValue
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
                    // The click-wheel skins have their own menus for choosing music.
                    WheelPlayerView()
                } else {
                    DeckView(openShelf: { showShelf = true })
                        .sheet(isPresented: $showShelf) {
                            ShelfView(onPick: { showShelf = false })
                        }
                }
            }
            .onChange(of: open) { wasOpen, isOpen in
                if wasOpen, !isOpen { model.lidClosed() }
            }
        }
        // The introduction, the first time the app is opened
        .fullScreenCover(isPresented: introShown) {
            OnboardingView(done: { introSeen = true })
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
