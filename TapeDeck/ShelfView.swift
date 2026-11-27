import SwiftUI
import MusicKit
import UIKit

/// The tape shelf: your mixtapes, then your Apple Music library browsed the
/// way the Music app does it (playlists, artists, albums, songs), and a
/// search of Apple Music or your library. Albums and playlists sit on the
/// shelf as cassette spines.
struct ShelfView: View {
    @EnvironmentObject private var model: PlayerModel
    /// False on the open phone, where the tape waits for the phone to close.
    var playOnPick = true
    var onPick: () -> Void
    /// Set where the shelf covers the screen, so it has a key to close it.
    var onClose: (() -> Void)?

    @State private var term = ""
    @State private var scope = SearchScope.catalog
    @State private var findings = SearchFindings()
    @State private var searching = false
    @State private var recent: [Album] = []
    /// The mixtape being recorded or edited, if any.
    @State private var editing: Mixtape?
    /// The mixtape waiting for a yes before it is deleted.
    @State private var deleting: Mixtape?
    @State private var showSettings = false
    @Environment(\.playerTheme) private var theme

    var body: some View {
        NavigationStack {
            Group {
                switch model.authStatus {
                case .authorized:
                    shelf
                case .notDetermined:
                    prompt(text: "Cassety needs access to Apple Music to load your tapes.",
                           button: "Connect Apple Music") {
                        Task { await model.requestAccess() }
                    }
                default:
                    prompt(text: "Apple Music access is turned off for Cassety. Turn on Media & Apple Music in Settings.",
                           button: "Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .navigationTitle("Tape Shelf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings and themes")
                }
            }
            .fullScreenCover(isPresented: $showSettings) {
                SettingsView()
            }
            .background(ShelfBackground())
        }
        .errorAlert(model, when: editing == nil && !showSettings)
        .environment(\.pickTape, PickTape { tape, track in
            model.insert(tape, autoPlay: playOnPick, startingAt: track)
            onPick()
        })
    }

    private var deletingShown: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    private var isSearching: Bool { !term.trimmingCharacters(in: .whitespaces).isEmpty }

    private var shelf: some View {
        List {
            if isSearching {
                if findings.isEmpty {
                    Text(searching ? "Searching…" : "No results.")
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                }
                SearchResultsSections(findings: findings, scope: scope)
            } else {
                mixtapes
                Section {
                    ForEach(LibraryCategory.allCases) { category in
                        CategoryRow(category: category)
                    }
                } header: {
                    ShelfStyle.header("Library")
                }
                if !recent.isEmpty {
                    Section {
                        ForEach(recent) { album in
                            CollectionLink(tape: .album(album)).shelfRow()
                        }
                    } header: {
                        ShelfStyle.header("Recently Added")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .searchable(text: $term, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: scope == .catalog ? "Search Apple Music" : "Search your library")
        .searchScopes($scope, activation: .onSearchPresentation) {
            ForEach(SearchScope.allCases) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .task(id: "\(scope.rawValue)|\(term)") {
            let wanted = term.trimmingCharacters(in: .whitespaces)
            guard !wanted.isEmpty else {
                findings = SearchFindings()
                return
            }
            searching = true
            // Wait for a pause in typing before searching.
            do { try await Task.sleep(nanoseconds: 400_000_000) } catch { return }
            do {
                let found = try await SearchFindings.look(for: wanted, in: scope)
                guard !Task.isCancelled else { return }
                findings = found
            } catch {
                if !Task.isCancelled {
                    findings = SearchFindings()
                    model.errorMessage = await model.explain(error, doing: "Search failed.")
                }
            }
            searching = false
        }
        .task { await loadRecent() }
        .refreshable {
            await loadRecent()
            await model.loadLibrary()
        }
        .fullScreenCover(item: $editing) { mixtape in
            MixtapeEditor(mixtape: mixtape)
        }
        .confirmationDialog("Delete this mixtape?", isPresented: deletingShown, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let deleting { model.delete(deleting) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("The songs stay in Apple Music. Only the tape is erased.")
        }
    }

    /// The albums most lately added to the library, as on the Music app's
    /// library page.
    private func loadRecent() async {
        var request = MusicLibraryRequest<Album>()
        request.sort(by: \.libraryAddedDate, ascending: false)
        request.limit = 12
        if let items = try? await request.response().items {
            recent = Array(items)
        }
    }

    /// Tapes you recorded yourself, with a blank at the top to start a new one.
    private var mixtapes: some View {
        Section {
            Button {
                editing = Mixtape()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 40, height: 40)
                    Text("Record a new mixtape")
                        .font(Typeface.display(16))
                    Spacer(minLength: 0)
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(theme.accentColor.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            ForEach(model.mixtapes) { mixtape in
                Button {
                    model.insert(.mixtape(mixtape), autoPlay: playOnPick)
                    onPick()
                } label: {
                    TapeSpine(tape: .mixtape(mixtape))
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions {
                    Button("Delete") { deleting = mixtape }
                        .tint(.red)
                    Button("Edit") {
                        editing = mixtape
                    }
                }
                // The same two, for anyone who does not find the swipe
                .contextMenu {
                    Button("Edit", systemImage: "pencil") { editing = mixtape }
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = mixtape }
                }
            }
        } header: {
            ShelfStyle.header("Your Mixtapes")
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

    /// The five colours of the eighties stripe
    private static let bands: [Color] = [
        Color(red: 0.11, green: 0.60, blue: 0.67), Color(red: 0.95, green: 0.79, blue: 0.30),
        Color(red: 0.95, green: 0.62, blue: 0.02), Color(red: 0.89, green: 0.34, blue: 0.18),
        Color(red: 1.0, green: 0.24, blue: 0.64)
    ]
    private let ink = Color(red: 0.07, green: 0.10, blue: 0.33)

    /// The same tape always gets the same shade of band.
    private var band: Color {
        let sum = tape.id.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 9973 }
        return Self.bands[sum % Self.bands.count]
    }

    private var length: String {
        if case .mixtape(let mixtape) = tape { return "\(mixtape.minutesPerSide * 2)" }
        return "90"
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
                    .font(Typeface.marker(18))
                    .minimumScaleFactor(0.75)
                    .foregroundColor(ink.opacity(0.92))
                Text(tape.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.38))
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            Text(length)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(Color(white: 0.45))
                .accessibilityHidden(true)
        }
        .padding(.trailing, 12)
        .frame(minHeight: 52)
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
