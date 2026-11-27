import ActivityKit
import Foundation

/// Owns the Live Activity that puts the tape on the lock screen.
@MainActor
final class LockScreenTape {
    private typealias State = TapeActivityAttributes.ContentState

    private var activity: Activity<TapeActivityAttributes>?
    private var sent: State?
    private var sentElapsed: TimeInterval = 0
    private var sentAt = Date.distantPast
    private var lastAttempt = Date.distantPast

    init() {
        // Clear out anything left over from a previous run of the app.
        Task {
            for old in Activity<TapeActivityAttributes>.activities {
                await old.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Call often. Only talks to the system when something worth showing changed.
    func sync(title: String, subtitle: String, isPlaying: Bool,
              elapsed: TimeInterval, duration: TimeInterval,
              tapeProgress: Double, side: String, tint: [Double]?, theme: [Double]?) {
        let now = Date()
        // Swiped away on the lock screen: forget it, so a fresh one can start.
        if let activity, activity.activityState == .dismissed || activity.activityState == .ended {
            self.activity = nil
        }
        // Do not pester the system if starting one keeps failing.
        if activity == nil {
            guard now.timeIntervalSince(lastAttempt) > 5 else { return }
            lastAttempt = now
        }
        let start = now.addingTimeInterval(-elapsed)
        // With no known length, let the lock screen clock run for a few hours.
        let end = start.addingTimeInterval(duration > elapsed ? duration : elapsed + 4 * 3600)
        let state = State(title: title, subtitle: subtitle, isPlaying: isPlaying,
                          trackStart: start, trackEnd: end, progress: tapeProgress,
                          side: side, tint: tint, theme: theme)

        if let sent, activity != nil {
            let sameLabel = sent.title == title && sent.subtitle == subtitle
                && sent.isPlaying == isPlaying && sent.side == side && sent.theme == theme
            let age = now.timeIntervalSince(sentAt)
            if sameLabel {
                // While playing the lock screen keeps time itself. Resend only
                // after a jump in position, or now and then to resize the reels.
                let jumped = isPlaying
                    ? abs(sent.trackStart.timeIntervalSince(start)) > 2
                    : abs(sentElapsed - elapsed) > 1
                if !(jumped && age > 1) && !(isPlaying && age > 15) { return }
            }
        }

        sent = state
        sentElapsed = elapsed
        sentAt = now
        let content = ActivityContent(state: state, staleDate: nil)
        if let activity {
            Task { await activity.update(content) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            // Starting needs the app on screen. If it is not, this fails quietly
            // and the next sync tries again.
            activity = try? Activity.request(attributes: TapeActivityAttributes(),
                                             content: content, pushType: nil)
        }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        sent = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
