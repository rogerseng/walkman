import CoreGraphics
import Foundation
import MusicKit

/// What the tape transport is doing right now.
enum TapeMotion: Equatable {
    case stopped, playing, paused, fastForward, rewind
}

// MARK: Mixtapes

/// One song recorded onto a mixtape. Only what is needed to show it and to
/// find it again in the Apple Music catalogue.
struct MixSong: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var artist: String
    var duration: TimeInterval
}

/// A tape you record yourself. Like a real blank it has a fixed length, and a
/// song only goes on if there is room left on that side.
struct Mixtape: Codable, Identifiable {
    var id = UUID()
    var name = ""
    /// 30 for a C-60, 45 for a C-90.
    var minutesPerSide = 45
    var sideA: [MixSong] = []
    var sideB: [MixSong] = []
    /// When it was last changed. Decides which copy wins when two devices differ.
    var modified = Date()

    var lengthName: String { "C-\(minutesPerSide * 2)" }
    var sideLength: TimeInterval { Double(minutesPerSide) * 60 }

    func songs(onSide side: Int) -> [MixSong] { side == 0 ? sideA : sideB }

    func used(onSide side: Int) -> TimeInterval {
        songs(onSide: side).reduce(0) { $0 + $1.duration }
    }

    func remaining(onSide side: Int) -> TimeInterval {
        max(0, sideLength - used(onSide: side))
    }

    func fits(_ song: MixSong, onSide side: Int) -> Bool {
        song.duration > 0 && song.duration <= remaining(onSide: side)
    }
}

extension Mixtape {
    /// Reads a mixtape saved by any version, filling in what older ones lacked.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        minutesPerSide = try values.decodeIfPresent(Int.self, forKey: .minutesPerSide) ?? 45
        sideA = try values.decodeIfPresent([MixSong].self, forKey: .sideA) ?? []
        sideB = try values.decodeIfPresent([MixSong].self, forKey: .sideB) ?? []
        modified = try values.decodeIfPresent(Date.self, forKey: .modified) ?? .distantPast
    }
}

/// All the mixtapes, plus a note of which have been deleted and when. The
/// note is what stops a deleted tape coming back from another device.
struct MixtapeLibrary: Codable, Equatable {
    var mixtapes: [Mixtape] = []
    var deleted: [String: Date] = [:]

    static func == (a: MixtapeLibrary, b: MixtapeLibrary) -> Bool {
        a.deleted == b.deleted && a.mixtapes.map(\.id) == b.mixtapes.map(\.id)
            && a.mixtapes.map(\.modified) == b.mixtapes.map(\.modified)
    }

    mutating func put(_ mixtape: Mixtape) {
        var copy = mixtape
        copy.modified = Date()
        mixtapes.removeAll { $0.id == copy.id }
        mixtapes.insert(copy, at: 0)
        deleted[copy.id.uuidString] = nil
    }

    mutating func remove(_ mixtape: Mixtape) {
        mixtapes.removeAll { $0.id == mixtape.id }
        deleted[mixtape.id.uuidString] = Date()
    }

    /// Combines two copies of the library. For a tape both have, the one
    /// changed most recently wins; a tape deleted after its last change stays
    /// deleted. Nothing is lost just because one side had not heard of it.
    func merged(with other: MixtapeLibrary) -> MixtapeLibrary {
        var result = MixtapeLibrary()
        result.deleted = deleted.merging(other.deleted) { max($0, $1) }
        var newest: [UUID: Mixtape] = [:]
        for mixtape in mixtapes + other.mixtapes {
            if let have = newest[mixtape.id], have.modified >= mixtape.modified { continue }
            newest[mixtape.id] = mixtape
        }
        result.mixtapes = newest.values
            .filter { tape in
                guard let gone = result.deleted[tape.id.uuidString] else { return true }
                return tape.modified > gone
            }
            .sorted { $0.modified > $1.modified }
        // Forget deletions that a later edit has overridden.
        for tape in result.mixtapes { result.deleted[tape.id.uuidString] = nil }
        return result
    }
}

/// Keeps the mixtape library in a small file in the app's documents folder,
/// which is also covered by the phone's own iCloud or computer backup.
enum MixtapeStore {
    private static var file: URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent("mixtapes.json")
    }

    static func load() -> MixtapeLibrary {
        guard let data = try? Data(contentsOf: file) else { return MixtapeLibrary() }
        if let library = try? JSONDecoder().decode(MixtapeLibrary.self, from: data) { return library }
        // The first version of the file was a plain list of mixtapes.
        let list = (try? JSONDecoder().decode([Mixtape].self, from: data)) ?? []
        return MixtapeLibrary(mixtapes: list, deleted: [:])
    }

    static func save(_ library: MixtapeLibrary) {
        guard let data = try? JSONEncoder().encode(library) else { return }
        try? data.write(to: file, options: .atomic)
    }
}

// MARK: Tapes

/// Something that can be put in the deck.
enum Tape: Identifiable {
    case album(Album)
    case playlist(Playlist)
    case song(Song)
    case mixtape(Mixtape)

    var id: String {
        switch self {
        case .album(let a): return "album-\(a.id.rawValue)"
        case .playlist(let p): return "playlist-\(p.id.rawValue)"
        case .song(let s): return "song-\(s.id.rawValue)"
        case .mixtape(let m): return "mixtape-\(m.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .album(let a): return a.title
        case .playlist(let p): return p.name
        case .song(let s): return s.title
        case .mixtape(let m): return m.name.isEmpty ? "Untitled mixtape" : m.name
        }
    }

    var subtitle: String {
        switch self {
        case .album(let a): return a.artistName
        case .playlist(let p): return p.curatorName ?? "Playlist"
        case .song(let s): return s.artistName
        case .mixtape(let m): return "\(m.lengthName) mixtape"
        }
    }

    var artwork: Artwork? {
        switch self {
        case .album(let a): return a.artwork
        case .playlist(let p): return p.artwork
        case .song(let s): return s.artwork
        case .mixtape: return nil
        }
    }

    /// Albums and singles are shop-bought tapes with a printed label.
    /// Playlists and mixtapes are home recordings, labelled by hand.
    var hasPrintedLabel: Bool {
        switch self {
        case .album, .song: return true
        case .playlist, .mixtape: return false
        }
    }

    /// The cover art's own background colour, used for the label and to tint
    /// the clear shell.
    var labelColor: CGColor? { artwork?.backgroundColor }

    /// The colour the cover art suggests for text on that background.
    var printColor: CGColor? { artwork?.primaryTextColor }
}

/// One side of a tape: what is recorded on it, in order.
struct TapeSide {
    /// The system player takes a list of one kind of item, so a side is
    /// either all album/playlist tracks or all songs.
    enum Items {
        case tracks([Track])
        case songs([Song])
    }

    struct Entry {
        let title: String
        let artist: String
        let duration: TimeInterval
    }

    let items: Items
    let entries: [Entry]
    let duration: TimeInterval

    var isBlank: Bool { entries.isEmpty }

    init(tracks: [Track]) {
        items = .tracks(tracks)
        entries = tracks.map { Entry(title: $0.title, artist: $0.artistName, duration: $0.duration ?? 0) }
        duration = entries.reduce(0) { $0 + $1.duration }
    }

    init(songs: [Song]) {
        items = .songs(songs)
        entries = songs.map { Entry(title: $0.title, artist: $0.artistName, duration: $0.duration ?? 0) }
        duration = entries.reduce(0) { $0 + $1.duration }
    }

    /// How far into the side a track starts.
    func start(of index: Int) -> TimeInterval {
        entries.prefix(max(0, index)).reduce(0) { $0 + $1.duration }
    }

    /// Which track a point on the side falls in, and how far into it.
    func locate(_ position: TimeInterval) -> (index: Int, offset: TimeInterval) {
        guard !entries.isEmpty else { return (0, 0) }
        var remaining = max(0, position)
        for (index, entry) in entries.enumerated() {
            if remaining < entry.duration || index == entries.count - 1 {
                return (index, min(remaining, max(0, entry.duration - 1)))
            }
            remaining -= entry.duration
        }
        return (entries.count - 1, 0)
    }

    /// Splits a run of tracks into two sides as near to equal length as the
    /// track boundaries allow. A single track leaves side B blank.
    static func split(_ tracks: [Track]) -> [TapeSide] {
        guard tracks.count > 1 else { return [TapeSide(tracks: tracks), TapeSide(tracks: [])] }
        let lengths = tracks.map { $0.duration ?? 0 }
        let half = lengths.reduce(0, +) / 2
        var best = 1
        var bestGap = Double.greatestFiniteMagnitude
        var running = 0.0
        for cut in 1..<tracks.count {
            running += lengths[cut - 1]
            let gap = abs(running - half)
            if gap < bestGap {
                bestGap = gap
                best = cut
            }
        }
        return [TapeSide(tracks: Array(tracks[..<best])), TapeSide(tracks: Array(tracks[best...]))]
    }
}

extension CGColor {
    /// Red, green and blue as 0...1, for sending to the lock screen.
    var rgb: [Double]? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = converted(to: space, intent: .defaultIntent, options: nil),
              let parts = converted.components, parts.count >= 3 else { return nil }
        return [Double(parts[0]), Double(parts[1]), Double(parts[2])]
    }
}
