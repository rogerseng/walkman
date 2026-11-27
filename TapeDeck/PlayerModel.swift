import Foundation
import MusicKit
import SwiftUI
import UIKit

/// What the tape transport is doing right now.
enum TapeMotion: Equatable {
    case stopped, playing, paused, fastForward, rewind
}

/// Something that can be put in the deck.
enum Tape: Identifiable {
    case album(Album)
    case playlist(Playlist)
    case song(Song)

    var id: String {
        switch self {
        case .album(let a): return "album-\(a.id.rawValue)"
        case .playlist(let p): return "playlist-\(p.id.rawValue)"
        case .song(let s): return "song-\(s.id.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .album(let a): return a.title
        case .playlist(let p): return p.name
        case .song(let s): return s.title
        }
    }

    var subtitle: String {
        switch self {
        case .album(let a): return a.artistName
        case .playlist(let p): return p.curatorName ?? "Playlist"
        case .song(let s): return s.artistName
        }
    }

    var artwork: Artwork? {
        switch self {
        case .album(let a): return a.artwork
        case .playlist(let p): return p.artwork
        case .song(let s): return s.artwork
        }
    }
}

@MainActor
final class PlayerModel: ObservableObject {
    // Access
    @Published var authStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus

    // Transport
    @Published private(set) var motion: TapeMotion = .stopped {
        didSet { if motion != oldValue { motionChanged(from: oldValue) } }
    }
    @Published private(set) var hasTape = false
    @Published private(set) var tapeTitle = ""
    @Published private(set) var trackTitle = ""
    @Published private(set) var trackArtist = ""
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    // Shelf
    @Published private(set) var libraryPlaylists: [Tape] = []
    @Published private(set) var libraryAlbums: [Tape] = []
    @Published private(set) var searchResults: [Tape] = []
    @Published private(set) var isLoadingLibrary = false

    @Published var errorMessage: String?
    @Published var soundEffectsOn: Bool {
        didSet {
            sounds.enabled = soundEffectsOn
            UserDefaults.standard.set(soundEffectsOn, forKey: "soundEffectsOn")
        }
    }

    /// 0 at the start of the current track, 1 at the end.
    var progress: Double {
        duration > 0 ? min(max(elapsed / duration, 0), 1) : 0
    }

    private let player = ApplicationMusicPlayer.shared
    private let sounds = TapeSounds()
    private let lockScreen = LockScreenTape()
    private var pausedSince: Date?
    private var waitingForLid = false
    private var heldSeek: TapeMotion?
    private var seekTask: Task<Void, Never>?
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

    // MARK: Loading tapes

    /// The current track and artist on one line, for labels.
    var trackLine: String {
        if trackTitle.isEmpty || trackTitle == tapeTitle { return trackArtist }
        return trackArtist.isEmpty ? trackTitle : "\(trackTitle) · \(trackArtist)"
    }

    /// The phone was folded shut. A tape chosen while it was open starts now.
    func lidClosed() {
        guard waitingForLid, hasTape, motion != .playing else { return }
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
                switch tape {
                case .album(let album): player.queue = [album]
                case .playlist(let playlist): player.queue = [playlist]
                case .song(let song): player.queue = [song]
                }
                tapeTitle = tape.title
                trackTitle = ""
                trackArtist = tape.subtitle
                elapsed = 0
                duration = 0
                lastEntryID = nil
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

    private func eject() {
        sounds.play(.eject)
        Haptics.door()
        player.stop()
        player.queue = []
        withAnimation(.easeIn(duration: 0.25)) { hasTape = false }
        tapeTitle = ""
        trackTitle = ""
        trackArtist = ""
        elapsed = 0
        duration = 0
        lastEntryID = nil
    }

    // MARK: Keys

    func playKey() {
        pressFeedback()
        guard hasTape else { return }
        run { try await self.player.play() }
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
        } else if motion == .paused {
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

    /// Rewind and fast forward: a tap skips a track, a hold winds the tape.
    func seekKeyDown(forward: Bool) {
        pressFeedback()
        guard hasTape else { return }
        seekTask?.cancel()
        seekTask = Task {
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            guard !Task.isCancelled else { return }
            heldSeek = forward ? .fastForward : .rewind
            if forward {
                player.beginSeekingForward()
            } else {
                player.beginSeekingBackward()
            }
            refresh()
        }
    }

    func seekKeyUp(forward: Bool) {
        seekTask?.cancel()
        seekTask = nil
        guard hasTape else { return }
        if heldSeek != nil {
            heldSeek = nil
            player.endSeeking()
            lastKeyPress = Date()
            sounds.play(.keyUp)
            Haptics.keyUp()
            refresh()
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
        if motion == .playing { waitingForLid = false }
        // The tape ran out on its own: the play key pops back up.
        if old == .playing, motion == .stopped || motion == .paused,
           Date().timeIntervalSince(lastKeyPress) > 1.0 {
            sounds.play(.keyUp)
            Haptics.keyUp()
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

        let newMotion: TapeMotion
        if let heldSeek {
            newMotion = heldSeek
            Haptics.windTick() // the motor, felt four times a second
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

        if let entry = player.queue.currentEntry {
            if entry.id != lastEntryID {
                lastEntryID = entry.id
                trackTitle = entry.title
                trackArtist = entry.subtitle ?? ""
            }
            var length: TimeInterval = 0
            if case .song(let song)? = entry.item {
                length = song.duration ?? 0
            } else if case .musicVideo(let video)? = entry.item {
                length = video.duration ?? 0
            }
            if length != duration { duration = length }
        }

        let time = player.playbackTime
        if time.isFinite, abs(time - elapsed) > 0.05 { elapsed = max(time, 0) }

        syncLockScreen()
    }

    /// Keeps the lock screen tape current, and keeps the app awake behind the
    /// lock screen so it can do that. A tape left paused for ten minutes is put
    /// away so nothing stale is left showing and no battery is wasted.
    private func syncLockScreen() {
        let parked = motion == .paused
            && Date().timeIntervalSince(pausedSince ?? Date()) > 600
        guard motion != .stopped, !parked else {
            sounds.keepAlive = false
            lockScreen.end()
            return
        }
        sounds.keepAlive = true
        lockScreen.sync(title: tapeTitle, subtitle: trackLine, isPlaying: motion == .playing,
                        elapsed: elapsed, duration: duration)
    }
}
