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
///  - Narrow (folded, cover screen): the whole screen is the player.
///  - Wide (unfolded): the player on the left, the tape shelf on the right.
struct ContentView: View {
    @EnvironmentObject private var model: PlayerModel
    @State private var showShelf = false

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= 640 {
                HStack(spacing: 0) {
                    DeckView(showShelfButton: false, openShelf: {})
                        .frame(width: geo.size.width * 0.54)
                    ShelfView(onPick: {})
                }
            } else {
                DeckView(showShelfButton: true, openShelf: { showShelf = true })
                    .sheet(isPresented: $showShelf) {
                        ShelfView(onPick: { showShelf = false })
                    }
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
