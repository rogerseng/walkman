import Combine
import Foundation
import MediaPlayer
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
    /// The tempo the lights and speakers move to. It is the song's own when
    /// the music library knows it, and a steady default when it does not:
    /// an app cannot listen to the music to work it out.
    @Published private(set) var beatsPerMinute = PlayerModel.defaultTempo
    static let defaultTempo = 123.0
    /// The album or playlist in the deck, for showing its songs.
    @Published private(set) var currentTape: Tape?
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
    /// The cover art of the tape in the deck, if it has any.
    @Published private(set) var tapeArtwork: Artwork?
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
    @Published private(set) var mixtapes: [Mixtape] = []
    /// A line saying how iCloud sync stands, for the settings screen.
    @Published private(set) var cloudStatus = ""

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

    /// The deck has chewed the tape: it hangs out of the cassette in a
    /// tangle and nothing plays until it is wound back in. A bit of fun,
    /// set off by leaning on a reel.
    @Published private(set) var tapeEaten = false

    /// The moment the tape is on its way out of the cassette or back in:
    /// the reels race and nothing else can be done.
    enum TapeChurn { case eating, winding }
    @Published private(set) var tapeChurn: TapeChurn?

    /// The tape is out, or on its way out or in: the keys do nothing.
    var tapeJammed: Bool { tapeEaten || tapeChurn != nil }

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
    private let cloud = CloudSync()
    private var library = MixtapeStore.load()
    private var sides: [TapeSide] = []
    private var trackIndex = 0
    private var pausedSince: Date?
    private var waitingForLid = false
    private var heldSeek: TapeMotion?
    /// What a key just asked for, shown at once while the system player
    /// catches up, so the key latches the moment it is pressed.
    private var promised: (motion: TapeMotion, since: Date)?
    /// The motor running the tape up to speed or down to a stop. Each run
    /// has a number, so one that was replaced cannot clear its successor.
    private var rampTask: Task<Void, Never>?
    private var rampNumber = 0
    private var ramping: Bool { rampTask != nil }
    /// The work of picking the music up after a wind, and whether it is
    /// going to start the music again.
    private var finishTask: Task<Void, Never>?
    private var resumePending = false
    /// A key's promise ran out without the player agreeing, so the change
    /// of motion that follows is not the music stopping by itself.
    private var promiseLapsed = false
    private var wasReallyPlaying = false

    /// Things the listener did on the deck, as they happen. The tour listens.
    enum DeckEvent { case inserted, played, stopped, skipped, wound, flipped }
    let events = PassthroughSubject<DeckEvent, Never>()
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
        mixtapes = library.mixtapes
        cloud.onRemoteChange = { [weak self] in self?.syncWithCloud() }
        cloud.start()
        syncWithCloud()

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
            var found: [Tape] = response.albums.map { Tape.album($0) }
            found += response.playlists.map { Tape.playlist($0) }
            found += response.songs.map { Tape.song($0) }
            searchResults = found
        } catch {
            if !Task.isCancelled {
                errorMessage = "Search failed. \(error.localizedDescription)"
            }
        }
    }

    // MARK: Mixtapes

    func save(_ mixtape: Mixtape) {
        library.put(mixtape)
        libraryChanged()
    }

    func delete(_ mixtape: Mixtape) {
        library.remove(mixtape)
        libraryChanged()
    }

    private func libraryChanged() {
        mixtapes = library.mixtapes
        MixtapeStore.save(library)
        cloud.push(library)
        cloudStatus = cloud.status
    }

    // MARK: iCloud and backup

    /// Brings this device and iCloud into line: whatever either has that the
    /// other lacks is kept, and the newer copy of anything they share wins.
    func syncWithCloud() {
        if cloud.isOn {
            cloud.pullSettings()
            cloud.pushSettings()
            let sounds = Prefs.isOn(Prefs.sounds)
            if soundEffectsOn != sounds { soundEffectsOn = sounds }
            if let remote = cloud.remoteLibrary() {
                let merged = library.merged(with: remote)
                if merged != library {
                    library = merged
                    mixtapes = library.mixtapes
                    MixtapeStore.save(library)
                }
            }
            cloud.push(library)
        }
        cloudStatus = cloud.status
    }

    /// Everything worth keeping, as the contents of a backup file.
    func makeBackup() -> Data? {
        var settings: [String: Bool] = [:]
        for key in CloudSync.syncedPrefs { settings[key] = Prefs.isOn(key) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        var choices: [String: String] = [:]
        for key in CloudSync.syncedChoices {
            choices[key] = UserDefaults.standard.string(forKey: key)
        }
        return try? encoder.encode(Backup(library: library, settings: settings, choices: choices))
    }

    /// Restores from a backup file. Settings are set to what the backup holds.
    /// Mixtapes are merged in: tapes in the backup come back, and tapes made
    /// since are kept. Returns how many mixtapes the backup held.
    func restore(from data: Data) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: data)
        for (key, value) in backup.settings where CloudSync.syncedPrefs.contains(key) {
            UserDefaults.standard.set(value, forKey: key)
        }
        for (key, value) in backup.choices ?? [:] where CloudSync.syncedChoices.contains(key) {
            UserDefaults.standard.set(value, forKey: key)
        }
        let sounds = Prefs.isOn(Prefs.sounds)
        if soundEffectsOn != sounds { soundEffectsOn = sounds }
        // A restore is a deliberate act: bring back tapes even if they were
        // deleted after the backup was made.
        var incoming = backup.library
        incoming.deleted = [:]
        for tape in incoming.mixtapes { library.deleted[tape.id.uuidString] = nil }
        library = library.merged(with: incoming)
        libraryChanged()
        return backup.library.mixtapes.count
    }

    // MARK: Loading tapes

    /// The phone was folded shut. A tape chosen while it was open starts now.
    func lidClosed() {
        guard Prefs.isOn(Prefs.playOnClose), waitingForLid, hasTape, motion != .playing else { return }
        playKey()
    }

    /// Puts a tape in, or, if that tape is already in the deck and a song on
    /// it was chosen, winds straight to that song without taking it out.
    func put(_ tape: Tape, startingAt trackID: MusicItemID?, autoPlay: Bool) {
        if let trackID, hasTape, !swapping, currentTape?.id == tape.id {
            for (number, side) in sides.enumerated() {
                guard let index = side.index(of: trackID) else { continue }
                resetTransport()
                lastKeyPress = Date()
                sideIndex = number
                sideEnded = false
                elapsed = 0
                progress = side.duration > 0 ? side.start(of: index) / side.duration : 0
                setQueue(side: side, startAt: index)
                // A song chosen from a list simply starts: no key goes
                // down, and the tape does not slur up to speed.
                promise(.playing)
                startTape(slur: false)
                return
            }
        }
        insert(tape, autoPlay: autoPlay, startingAt: trackID)
    }

    /// True when the other side has something on it to turn over to.
    var canFlip: Bool {
        let other = 1 - sideIndex
        return hasTape && other < sides.count && !sides[other].isBlank
    }

    /// Ejects whatever is in the deck and drops the new tape in. With
    /// `autoPlay` it then presses play; without, it waits for the play key or
    /// for the phone to be closed. With `startingAt`, the tape is wound on to
    /// that track first, on whichever side it is recorded.
    func insert(_ tape: Tape, autoPlay: Bool = true, startingAt trackID: MusicItemID? = nil) {
        guard !swapping else { return }
        swapping = true
        lastKeyPress = Date()
        resetTransport()
        // A song tapped in a list should simply start, so its tape goes in
        // without the door, its sounds and their waits.
        let quick = trackID != nil && autoPlay
        Task {
            defer { swapping = false }
            if hasTape, quick {
                player.stop()
            } else if hasTape {
                sounds.play(.eject)
                Haptics.door()
                player.stop()
                withAnimation(.easeIn(duration: 0.4)) { hasTape = false }
                await pause(seconds: 0.8)
            }
            do {
                let loaded = try await loadSides(of: tape)
                guard var first = loaded.firstIndex(where: { !$0.isBlank }) else {
                    errorMessage = "That tape has nothing on it."
                    return
                }
                var startIndex = 0
                if let trackID {
                    for (number, side) in loaded.enumerated() {
                        if let found = side.index(of: trackID) {
                            first = number
                            startIndex = found
                            break
                        }
                    }
                }
                sides = loaded
                sideIndex = first
                sideEnded = false
                let side = loaded[first]
                progress = side.duration > 0 ? side.start(of: startIndex) / side.duration : 0
                trackIndex = startIndex
                currentTape = tape
                tapeTitle = tape.title
                tapeSubtitle = tape.subtitle
                printedLabel = tape.hasPrintedLabel
                labelColor = tape.labelColor
                printColor = tape.printColor
                tapeArtwork = tape.artwork
                trackTitle = ""
                trackArtist = tape.subtitle
                elapsed = 0
                duration = 0
                lastEntryID = nil
                setQueue(side: sides[first], startAt: startIndex)
                if !quick {
                    sounds.play(.insert)
                    Haptics.seat()
                    Task {
                        try? await Task.sleep(nanoseconds: 180_000_000)
                        Haptics.door()
                    }
                }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) { hasTape = true }
                events.send(.inserted)
                if autoPlay {
                    if !quick {
                        await pause(seconds: 0.55)
                        pressFeedback()
                    }
                    try await player.play()
                } else {
                    waitingForLid = true
                    try await player.prepareToPlay()
                }
            } catch {
                errorMessage = await explain(error, doing: "That tape would not play.")
            }
        }
    }

    /// Works out what is on each side of a tape. Albums and playlists are
    /// split into two sides of about the same length.
    private func loadSides(of tape: Tape) async throws -> [TapeSide] {
        switch tape {
        case .album(let album):
            let full = try await album.with([.tracks])
            return TapeSide.split(try await Self.everything(in: full.tracks))
        case .playlist(let playlist):
            let full = try await playlist.with([.tracks])
            return TapeSide.split(try await Self.everything(in: full.tracks))
        case .song(let song):
            return [TapeSide(songs: [song]), TapeSide(songs: [])]
        case .mixtape(let mixtape):
            let a = try await songs(for: mixtape.sideA)
            let b = try await songs(for: mixtape.sideB)
            return [TapeSide(songs: a), TapeSide(songs: b)]
        }
    }

    /// Every track of an album or playlist. Long ones arrive a batch at a
    /// time, and a tape needs them all.
    static func everything(in tracks: MusicItemCollection<Track>?) async throws -> [Track] {
        guard var batch = tracks else { return [] }
        var all = Array(batch)
        while batch.hasNextBatch, all.count < 2000, let next = try await batch.nextBatch() {
            all += Array(next)
            batch = next
        }
        return all
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

    /// Lets go of everything in progress on the transport: a wind, a run-up
    /// or run-down, a promise. Called whenever the tape itself changes.
    private func resetTransport() {
        tapeEaten = false
        tapeChurn = nil
        seekTask?.cancel()
        seekTask = nil
        finishTask?.cancel()
        finishTask = nil
        resumePending = false
        winding = false
        heldSeek = nil
        keyWound = false
        promised = nil
        cancelRamp()
    }

    private func eject() {
        resetTransport()
        sounds.play(.eject)
        Haptics.door()
        player.stop()
        player.queue = []
        withAnimation(.easeIn(duration: 0.4)) { hasTape = false }
        sides = []
        currentTape = nil
        sideIndex = 0
        sideEnded = false
        progress = 0
        tapeTitle = ""
        tapeSubtitle = ""
        labelColor = nil
        printColor = nil
        tapeArtwork = nil
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
        guard hasTape, !swapping, !tapeJammed, sides.count == 2 else { return }
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
        resetTransport()
        Task {
            defer { swapping = false }
            sounds.play(.eject)
            Haptics.door()
            player.pause()
            withAnimation(.easeIn(duration: 0.28)) { flipAngle = 90 }
            await pause(seconds: 0.3)

            // The tape may have been taken out while it was turning.
            guard hasTape, other < sides.count else {
                flipAngle = 0
                return
            }
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
            events.send(.flipped)
            await pause(seconds: 0.3)
            Haptics.door()
            guard hasTape else { return }

            do {
                try await player.prepareToPlay()
                if spot.offset > 0 { player.playbackTime = spot.offset }
                if resume {
                    pressFeedback()
                    try await player.play()
                }
            } catch {
                errorMessage = await explain(error, doing: "The tape would not play.")
            }
        }
    }

    // MARK: Keys

    func playKey() {
        pressFeedback()
        guard hasTape else { return }
        if sideEnded || tapeJammed {
            // End of the tape: the key will not stay down.
            Task {
                await pause(seconds: 0.18)
                sounds.play(.keyUp)
                Haptics.keyUp()
            }
            return
        }
        // Already down and playing: the key has nothing more to do.
        guard motion != .playing else { return }
        promise(.playing)
        startTape()
    }

    /// Stops the tape where it is. Play carries on from the same place.
    func stopKey() {
        pressFeedback()
        guard hasTape, !swapping else { return }
        if motion != .paused, motion != .stopped {
            if player.state.playbackStatus == .playing { events.send(.stopped) }
            promise(.paused)
            stopTape()
        }
    }

    // MARK: Chewed tape

    /// The speeds the music lurches through as the tape snags.
    private static let chewRates: [Float] = [0.8, 1.12, 0.62, 0.95, 0.5, 0.7, 0.36]

    /// The deck eats the tape: the music lurches and stops, and the tape
    /// spills out until it is wound back.
    func eatTape() {
        guard hasTape, !swapping, !tapeJammed,
              motion != .fastForward, motion != .rewind else { return }
        sounds.play(.tangle)
        Haptics.chew()
        tapeChurn = .eating
        withAnimation(.easeIn(duration: 1.2)) { tapeEaten = true }
        Task {
            await pause(seconds: 1.25)
            if tapeChurn == .eating { tapeChurn = nil }
        }
        let wasPlaying = motion == .playing
        promise(.paused)
        ramp { [self] in
            if wasPlaying {
                for rate in Self.chewRates {
                    setRate(rate)
                    do { try await Task.sleep(nanoseconds: 85_000_000) } catch { return }
                }
            }
            restoreRate()
            player.pause()
        }
    }

    /// Winds the spilled tape back into the cassette, ready to play again.
    func windTapeBack() {
        guard tapeEaten, tapeChurn == nil else { return }
        sounds.play(.windBack)
        Haptics.windBack()
        tapeChurn = .winding
        withAnimation(.easeInOut(duration: 1.6)) { tapeEaten = false }
        Task {
            await pause(seconds: 1.65)
            if tapeChurn == .winding { tapeChurn = nil }
        }
    }

    /// A knock on the empty deck: there is no tape to press on.
    func knockEmptyDeck() {
        guard !hasTape else { return }
        sounds.play(.keyDown)
        Haptics.door()
    }

    /// Shows what a key asked for straight away.
    private func promise(_ wanted: TapeMotion) {
        promised = (wanted, Date())
        if motion != wanted { motion = wanted }
    }

    /// Steps of the playback rate as the capstan comes up to speed or runs
    /// down: a short slur, like a deck's motor starting and stopping.
    private static let rampUp: [Float] = [0.55, 0.7, 0.82, 0.92, 1.0]
    private static let rampDown: [Float] = [0.85, 0.7, 0.55, 0.42, 0.32]

    /// Starts a run-up or run-down, replacing any in progress.
    private func ramp(_ body: @escaping @MainActor () async -> Void) {
        rampTask?.cancel()
        rampNumber += 1
        let number = rampNumber
        rampTask = Task {
            await body()
            if number == rampNumber { rampTask = nil }
            refresh()
        }
    }

    /// Ends a run-up or run-down where it stands and puts the speed back.
    private func cancelRamp() {
        rampTask?.cancel()
        rampTask = nil
        rampNumber += 1
        restoreRate()
    }

    /// Changes the speed, but only of music that is playing: setting the
    /// rate of a paused player starts it.
    private func setRate(_ rate: Float) {
        guard player.state.playbackStatus == .playing else { return }
        player.state.playbackRate = rate
    }

    private func restoreRate() {
        if player.state.playbackStatus == .playing, player.state.playbackRate != 1 {
            player.state.playbackRate = 1
        }
    }

    /// Plays, letting the tape run up to speed.
    private func startTape(slur wanted: Bool = true) {
        ramp { [self] in
            do {
                let slur = wanted && Prefs.isOn(Prefs.tapeRamp)
                let from = player.playbackTime
                try await player.play()
                // Stop was pressed while the music was still starting.
                if Task.isCancelled {
                    if promised?.motion == .paused { player.pause() }
                    return
                }
                guard slur else { return }
                setRate(Self.rampUp[0])
                // Apple Music can take a moment to start after play()
                // returns. Wait until the tape is really moving, so the
                // motor is heard together with the music, not before it.
                var waited = 0
                while player.playbackTime <= from + 0.02, waited < 40 {
                    try await Task.sleep(nanoseconds: 25_000_000)
                    waited += 1
                }
                // The motor is heard running down on stop, but not running
                // up on play: over the start of a song it only got in the way.
                for rate in Self.rampUp.dropFirst() {
                    try await Task.sleep(nanoseconds: 70_000_000)
                    setRate(rate)
                }
            } catch is CancellationError {
                // Replaced by another run; that one looks after the speed.
            } catch {
                promised = nil
                errorMessage = await explain(error, doing: "The tape would not play.")
            }
            if !Task.isCancelled { restoreRate() }
        }
    }

    /// Moves to a place in the song that is playing, given as a part of
    /// its length from 0 to 1: the timeline being dragged.
    func scrub(to fraction: Double) {
        guard hasTape, !swapping, !tapeJammed, duration > 0 else { return }
        // Short of the very end, so the song is not skipped by a slip.
        let time = min(max(0, fraction), 0.995) * duration
        player.playbackTime = time
        elapsed = time
        lastKeyPress = Date()
    }

    /// The clunk and click of a key that does nothing to the tape, such
    /// as the one that opens Settings.
    func keyClick() {
        pressFeedback()
    }

    /// Stops, letting the tape run down first.
    private func stopTape() {
        ramp { [self] in
            if Prefs.isOn(Prefs.tapeRamp), player.state.playbackStatus == .playing {
                // The music reaches the speaker a little after the player
                // is told to slow, so the motor sound waits for the first
                // step to be heard, and the tape stops as the sound ends.
                for (step, rate) in Self.rampDown.enumerated() {
                    setRate(rate)
                    if step == 1 { sounds.play(.motorDown) }
                    do { try await Task.sleep(nanoseconds: 80_000_000) } catch { return }
                }
            }
            // Back to full speed in the same breath as the pause, so the
            // slow rate is never left behind for the next thing that plays
            // (headphone keys, the lock screen), and nothing is heard of it.
            restoreRate()
            player.pause()
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
        guard hasTape, !swapping else { return }
        if motion == .playing {
            if player.state.playbackStatus == .playing { events.send(.stopped) }
            promise(.paused)
            stopTape()
        } else if motion == .paused, !sideEnded {
            promise(.playing)
            startTape()
        }
    }

    /// The eject key. On the closed phone it only opens the shelf, so the
    /// music carries on until another tape is chosen. Where `removeTape` is
    /// set it takes the tape out.
    func ejectKey(removeTape: Bool) {
        lastKeyPress = Date()
        // Not while a tape is being put in or turned over.
        if removeTape, hasTape, !swapping {
            eject()
        } else {
            sounds.play(.keyDown)
            Haptics.keyDown()
        }
    }

    /// Rewind and fast forward: a tap skips a song, a hold winds the tape.
    func seekKeyDown(forward: Bool) {
        pressFeedback()
        guard hasTape, !swapping, !tapeJammed else { return }
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
        guard sideIndex < sides.count else { return }
        let side = sides[sideIndex]
        guard side.duration > 0 else { return }
        keyWound = true
        // Playing now, or about to be once the last wind has been tidied up
        windResume = motion == .playing || resumePending
        finishTask?.cancel()
        finishTask = nil
        resumePending = false
        promised = nil
        cancelRamp()
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
            sounds.setWindSpeed((rate - 12) / 33)
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
            Haptics.endOfSide()
            refresh()
            return
        }
        let resume = windResume
        let position = windPosition
        events.send(.wound)
        resumePending = resume
        finishTask = Task {
            do {
                let spot = side.locate(position)
                setQueue(side: side, startAt: spot.index)
                try await player.prepareToPlay()
                guard !Task.isCancelled else { return }
                if spot.offset > 0 { player.playbackTime = spot.offset }
                if resume { try await player.play() }
            } catch {
                if !Task.isCancelled {
                    errorMessage = await explain(error, doing: "The tape would not play.")
                }
            }
            guard !Task.isCancelled else { return }
            resumePending = false
            finishTask = nil
            refresh()
        }
    }

    /// The press turned out not to be a press (on the click wheel, the thumb
    /// moved on round). Nothing is skipped; a wind in progress is ended.
    func seekKeyCancel() {
        seekTask?.cancel()
        seekTask = nil
        if winding { finishWinding() }
        keyWound = false
    }

    func seekKeyUp(forward: Bool) {
        seekTask?.cancel()
        seekTask = nil
        guard hasTape, !swapping else { return }
        if winding {
            finishWinding()
        } else if keyWound {
            // The tape ran out while the key was still held.
            keyWound = false
        } else {
            events.send(.skipped)
            run {
                if forward {
                    try await self.player.skipToNextEntry()
                } else {
                    try await self.player.skipToPreviousEntry()
                }
            }
        }
    }

    /// A message for something that went wrong, in plain words. The usual
    /// cause of music not playing is no Apple Music subscription, so that is
    /// checked first and said outright.
    func explain(_ error: Error, doing what: String) async -> String {
        if let subscription = try? await MusicSubscription.current, !subscription.canPlayCatalogContent {
            return "\(what) Cassety plays music from Apple Music, and this Apple Account has no active Apple Music subscription. Music you have bought or added to your library may still play."
        }
        return "\(what) \(error.localizedDescription)"
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
        case .fastForward: sounds.setLoop(.whir)
        case .rewind: sounds.setLoop(.reverse)
        case .paused, .stopped: sounds.setLoop(nil)
        }
        pausedSince = motion == .paused ? Date() : nil
        // Music started from somewhere else (headphones, the lock screen):
        // the tape cannot be both playing and in a heap.
        if motion == .playing, tapeEaten, rampTask == nil { tapeEaten = false }
        if motion == .playing {
            waitingForLid = false
            sideEnded = false
        }
        // The music stopped on its own: the play key pops back up.
        if old == .playing, motion == .stopped || motion == .paused, !promiseLapsed,
           Date().timeIntervalSince(lastKeyPress) > 1.0 {
            sounds.play(.keyUp)
            Haptics.keyUp()
            // If that was the last track on this side, the tape has run out.
            if !swapping, sideIndex < sides.count,
               trackIndex >= sides[sideIndex].entries.count - 1,
               duration <= 0 || duration - elapsed < 3 || elapsed < 1.5 {
                sideEnded = true
                progress = 1
                Haptics.endOfSide()
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

    #if DEBUG
    /// For taking pictures of the app in the simulator, which cannot play
    /// Apple Music: a made-up tape, shown as playing. Launch with the
    /// argument `-demoTape`. Never in the build that goes to the App Store.
    private var demo = false

    func loadDemoTape() {
        demo = true
        authStatus = .authorized
        tapeTitle = "Summer Drive '86"
        tapeSubtitle = "Mixed for the road"
        printedLabel = false
        trackTitle = "Neon Coastline"
        trackArtist = "The Night Shift"
        elapsed = 74
        duration = 221
        sideIndex = 0
        progress = 0.34
        hasTape = true
        motion = .playing
    }
    #endif

    /// Mirrors the system player's state into published properties.
    private func refresh() {
        #if DEBUG
        if demo { return }
        #endif
        guard hasTape, !swapping else {
            if !hasTape {
                if motion != .stopped { motion = .stopped }
                sounds.keepAlive = false
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

        var newMotion: TapeMotion
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
        // Music started by any other route after a run-down plays at full speed.
        if !ramping, player.state.playbackStatus == .playing, player.state.playbackRate < 0.99 {
            player.state.playbackRate = 1
        }

        // A key's promise holds until the player agrees, or for two seconds
        // if it never does.
        if let promised {
            if newMotion == promised.motion {
                self.promised = nil
            } else if Date().timeIntervalSince(promised.since) > 2 {
                self.promised = nil
                promiseLapsed = true
            } else {
                newMotion = promised.motion
            }
        }
        if newMotion != motion { motion = newMotion }
        promiseLapsed = false
        // The music is really playing, not just promised.
        let reallyPlaying = player.state.playbackStatus == .playing
        if reallyPlaying, !wasReallyPlaying { events.send(.played) }
        wasReallyPlaying = reallyPlaying

        let time = player.playbackTime
        if time.isFinite, abs(time - elapsed) > 0.05 { elapsed = max(time, 0) }

        if let entry = player.queue.currentEntry, sideIndex < sides.count {
            let side = sides[sideIndex]
            if entry.id != lastEntryID {
                lastEntryID = entry.id
                let known = MPMusicPlayerController.applicationQueuePlayer.nowPlayingItem?.beatsPerMinute ?? 0
                let tempo = (50...220).contains(known) ? Double(known) : Self.defaultTempo
                if tempo != beatsPerMinute { beatsPerMinute = tempo }
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

    /// Keeps the hiss going with the music behind the lock screen, and lets it
    /// go once the tape has been stopped or left paused for ten minutes.
    private func syncLockScreen() {
        let parked = motion == .paused
            && Date().timeIntervalSince(pausedSince ?? Date()) > 600
        sounds.keepAlive = motion != .stopped && !parked
    }
}
