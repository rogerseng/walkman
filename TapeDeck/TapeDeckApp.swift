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

    var body: some View {
        GeometryReader { geo in
            let open = geo.size.width >= 640 && geo.size.height >= 500
            Group {
                if open {
                    HStack(spacing: 0) {
                        ShelfView(playOnPick: false, onPick: {})
                            .frame(width: geo.size.width * 0.5)
                        OpenTrayView()
                    }
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
        .alert("Tape trouble", isPresented: errorShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } })
    }
}
