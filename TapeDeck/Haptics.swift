import UIKit

/// The feel of the deck under your thumb. Each mechanical event has its own
/// tap, so a key going down, a key coming up and the door are told apart.
@MainActor
enum Haptics {
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let notch = UIImpactFeedbackGenerator(style: .rigid)

    /// Where the on/off setting is kept. Settings writes it; this reads it.
    static let settingKey = Prefs.haptics
    private static var on: Bool { Prefs.isOn(Prefs.haptics) }

    /// Wakes the haptic engine so the first tap is not late.
    static func warmUp() {
        rigid.prepare()
        light.prepare()
        heavy.prepare()
        medium.prepare()
        notch.prepare()
    }

    /// A key driven down to its latch: a heavy thud as it gives, then the
    /// sharp knock of it hitting the bottom.
    static func keyDown() {
        guard on else { return }
        heavy.impactOccurred(intensity: 1.0)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 45_000_000)
            rigid.impactOccurred(intensity: 1.0)
            medium.prepare()
            heavy.prepare()
        }
    }

    /// A key springing back up.
    static func keyUp() {
        guard on else { return }
        medium.impactOccurred(intensity: 0.9)
        heavy.prepare()
    }

    /// The cassette door opening or shutting.
    static func door() {
        guard on else { return }
        heavy.impactOccurred(intensity: 1.0)
    }

    /// The cassette dropping into place.
    static func seat() {
        guard on else { return }
        rigid.impactOccurred(intensity: 0.6)
    }

    /// The deck chewing the tape: a run of uneven knocks as it snags.
    static func chew() {
        guard on else { return }
        heavy.impactOccurred(intensity: 1.0)
        Task { @MainActor in
            for (wait, strength) in [(70, 0.7), (60, 1.0), (110, 0.5), (80, 0.9), (140, 0.6), (120, 1.0)] {
                try? await Task.sleep(nanoseconds: UInt64(wait) * 1_000_000)
                rigid.impactOccurred(intensity: CGFloat(strength))
            }
            heavy.prepare()
        }
    }

    /// The tape being wound back in: quick light ticks, then it seats.
    static func windBack() {
        guard on else { return }
        Task { @MainActor in
            for _ in 0..<14 {
                light.impactOccurred(intensity: 0.6)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            rigid.impactOccurred(intensity: 0.8)
        }
    }

    /// The volume fader clicking into a notch.
    static func detent() {
        guard on else { return }
        notch.impactOccurred(intensity: 0.85)
        notch.prepare()
    }

    /// The tape has run out: the system's own "attention" pattern.
    static func endOfSide() {
        guard on else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// One beat of the motor while the tape winds.
    static func windTick() {
        guard on else { return }
        soft.impactOccurred(intensity: 0.45)
    }
}
