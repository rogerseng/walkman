import Foundation
import MusicKit
import SwiftUI
import UIKit

@MainActor
final class PlayerModel: ObservableObject {
    // Access
    @Published var authStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus

    // Transport
    @Published private(set) var motion: TapeMotion = .stopped {
        didSet { if motion != oldValue { motionChanged(from: oldValue) } }
    }
    @Published private(set) var hasTape = false
    @Published private(set) var trackTitle = ""
    @Published private(set) var trackArtist = ""
    /// Position in, and length of, the current track.
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    // The tape itself
    @Published private(set) var tapeTitle = ""
    @Published private(set) var tapeSubtitle = ""
    @Published private(set) var printedLabel = false
    @Published private(set) var labelColor: CGColor?
    @Published private(set) var printColor: CGColor?
    /// 0 for side A, 1 for side B.
    @Published private(set) var sideIndex = 0
    /// How far through the current side the tape is, 0...1. This is what the
    /// reels show: the whole side, not the current song.
    @Published private(set) var progress: Double = 0
    /// The tape has run to the end of this side and stopped itself.
    @Published private(set) var sideEnded = false
    /// Turns the cassette over on screen while it is being flipped.
    @Published private(set) var flipAngle: Double = 0

    // Shelf
    @Published private(set) var libraryPlaylists: [Tape] = []
    @Published private(set) var libraryAlbums: [Tape] = []
    @Published private(set) var searchResults: [Tape] = []
    @Published private(set) var isLoadingLibrary = false
    @Published private(set) var mixtapes: [Mixtape] = MixtapeStore.load()

    @Published var errorMessage: String?
    @Published var soundEffectsOn: Bool {
        didSet {
            sounds.enabled = soundEffectsOn
            UserDefaults.standard.set(soundEffectsOn, forKey: "soundEffectsOn")
        }
    }

    var sideLetter: String { sideIndex == 0 ? "A" : "B" }

    /// The current track and artist on one line, for labels.
    var trackLine: String {
        if trackTitle.isEmpty || trackTitle == tapeTitle { return trackArtist }
        return trackArtist.isEmpty ? trackTitle : "\(trackTitle) · \(trackArtist)"
    }

    /// What to tell the listener when the tape has run out.
    var endOfSideNote: String? {
        guard hasTape, sideEnded else { return nil }
        let other = 1 - sideIndex
        if other < sides.count, !sides[other].isBlank {
            return "End of side \(sideLetter). Double-tap the tape to flip it."
        }
        return "End of side \(sideLetter). The other side is blank."
    }

    private let player = ApplicationMusicPlayer.shared
    private let sounds = TapeSounds()
    private let lockScreen = LockScreenTape()
    private var sides: [TapeSide] = []
    private var trackIndex = 0
    private var pausedSince: Date?
    private var waitingForLid = false
    private var heldSeek: TapeMotion?
    private var seekTask: Task<Void, Never>?
    /// Winding the tape by hand: where it has got to on the side, and
    /// whether to carry on playing when the key is let go.
    private var winding = false
    private var windPosition: TimeInterval = 0
    private var windResume = false
    /// This press of the key wound the tape, so letting go must not skip a song.
    private var keyWound = false
    private var swapping = false
    private var lastKeyPress = Date.distantPast
    private var lastEntryID: String?

    init() {
        let stored = UserDefaults.standard.object(forKey: "soundEffectsOn") as? Bool
        soundEffectsOn = stored ?? true
        sounds.enabled = soundEffectsOn
        Haptics.warmUp()

        Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
        if authStatus == .authorized {
            Task { await loadLibrary() }
        }
    }

    // MARK: Access

    func requestAccess() async {
        authStatus = await MusicAuthorization.request()
        if authStatus == .authorized {
            await loadLibrary()
        }
    }

    // MARK: Shelf

    func loadLibrary() async {
        isLoadingLibrary = true
        defer { isLoadingLibrary = false }
        do {
            var playlists = MusicLibraryRequest<Playlist>()
            playlists.limit = 100
            libraryPlaylists = try await playlists.response().items.map { Tape.playlist($0) }

            var albums = MusicLibraryRequest<Album>()
            albums.limit = 200
            libraryAlbums = try await albums.response().items.map { Tape.album($0) }
        } catch {
            errorMessage = "Could not read your library. \(error.localizedDescription)"
        }
    }

    func search(_ term: String) async {
        let term = term.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else {
            searchResults = []
            return
        }
        do {
            var request = MusicCatalogSearchRequest(term: term, types: [Album.self, Playlist.self, Song.self])
            request.limit = 12
            let response = try await request.response()
            guard !Task.isCancelled else { return }
            searchResults = response.albums.map { Tape.album($0) }
                + response.playlists.map { Tape.playlist($0) }
                + response.songs.map { Tape.song($0) }
        } catch {
            if !Task.isCancelled {
                errorMessage = "Search failed. \(error.localizedDescription)"
            }
        }
    }

    // MARK: Mixtapes

    /// Songs from the Apple Music catalogue, for recording onto a mixtape.
    func searchSongs(_ term: String) async -> [MixSong] {
        let term = term.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return [] }
        do {
            var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
            request.limit = 20
            let response = try await request.response()
            return response.songs.map {
                MixSong(id: $0.id.rawValue, title: $0.title, artist: $0.artistName, duration: $0.duration ?? 0)
            }
        } catch {
            if !Task.isCancelled {
                errorMessage = "Search failed. \(error.localizedDescription)"
            }
            return []
        }
    }

    func save(_ mixtape: Mixtape) {
        if let index = mixtapes.firstIndex(where: { $0.id == mixtape.id }) {
            mixtapes[index] = mixtape
        } else {
            mixtapes.insert(mixtape, at: 0)
        }
        MixtapeStore.save(mixtapes)
    }

    func delete(_ mixtape: Mixtape) {
        mixtapes.removeAll { $0.id == mixtape.id }
        MixtapeStore.save(mixtapes)
    }

    // MARK: Loading tapes

    /// The phone was folded shut. A tape chosen while it was open starts now.
    func lidClosed() {
        guard Prefs.isOn(Prefs.playOnClose), waitingForLid, hasTape, motion != .playing else { return }
        playKey()
    }

    /// Ejects whatever is in the deck and drops the new tape in. With
    /// `autoPlay` it then presses play; without, it waits for the play key or
    /// for the phone to be closed.
    func insert(_ tape: Tape, autoPlay: Bool = true) {
        guard !swapping else { return }
        swapping = true
        lastKeyPress = Date()
        Task {
            defer { swapping = false }
            if hasTape {
                sounds.play(.eject)
                Haptics.door()
                player.stop()
                withAnimation(.easeIn(duration: 0.25)) { hasTape = false }
                await pause(seconds: 0.6)
            }
            do {
                let loaded = try await loadSides(of: tape)
                guard let first = loaded.firstIndex(where: { !$0.isBlank }) else {
                    errorMessage = "That tape has nothing on it."
                    return
                }
                sides = loaded
                sideIndex = first
                sideEnded = false
                progress = 0
                trackIndex = 0
                tapeTitle = tape.title
                tapeSubtitle = tape.subtitle
                printedLabel = tape.hasPrintedLabel
                labelColor = tape.labelColor
                printColor = tape.printColor
                trackTitle = ""
                trackArtist = tape.subtitle
                elapsed = 0
                duration = 0
                lastEntryID = nil
                setQueue(side: sides[first], startAt: 0)
                sounds.play(.insert)
                Haptics.seat()
                Task {
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    Haptics.door()
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { hasTape = true }
                if autoPlay {
                    await pause(seconds: 0.55)
                    pressFeedback()
                    try await player.play()
                } else {
                    waitingForLid = true
                    try await player.prepareToPlay()
                }
            } catch {
                errorMessage = "That tape would not play. \(error.localizedDescription)"
            }
        }
    }

    /// Works out what is on each side of a tape. Albums and playlists are
    /// split into two sides of about the same length.
    private func loadSides(of tape: Tape) async throws -> [TapeSide] {
        switch tape {
        case .album(let album):
            let full = try await album.with([.tracks])
            return TapeSide.split(Array(full.tracks ?? []))
        case .playlist(let playlist):
            let full = try await playlist.with([.tracks])
            return TapeSide.split(Array(full.tracks ?? []))
        case .song(let song):
            return [TapeSide(songs: [song]), TapeSide(songs: [])]
        case .mixtape(let mixtape):
            let a = try await songs(for: mixtape.sideA)
            let b = try await songs(for: mixtape.sideB)
            return [TapeSide(songs: a), TapeSide(songs: b)]
        }
    }

    private func songs(for list: [MixSong]) async throws -> [Song] {
        guard !list.isEmpty else { return [] }
        let ids = list.map { MusicItemID($0.id) }
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: ids)
        let found = try await request.response().items
        // The catalogue answers in its own order; put them back in ours.
        return ids.compactMap { id in found.first { $0.id == id } }
    }

    private func setQueue(side: TapeSide, startAt index: Int) {
        switch side.items {
        case .tracks(let tracks):
            guard tracks.indices.contains(index) else { return }
            player.queue = ApplicationMusicPlayer.Queue(for: tracks, startingAt: tracks[index])
        case .songs(let songs):
            guard songs.indices.contains(index) else { return }
            player.queue = ApplicationMusicPlayer.Queue(for: songs, startingAt: songs[index])
        }
        trackIndex = index
        lastEntryID = nil
    }

    private func eject() {
        sounds.play(.eject)
        Haptics.door()
        player.stop()
        player.queue = []
        withAnimation(.easeIn(duration: 0.25)) { hasTape = false }
        sides = []
        sideIndex = 0
        sideEnded = false
        progress = 0
        tapeTitle = ""
        tapeSubtitle = ""
        labelColor = nil
        printColor = nil
        trackTitle = ""
        trackArtist = ""
        elapsed = 0
        duration = 0
        lastEntryID = nil
    }

    // MARK: Flipping

    /// Takes the tape out, turns it over and puts it back. As with a real
    /// cassette, you land as far from the end of the new side as you were
    /// from the start of the old one. A tape flipped at the very start of a
    /// side is treated as rewound, so the other side begins at its beginning.
    func flipTape() {
        guard hasTape, !swapping, sides.count == 2 else { return }
        let other = 1 - sideIndex
        guard !sides[other].isBlank else {
            pressFeedback()
            errorMessage = "Side \(other == 0 ? "A" : "B") of this tape is blank."
            return
        }
        let from = sideEnded ? 1 : progress
        let resume = motion == .playing || sideEnded
        swapping = true
        lastKeyPress = Date()
        Task {
            defer { swapping = false }
            sounds.play(.eject)
            Haptics.door()
            player.pause()
            withAnimation(.easeIn(duration: 0.28)) { flipAngle = 90 }
            await pause(seconds: 0.3)

            let side = sides[other]
            let position = from < 0.02 ? 0 : (1 - from) * side.duration
            let spot = side.locate(position)
            sideIndex = other
            sideEnded = false
            progress = side.duration > 0 ? min(1, position / side.duration) : 0
            setQueue(side: side, startAt: spot.index)

            // Come round from the far edge without animating the jump.
            var snap = Transaction()
            snap.disablesAnimations = true
            withTransaction(snap) { flipAngle = -90 }
            withAnimation(.easeOut(duration: 0.28)) { flipAngle = 0 }
            sounds.play(.insert)
            Haptics.seat()
            await pause(seconds: 0.3)
            Haptics.door()

            do {
                try await player.prepareToPlay()
                if spot.offset > 0 { player.playbackTime = spot.offset }
                if resume {
                    pressFeedback()
                    try await player.play()
                }
            } catch {
                errorMessage = "The tape would not play. \(error.localizedDescription)"
            }
        }
    }

    // MARK: Keys

    func playKey() {
        pressFeedback()
        guard hasTape else { return }
        if sideEnded {
            // End of the tape: the key will not stay down.
            Task {
                await pause(seconds: 0.18)
                sounds.play(.keyUp)
                Haptics.keyUp()
            }
            return
        }
        run {
            try await self.player.play()
            self.refresh()
        }
    }

    /// Stops the tape where it is. Play carries on from the same place.
    func stopKey() {
        pressFeedback()
        guard hasTape else { return }
        if motion != .paused, motion != .stopped {
            player.pause()
            refresh()
        }
    }

    /// One key for both: pauses while playing, plays otherwise.
    func playPauseKey() {
        if motion == .playing {
            pauseKey()
        } else {
            playKey()
        }
    }

    func pauseKey() {
        pressFeedback()
        guard hasTape else { return }
        if motion == .playing {
            player.pause()
        } else if motion == .paused, !sideEnded {
            run { try await self.player.play() }
        }
    }

    /// The eject key. On the closed phone it only opens the shelf, so the
    /// music carries on until another tape is chosen. Where `removeTape` is
    /// set it takes the tape out.
    func ejectKey(removeTape: Bool) {
        lastKeyPress = Date()
        if removeTape, hasTape {
            eject()
        } else {
            sounds.play(.keyDown)
            Haptics.keyDown()
        }
    }

    /// Rewind and fast forward: a tap skips a song, a hold winds the tape.
    func seekKeyDown(forward: Bool) {
        pressFeedback()
        guard hasTape else { return }
        keyWound = false
        seekTask?.cancel()
        seekTask = Task {
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            guard !Task.isCancelled, sideIndex < sides.count else { return }
            await wind(forward: forward)
        }
    }

    /// Winds the tape the way a deck does: the music stops, the motor spins
    /// the reels up to speed, and the tape runs on through one song after
    /// another until the key is let go or the tape runs out.
    private func wind(forward: Bool) async {
        let side = sides[sideIndex]
        guard side.duration > 0 else { return }
        keyWound = true
        windResume = motion == .playing
        windPosition = sideEnded ? side.duration : side.start(of: trackIndex) + elapsed
        player.pause()
        sideEnded = false
        winding = true
        heldSeek = forward ? .fastForward : .rewind
        refresh()

        var held = 0.0
        while !Task.isCancelled {
            do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
            held += 0.1
            // Seconds of tape per second: slow off the mark, then quick.
            let rate = min(45, 12 + held * 14)
            windPosition += (forward ? 1 : -1) * rate * 0.1
            let hitEnd = windPosition <= 0 || windPosition >= side.duration
            windPosition = min(max(windPosition, 0), side.duration)

            let spot = side.locate(windPosition)
            trackIndex = spot.index
            trackTitle = side.entries[spot.index].title
            trackArtist = side.entries[spot.index].artist
            duration = side.entries[spot.index].duration
            elapsed = spot.offset
            progress = windPosition / side.duration

            if hitEnd {
                // The tape has run out: the key is thrown back up.
                finishWinding()
                return
            }
        }
    }

    /// Lets the winding key go and picks the music up where the tape stopped.
    private func finishWinding() {
        guard winding, sideIndex < sides.count else { return }
        let side = sides[sideIndex]
        winding = false
        heldSeek = nil
        lastKeyPress = Date()
        sounds.play(.keyUp)
        Haptics.keyUp()
        if windPosition >= side.duration - 0.5 {
            sideEnded = true
            progress = 1
            refresh()
            return
        }
        let resume = windResume
        let position = windPosition
        Task {
            do {
                let spot = side.locate(position)
                setQueue(side: side, startAt: spot.index)
                try await player.prepareToPlay()
                if spot.offset > 0 { player.playbackTime = spot.offset }
                if resume { try await player.play() }
            } catch {
                errorMessage = "The tape would not play. \(error.localizedDescription)"
            }
            refresh()
        }
    }

    func seekKeyUp(forward: Bool) {
        seekTask?.cancel()
        seekTask = nil
        guard hasTape else { return }
        if winding {
            finishWinding()
        } else if keyWound {
            // The tape ran out while the key was still held.
            keyWound = false
        } else {
            run {
                if forward {
                    try await self.player.skipToNextEntry()
                } else {
                    try await self.player.skipToPreviousEntry()
                }
            }
        }
    }

    // MARK: Internals

    private func pressFeedback() {
        lastKeyPress = Date()
        sounds.play(.keyDown)
        Haptics.keyDown()
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        Task {
            do {
                try await operation()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func pause(seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func motionChanged(from old: TapeMotion) {
        switch motion {
        case .playing: sounds.setLoop(.hiss)
        case .fastForward, .rewind: sounds.setLoop(.whir)
        case .paused, .stopped: sounds.setLoop(nil)
        }
        pausedSince = motion == .paused ? Date() : nil
        if motion == .playing {
            waitingForLid = false
            sideEnded = false
        }
        // The music stopped on its own: the play key pops back up.
        if old == .playing, motion == .stopped || motion == .paused,
           Date().timeIntervalSince(lastKeyPress) > 1.0 {
            sounds.play(.keyUp)
            Haptics.keyUp()
            // If that was the last track on this side, the tape has run out.
            if !swapping, sideIndex < sides.count,
               trackIndex >= sides[sideIndex].entries.count - 1,
               duration <= 0 || duration - elapsed < 3 || elapsed < 1.5 {
                sideEnded = true
                progress = 1
                // Auto reverse, for those who have it switched on
                let other = 1 - sideIndex
                if Prefs.isOn(Prefs.autoFlip), other < sides.count, !sides[other].isBlank {
                    Task {
                        await pause(seconds: 0.8)
                        if sideEnded { flipTape() }
                    }
                }
            }
        }
    }

    /// Mirrors the system player's state into published properties.
    private func refresh() {
        guard hasTape, !swapping else {
            if !hasTape {
                if motion != .stopped { motion = .stopped }
                sounds.keepAlive = false
                lockScreen.end()
            }
            return
        }

        let hissOn = Prefs.isOn(Prefs.hiss)
        if sounds.hissEnabled != hissOn { sounds.hissEnabled = hissOn }

        if winding, let heldSeek {
            // Winding by hand: the tape position is ours until the key is let go.
            if motion != heldSeek { motion = heldSeek }
            Haptics.windTick() // the motor, felt four times a second
            return
        }

        let newMotion: TapeMotion
        if let heldSeek {
            newMotion = heldSeek
        } else {
            switch player.state.playbackStatus {
            case .playing: newMotion = .playing
            case .paused, .interrupted: newMotion = .paused
            case .seekingForward: newMotion = .fastForward
            case .seekingBackward: newMotion = .rewind
            case .stopped: newMotion = .stopped
            @unknown default: newMotion = .stopped
            }
        }
        if newMotion != motion { motion = newMotion }

        let time = player.playbackTime
        if time.isFinite, abs(time - elapsed) > 0.05 { elapsed = max(time, 0) }

        if let entry = player.queue.currentEntry, sideIndex < sides.count {
            let side = sides[sideIndex]
            if entry.id != lastEntryID {
                lastEntryID = entry.id
                trackTitle = entry.title
                trackArtist = entry.subtitle ?? ""
                // Find this track on the side, looking forward from the last one first.
                let titles = side.entries.map(\.title)
                if let ahead = titles.indices.first(where: { $0 >= trackIndex && titles[$0] == entry.title }) {
                    trackIndex = ahead
                } else if let anywhere = titles.firstIndex(of: entry.title) {
                    trackIndex = anywhere
                }
            }
            var length: TimeInterval = 0
            if case .song(let song)? = entry.item {
                length = song.duration ?? 0
            } else if case .musicVideo(let video)? = entry.item {
                length = video.duration ?? 0
            }
            if length != duration { duration = length }

            // Where the tape is on this side as a whole.
            if !sideEnded, side.duration > 0 {
                let position = side.start(of: trackIndex) + elapsed
                let through = min(max(position / side.duration, 0), 1)
                if abs(through - progress) > 0.0005 { progress = through }
            }
        }

        syncLockScreen()
    }

    /// Keeps the lock screen tape current, and keeps the app awake behind the
    /// lock screen so it can do that. A tape left paused for ten minutes is put
    /// away so nothing stale is left showing and no battery is wasted.
    private func syncLockScreen() {
        let parked = motion == .paused
            && Date().timeIntervalSince(pausedSince ?? Date()) > 600
        guard motion != .stopped, !parked, Prefs.isOn(Prefs.lockScreenTape) else {
            sounds.keepAlive = false
            lockScreen.end()
            return
        }
        sounds.keepAlive = true
        lockScreen.sync(title: tapeTitle, subtitle: trackLine, isPlaying: motion == .playing,
                        elapsed: elapsed, duration: duration,
                        tapeProgress: progress, side: sideLetter, tint: labelColor?.rgb)
    }
}
