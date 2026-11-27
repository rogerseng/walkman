import MusicKit
import SwiftUI

// Browsing Apple Music the way the Music app does: your library by
// playlists, artists, albums and songs, and a search of either Apple Music or
// your library. Whatever is picked goes into the deck as a tape.

/// What the shelf does with a pick: put the tape in, wound on to a track if
/// one was chosen, and close.
struct PickTape {
    var action: (Tape, MusicItemID?) -> Void = { _, _ in }
    func callAsFunction(_ tape: Tape, startingAt track: MusicItemID? = nil) { action(tape, track) }
}

private struct PickTapeKey: EnvironmentKey {
    static let defaultValue = PickTape()
}

extension EnvironmentValues {
    var pickTape: PickTape {
        get { self[PickTapeKey.self] }
        set { self[PickTapeKey.self] = newValue }
    }
}

/// How the shelf draws its section headings.
enum ShelfStyle {
    static func header(_ title: String) -> some View {
        ShelfHeader(title: title)
    }
}

/// A section heading on the shelf, in the theme's heading colour.
struct ShelfHeader: View {
    let title: String
    @Environment(\.playerTheme) private var theme

    var body: some View {
        Text(title.uppercased())
            .font(Typeface.display(13))
            .tracking(1.5)
            .foregroundColor(theme.secondaryColor)
    }
}

/// The theme's background, behind a whole screen.
struct ShelfBackground: View {
    @Environment(\.playerTheme) private var theme
    var body: some View { theme.backgroundColor.ignoresSafeArea() }
}

extension View {
    /// A row on the shelf: no separators, no row colour.
    func shelfRow() -> some View {
        listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    /// A list screen on the shelf.
    func shelfList(_ title: String) -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(ShelfBackground())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Library categories

/// The four ways into your library, as in the Music app.
enum LibraryCategory: String, CaseIterable, Identifiable {
    case playlists = "Playlists"
    case artists = "Artists"
    case albums = "Albums"
    case songs = "Songs"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .playlists: return "music.note.list"
        case .artists: return "music.mic"
        case .albums: return "square.stack"
        case .songs: return "music.note"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .playlists:
            PagedLibraryList(title: rawValue) {
                var request = MusicLibraryRequest<Playlist>()
                request.sort(by: \.name, ascending: true)
                return try await request.response().items
            } row: { playlist in
                CollectionLink(tape: .playlist(playlist))
            }
        case .artists:
            PagedLibraryList(title: rawValue) {
                var request = MusicLibraryRequest<Artist>()
                request.sort(by: \.name, ascending: true)
                return try await request.response().items
            } row: { artist in
                ArtistLink(artist: artist, source: .library)
            }
        case .albums:
            PagedLibraryList(title: rawValue) {
                var request = MusicLibraryRequest<Album>()
                request.sort(by: \.title, ascending: true)
                return try await request.response().items
            } row: { album in
                CollectionLink(tape: .album(album))
            }
        case .songs:
            PagedLibraryList(title: rawValue) {
                var request = MusicLibraryRequest<Song>()
                request.sort(by: \.title, ascending: true)
                return try await request.response().items
            } row: { song in
                LibrarySongRow(song: song)
            }
        }
    }
}

/// A row that opens one of the library categories.
struct CategoryRow: View {
    let category: LibraryCategory
    @Environment(\.playerTheme) private var theme

    var body: some View {
        NavigationLink {
            category.destination
        } label: {
            HStack(spacing: 14) {
                Image(systemName: category.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.accentColor)
                    .frame(width: 28)
                Text(category.rawValue)
                    .font(Typeface.display(19))
                    .foregroundColor(.white)
            }
            .frame(minHeight: 40)
        }
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(Color.white.opacity(0.12))
    }
}

/// A long list from the library, read a batch at a time as it is scrolled.
struct PagedLibraryList<Item: MusicItem, Row: View>: View {
    let title: String
    let load: () async throws -> MusicItemCollection<Item>
    @ViewBuilder let row: (Item) -> Row

    @State private var items: [Item] = []
    @State private var batch: MusicItemCollection<Item>?
    @State private var loading = true
    @State private var failure: String?

    var body: some View {
        List {
            if loading && items.isEmpty {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            } else if let failure {
                Text(failure).foregroundColor(.secondary).listRowBackground(Color.clear)
            } else if items.isEmpty {
                Text("Nothing here yet.").foregroundColor(.secondary).listRowBackground(Color.clear)
            }
            ForEach(items, id: \.id) { item in
                row(item)
                    .shelfRow()
                    .onAppear {
                        if item.id == items.last?.id { Task { await more() } }
                    }
            }
        }
        .shelfList(title)
        .task {
            guard items.isEmpty else { return }
            do {
                let first = try await load()
                batch = first
                items = Array(first)
            } catch {
                failure = "Could not read your library. \(error.localizedDescription)"
            }
            loading = false
        }
    }

    private func more() async {
        guard let current = batch, current.hasNextBatch, !loading else { return }
        loading = true
        defer { loading = false }
        if let next = try? await current.nextBatch() {
            batch = next
            items += Array(next)
        }
    }
}

// MARK: Rows

/// An album or playlist on the shelf. Opening it shows what is on it.
struct CollectionLink: View {
    let tape: Tape

    var body: some View {
        NavigationLink {
            CollectionDetail(tape: tape)
        } label: {
            TapeSpine(tape: tape)
        }
        .buttonStyle(.plain)
    }
}

/// An artist. Opening one shows their albums.
struct ArtistLink: View {
    let artist: Artist
    let source: MusicPropertySource

    var body: some View {
        NavigationLink {
            ArtistDetail(artist: artist, source: source)
        } label: {
            HStack(spacing: 12) {
                Group {
                    if let artwork = artist.artwork {
                        ArtworkImage(artwork, width: 44, height: 44)
                    } else {
                        Image(systemName: "music.mic")
                            .foregroundColor(Color(white: 0.6))
                            .frame(width: 44, height: 44)
                            .background(Color(white: 0.18))
                    }
                }
                .clipShape(Circle())
                Text(artist.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A single song. Picking it puts it in the deck as a single.
struct LibrarySongRow: View {
    let song: Song
    @Environment(\.pickTape) private var pick

    var body: some View {
        Button {
            Haptics.detent()
            pick(.song(song))
        } label: {
            HStack(spacing: 12) {
                Group {
                    if let artwork = song.artwork {
                        ArtworkImage(artwork, width: 44, height: 44)
                    } else {
                        Image(systemName: "music.note")
                            .foregroundColor(Color(white: 0.6))
                            .frame(width: 44, height: 44)
                            .background(Color(white: 0.18))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    Text(song.artistName)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Detail screens

/// An album or playlist opened up: its cover, a key to put the whole thing
/// in the deck, and the tracks. Picking a track puts the tape in wound on to
/// that track.
struct CollectionDetail: View {
    let tape: Tape
    @EnvironmentObject private var model: PlayerModel
    @Environment(\.playerTheme) private var theme
    @Environment(\.pickTape) private var pick
    @State private var tracks: [Track] = []
    @State private var loading = true
    @State private var failed = false
    /// How many of the songs are on side A; the rest are on side B.
    @State private var sideACount: Int?
    /// Set when the tape is turned over, until the list has caught up.
    @State private var followFlip = false

    private var inDeck: Bool { model.currentTape?.id == tape.id }

    var body: some View {
        ScrollViewReader { scroller in
        List {
            VStack(spacing: 10) {
                Group {
                    if let artwork = tape.artwork {
                        ArtworkImage(artwork, width: 200, height: 200)
                    } else {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50))
                            .foregroundColor(Color(white: 0.5))
                            .frame(width: 200, height: 200)
                            .background(Color(white: 0.15))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
                Text(tape.title)
                    .font(Typeface.marker(24))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text(tape.subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(theme.accentColor)
                    .multilineTextAlignment(.center)
                Button {
                    pick(tape)
                } label: {
                    Label("Put in the deck", systemImage: "play.fill")
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PlainKeyButtonStyle())
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if loading {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            } else if failed {
                Text("The songs could not be loaded. Check your connection and try again.")
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(Array(tracks.enumerated()), id: \.element.id) { number, track in
                // Where each side of the tape begins
                if let sideACount, number == 0 || number == sideACount {
                    sideBreak(number == 0 ? "A" : "B")
                }
                Button {
                    Haptics.detent()
                    pick(tape, startingAt: track.id)
                } label: {
                    let current = isPlaying(track)
                    HStack(spacing: 12) {
                        Group {
                            if current {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(theme.accentColor)
                            } else {
                                Text("\(number + 1)")
                                    .font(.system(size: 14, weight: .medium).monospacedDigit())
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .frame(width: 26, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.system(size: 15, weight: current ? .bold : .medium))
                                .foregroundColor(current ? theme.accentColor : .white)
                            if showsArtist {
                                Text(track.artistName)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                        }
                        .lineLimit(1)
                        Spacer(minLength: 0)
                        if let length = track.duration {
                            Text(TransportKeys.clock(length))
                                .font(.system(size: 13).monospacedDigit())
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isPlaying(track) ? .isSelected : [])
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Color.white.opacity(0.1))
                .id(track.id)
            }
        }
        .shelfList("")
        // The tape was turned over: go to the side it is now on, and then
        // to the song once the deck says which one is playing.
        .onChange(of: model.sideIndex) { _, side in
            guard inDeck, sideACount != nil else { return }
            followFlip = true
            withAnimation(.easeInOut(duration: 0.35)) {
                scroller.scrollTo("side-\(side == 0 ? "A" : "B")", anchor: .top)
            }
        }
        // Opened while the deck is on side B: start there, not at the top.
        .onChange(of: loading) { _, stillLoading in
            guard !stillLoading, inDeck, model.sideIndex == 1, sideACount != nil else { return }
            let playing = tracks.first(where: isPlaying)
            // After the rows are in place
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if let playing {
                    scroller.scrollTo(playing.id, anchor: .center)
                } else {
                    followFlip = true
                    scroller.scrollTo("side-B", anchor: .top)
                }
            }
        }
        .onChange(of: model.trackTitle) { _, _ in
            guard followFlip, inDeck, let playing = tracks.first(where: isPlaying) else { return }
            followFlip = false
            withAnimation(.easeInOut(duration: 0.35)) {
                scroller.scrollTo(playing.id, anchor: .center)
            }
        }
        }
        .task {
            guard tracks.isEmpty else { return }
            do {
                switch tape {
                case .album(let album):
                    tracks = try await PlayerModel.everything(in: album.with([.tracks]).tracks)
                case .playlist(let playlist):
                    tracks = try await PlayerModel.everything(in: playlist.with([.tracks]).tracks)
                default:
                    break
                }
            } catch {
                failed = true
            }
            // The same cut the deck makes when the tape goes in
            if tracks.count > 1 { sideACount = TapeSide.split(tracks)[0].entries.count }
            loading = false
        }
    }

    /// A line across the list where a side of the tape begins.
    private func sideBreak(_ letter: String) -> some View {
        let playing = inDeck && model.sideLetter == letter
        return HStack(spacing: 10) {
            Text(letter)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(lineWidth: 1.5))
            Text("SIDE \(letter)")
                .font(Typeface.display(12))
                .tracking(1.6)
            Rectangle().frame(height: 1).opacity(0.35)
        }
        .foregroundColor(playing ? theme.accentColor : theme.secondaryColor)
        .padding(.top, letter == "A" ? 4 : 14)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Side \(letter)")
        .accessibilityAddTraits(.isHeader)
        .id("side-\(letter)")
    }

    /// The song the deck is on, when this is the tape in it.
    private func isPlaying(_ track: Track) -> Bool {
        model.currentTape?.id == tape.id && model.trackTitle == track.title
            && (model.trackArtist.isEmpty || model.trackArtist == track.artistName)
    }

    /// Playlists mix artists, so each track says whose it is.
    private var showsArtist: Bool {
        if case .playlist = tape { return true }
        return false
    }
}

/// An artist opened up: their albums, newest first.
struct ArtistDetail: View {
    let artist: Artist
    let source: MusicPropertySource
    @State private var albums: [Album] = []
    @State private var loading = true
    @State private var failed = false

    var body: some View {
        List {
            if loading {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            } else if albums.isEmpty {
                Text(failed ? "The albums could not be loaded. Check your connection and try again." : "No albums found.").foregroundColor(.secondary).listRowBackground(Color.clear)
            }
            if !albums.isEmpty {
                Section {
                    ForEach(albums) { album in
                        CollectionLink(tape: .album(album)).shelfRow()
                    }
                } header: {
                    ShelfStyle.header("Albums")
                }
            }
        }
        .shelfList(artist.name)
        .task {
            guard albums.isEmpty else { return }
            do {
                let full = try await artist.with([.albums], preferredSource: source)
                albums = Array(full.albums ?? []).sorted {
                    ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast)
                }
            } catch {
                failed = true
            }
            loading = false
        }
    }
}

// MARK: Search

/// Where a search looks, as in the Music app.
enum SearchScope: String, CaseIterable, Identifiable {
    case catalog = "Apple Music"
    case library = "Your Library"
    var id: String { rawValue }
}

/// What a search found, sorted by kind.
struct SearchFindings {
    var artists: [Artist] = []
    var albums: [Album] = []
    var playlists: [Playlist] = []
    var songs: [Song] = []

    var isEmpty: Bool { artists.isEmpty && albums.isEmpty && playlists.isEmpty && songs.isEmpty }

    static func look(for term: String, in scope: SearchScope) async throws -> SearchFindings {
        switch scope {
        case .catalog:
            let types: [any MusicCatalogSearchable.Type] = [Artist.self, Album.self, Playlist.self, Song.self]
            var request = MusicCatalogSearchRequest(term: term, types: types)
            request.limit = 10
            let found = try await request.response()
            return SearchFindings(artists: Array(found.artists), albums: Array(found.albums),
                                  playlists: Array(found.playlists), songs: Array(found.songs))
        case .library:
            let types: [any MusicLibrarySearchable.Type] = [Artist.self, Album.self, Playlist.self, Song.self]
            var request = MusicLibrarySearchRequest(term: term, types: types)
            request.limit = 10
            let found = try await request.response()
            return SearchFindings(artists: Array(found.artists), albums: Array(found.albums),
                                  playlists: Array(found.playlists), songs: Array(found.songs))
        }
    }
}

/// The results of a search, in sections.
struct SearchResultsSections: View {
    let findings: SearchFindings
    let scope: SearchScope

    var body: some View {
        if !findings.artists.isEmpty {
            Section {
                ForEach(findings.artists) { artist in
                    ArtistLink(artist: artist, source: scope == .library ? .library : .catalog).shelfRow()
                }
            } header: { ShelfStyle.header("Artists") }
        }
        if !findings.albums.isEmpty {
            Section {
                ForEach(findings.albums) { album in
                    CollectionLink(tape: .album(album)).shelfRow()
                }
            } header: { ShelfStyle.header("Albums") }
        }
        if !findings.songs.isEmpty {
            Section {
                ForEach(findings.songs) { song in
                    LibrarySongRow(song: song).shelfRow()
                }
            } header: { ShelfStyle.header("Songs") }
        }
        if !findings.playlists.isEmpty {
            Section {
                ForEach(findings.playlists) { playlist in
                    CollectionLink(tape: .playlist(playlist)).shelfRow()
                }
            } header: { ShelfStyle.header("Playlists") }
        }
    }
}
