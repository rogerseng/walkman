import SwiftUI

/// A light tap on each beat while music plays, for those who turn it on in
/// Settings. It keeps the same time as the speakers and the level lights:
/// the song's tempo where the music service gives one, and a steady default
/// where it does not. It is for show, since an app cannot hear the music.
struct BeatHaptic: ViewModifier {
    @EnvironmentObject private var model: PlayerModel
    @AppStorage(Prefs.beatHaptics) private var wanted = false
    @AppStorage(Prefs.haptics) private var hapticsOn = true
    @Environment(\.scenePhase) private var scenePhase

    private struct Run: Equatable {
        var on: Bool
        var tempo: Double
    }

    func body(content: Content) -> some View {
        let on = wanted && hapticsOn && scenePhase == .active
            && model.motion == .playing && !model.tapeJammed
        content.task(id: Run(on: on, tempo: model.beatsPerMinute)) {
            let tempo = max(40, min(220, model.beatsPerMinute))
            guard on else { return }
            while !Task.isCancelled {
                // Wait for the next whole beat on the clock the speakers use.
                let beat = Date().timeIntervalSinceReferenceDate * tempo / 60
                let wait = (floor(beat) + 1 - beat) * 60 / tempo
                do { try await Task.sleep(nanoseconds: UInt64(max(0.02, wait) * 1_000_000_000)) } catch { return }
                Haptics.beat()
            }
        }
    }
}
