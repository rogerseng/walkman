import ActivityKit
import AppIntents
import Foundation
import MusicKit

/// What the lock screen tape shows. Shared by the app, which sends it, and the
/// widget extension, which draws it.
struct TapeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var subtitle: String
        var isPlaying: Bool
        /// When the current track would have been at 0:00, and when it will end.
        /// The lock screen runs its own clock between the two.
        var trackStart: Date
        var trackEnd: Date
        /// 0...1 through the current side of the tape when this was sent.
        /// The reels are drawn from this.
        var progress: Double
        /// "A" or "B".
        var side: String
        /// Red, green and blue of the cover art's colour, if it has one.
        var tint: [Double]?
    }
}

// The keys on the lock screen tape. The system runs these inside the app, not
// the widget, so they can reach the music player.

struct TogglePlayTapeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Play or Pause Tape"

    func perform() async throws -> some IntentResult {
        let player = ApplicationMusicPlayer.shared
        if player.state.playbackStatus == .playing {
            player.pause()
        } else {
            try await player.play()
        }
        return .result()
    }
}

struct NextTapeTrackIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Next Track on Tape"

    func perform() async throws -> some IntentResult {
        try await ApplicationMusicPlayer.shared.skipToNextEntry()
        return .result()
    }
}

struct PreviousTapeTrackIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Previous Track on Tape"

    func perform() async throws -> some IntentResult {
        try await ApplicationMusicPlayer.shared.skipToPreviousEntry()
        return .result()
    }
}
