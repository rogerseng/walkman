import SwiftUI
import MusicKit
import UIKit

/// The tape shelf: your Apple Music playlists and albums as cassette spines,
/// plus a search of the Apple Music catalogue.
struct ShelfView: View {
    @EnvironmentObject private var model: PlayerModel
    /// False on the open phone, where the tape waits for the phone to close.
    var playOnPick = true
    var onPick: () -> Void

    @State private var term = ""

    var body: some View {
        NavigationStack {
            Group {
                switch model.authStatus {
                case .authorized:
                    shelf
                case .notDetermined:
                    prompt(text: "TapeDeck needs access to Apple Music to load your tapes.",
                           button: "Connect Apple Music") {
                        Task { await model.requestAccess() }
                    }
                default:
                    prompt(text: "Apple Music access is turned off for TapeDeck. Turn on Media & Apple Music in Settings.",
                           button: "Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .navigationTitle("Tape Shelf")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(white: 0.05).ignoresSafeArea())
        }
    }

    private var shelf: some View {
        List {
            if !term.trimmingCharacters(in: .whitespaces).isEmpty {
                section("Apple Music", tapes: model.searchResults, empty: "Searching…")
            } else {
                if model.isLoadingLibrary && model.libraryPlaylists.isEmpty && model.libraryAlbums.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
                }
                section("Your Playlists", tapes: model.libraryPlaylists, empty: nil)
                section("Your Albums", tapes: model.libraryAlbums, empty: nil)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .searchable(text: $term, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search Apple Music")
        .task(id: term) {
            // Wait for a pause in typing before searching.
            do { try await Task.sleep(nanoseconds: 400_000_000) } catch { return }
            await model.search(term)
        }
        .refreshable { await model.loadLibrary() }
    }

    @ViewBuilder
    private func section(_ title: String, tapes: [Tape], empty: String?) -> some View {
        if !tapes.isEmpty || empty != nil {
            Section {
                if tapes.isEmpty, let empty {
                    Text(empty).foregroundColor(.secondary).listRowBackground(Color.clear)
                }
                ForEach(tapes) { tape in
                    Button {
                        model.insert(tape, autoPlay: playOnPick)
                        onPick()
                    } label: {
                        TapeSpine(tape: tape)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
            }
        }
    }

    private func prompt(text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "music.note.list").font(.system(size: 40))
            Text(text).multilineTextAlignment(.center)
            Button(action: action) {
                Text(button).padding(.horizontal, 18).padding(.vertical, 10)
            }
            .buttonStyle(PlainKeyButtonStyle())
        }
        .foregroundColor(.white)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A cassette in its case, seen edge on as it sits on a shelf: a paper spine
/// card behind clear plastic, in greys and off-white like the rest of the app.
struct TapeSpine: View {
    let tape: Tape

    private static let bands: [Color] = [
        Color(white: 0.16), Color(white: 0.28), Color(white: 0.40), Color(white: 0.52), Color(white: 0.66)
    ]
    private let ink = Color(red: 0.07, green: 0.10, blue: 0.33)

    /// The same tape always gets the same shade of band.
    private var band: Color {
        let sum = tape.id.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 9973 }
        return Self.bands[sum % Self.bands.count]
    }

    var body: some View {
        HStack(spacing: 10) {
            band.frame(width: 8)
            Group {
                if let artwork = tape.artwork {
                    ArtworkImage(artwork, width: 40, height: 40)
                } else {
                    Image(systemName: "music.note")
                        .foregroundColor(Color(white: 0.45))
                        .frame(width: 40, height: 40)
                        .background(Color(white: 0.82))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            VStack(alignment: .leading, spacing: 0) {
                Text(tape.title)
                    .font(.custom("BradleyHandITCTT-Bold", size: 18))
                    .foregroundColor(ink.opacity(0.92))
                Text(tape.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.38))
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            Text("90")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(Color(white: 0.45))
        }
        .padding(.trailing, 12)
        .frame(height: 52)
        .background(
            LinearGradient(colors: [Color(red: 0.96, green: 0.95, blue: 0.92),
                                    Color(red: 0.89, green: 0.88, blue: 0.84)],
                           startPoint: .top, endPoint: .bottom)
        )
        // Light on the clear case over the card
        .overlay(
            LinearGradient(colors: [Color.white.opacity(0.35), .clear, Color.black.opacity(0.08)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
        .contentShape(Rectangle())
    }
}
