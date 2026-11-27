import SwiftUI
import MusicKit
import UIKit

/// The tape shelf: your Apple Music library browsed the
/// way the Music app does it (playlists, artists, albums, songs), and a
/// search of Apple Music or your library. Albums and playlists sit on the
/// shelf as cassette spines.
struct ShelfView: View {
    @EnvironmentObject private var model: PlayerModel
    /// False on the open phone, where the tape waits for the phone to close.
    var playOnPick = true
    var onPick: () -> Void
    /// On the open phone: start on the songs of the tape that is in the deck.
    var showsCurrentTape = false
    /// Set where the shelf covers the screen, so it has a key to close it.
    var onClose: (() -> Void)?

    @State private var term = ""
    @State private var scope = SearchScope.catalog
    @State private var findings = SearchFindings()
    @State private var searching = false
    /// Said above the results when Apple Music could not be searched.
    @State private var searchNote: String?
    /// Where the results on show came from, which is the library when a
    /// search of Apple Music fell back to it.
    @State private var resultsScope = SearchScope.catalog
    @State private var recent: [Album] = []
    @State private var showSettings = false
    @State private var showCurrent = false
    /// The tape whose songs were last opened without being asked.
    @State private var openedTape: String?
    @Environment(\.playerTheme) private var theme

    var body: some View {
        NavigationStack {
            Group {
                switch model.authStatus {
                case .authorized:
                    shelf
                case .notDetermined:
                    prompt(text: "Casseti needs access to Apple Music to load your tapes.",
                           button: "Connect Apple Music") {
                        Task { await model.requestAccess() }
                    }
                default:
                    prompt(text: "Apple Music access is turned off for Casseti. Turn on Media & Apple Music in Settings.",
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
        .errorAlert(model, when: !showSettings)
        .environment(\.pickTape, PickTape { tape, track in
            // A song that was tapped plays; a whole tape on the open phone
            // waits for play or for the phone to be closed.
            model.put(tape, startingAt: track, autoPlay: playOnPick || track != nil)
            onPick()
        })
    }

    #if DEBUG
    /// Everything that can be learned about why a search failed, for the
    /// note shown in builds run from Xcode.
    private static func diagnosis(of error: Error) async -> String {
        let plain = error as NSError
        var parts = ["\(type(of: error)).\(String(describing: error).prefix(90))", "\(plain.domain) \(plain.code)"]
        if let under = plain.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("under: \(under.domain) \(under.code) \(under.localizedDescription)")
        }
        do {
            _ = try await MusicDataRequest.tokenProvider.developerToken(options: .ignoreCache)
            parts.append("app token ok")
        } catch {
            let token = error as NSError
            parts.append("app token failed: \(type(of: error)).\(error) \(token.domain) \(token.code)")
        }
        if let subscription = try? await MusicSubscription.current {
            parts.append("catalog play \(subscription.canPlayCatalogContent)")
        } else {
            parts.append("subscription unknown")
        }
        let country = (try? await MusicDataRequest.currentCountryCode) ?? "??"
        parts.append("country \(country)")
        parts.append(await SearchFindings.probe("/v1/catalog/\(country)/search?term=love&types=songs&limit=1"))
        parts.append(await SearchFindings.probe("/v1/storefronts/\(country)"))
        parts.append(await SearchFindings.probe("/v1/me/storefront"))
        parts.append(await SearchFindings.probe("/v1/catalog/\(country)/charts?types=songs&limit=1"))
        return parts.joined(separator: " | ")
    }
    #endif

    private var isSearching: Bool { !term.trimmingCharacters(in: .whitespaces).isEmpty }

    private var shelf: some View {
        List {
            if isSearching {
                if let searchNote {
                    Label(searchNote, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                }
                if findings.isEmpty {
                    Text(searching ? "Searching…" : "No results.")
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                }
                SearchResultsSections(findings: findings, scope: resultsScope)
            } else {
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
                searchNote = nil
                return
            }
            searching = true
            // Wait for a pause in typing before searching.
            do { try await Task.sleep(nanoseconds: 400_000_000) } catch { return }
            do {
                var found: SearchFindings
                do {
                    found = try await SearchFindings.look(for: wanted, in: scope)
                } catch where scope == .catalog && !Task.isCancelled {
                    // Apple Music needs a token for the app, and a failed
                    // try at one is remembered. Ask for a fresh one and
                    // search once more before giving up.
                    _ = try? await MusicDataRequest.tokenProvider.developerToken(options: .ignoreCache)
                    found = try await SearchFindings.look(for: wanted, in: scope)
                }
                guard !Task.isCancelled else { return }
                findings = found
                resultsScope = scope
                searchNote = nil
            } catch {
                if !Task.isCancelled {
                    // Apple Music could not be searched. Say so above the
                    // results, not in an alert over every letter typed, and
                    // show what the library has under the same words.
                    var note = await model.explain(error, doing: scope == .catalog
                                                   ? "Apple Music could not be searched."
                                                   : "Your library could not be searched.")
                    #if DEBUG
                    note += " [\(await Self.diagnosis(of: error))]"
                    #endif
                    var fallback = SearchFindings()
                    if scope == .catalog, let mine = try? await SearchFindings.look(for: wanted, in: .library) {
                        fallback = mine
                        if !mine.isEmpty { note += " These are from your library." }
                    }
                    guard !Task.isCancelled else { return }
                    findings = fallback
                    resultsScope = .library
                    searchNote = note
                }
            }
            searching = false
        }
        .task { await loadRecent() }
        .refreshable {
            await loadRecent()
            await model.loadLibrary()
        }
        // On the open phone, the tape in the deck is opened to its songs.
        .navigationDestination(isPresented: $showCurrent) {
            if let tape = model.currentTape {
                CollectionDetail(tape: tape)
            }
        }
        .onAppear { openCurrentTape() }
        .onChange(of: model.currentTape?.id) { _, _ in openCurrentTape() }
    }

    /// Goes to the songs of the album or playlist that is in the deck.
    private func openCurrentTape() {
        guard showsCurrentTape else { return }
        guard let tape = model.currentTape else {
            openedTape = nil
            return
        }
        // Once for each tape. Going back to the shelf must stay on the shelf,
        // and the shelf coming back on screen is not a reason to leave it.
        guard tape.id != openedTape else { return }
        openedTape = tape.id
        switch tape {
        case .album, .playlist:
            // Close and reopen so a different tape replaces the last page.
            showCurrent = false
            DispatchQueue.main.async { showCurrent = true }
        default:
            break
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

/// The songs of the tape that is in the deck, as a page of its own: for the
/// closed phone, where the shelf is not on screen. A song that is tapped
/// plays, and the page closes.
struct CurrentTapeView: View {
    @EnvironmentObject private var model: PlayerModel
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let tape = model.currentTape {
                    CollectionDetail(tape: tape)
                } else {
                    Text("There is no tape in the deck.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ShelfBackground())
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .errorAlert(model)
        .environment(\.pickTape, PickTape { tape, track in
            model.put(tape, startingAt: track, autoPlay: true)
            onClose()
        })
    }
}

