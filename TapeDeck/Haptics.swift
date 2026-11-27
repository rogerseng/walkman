import UIKit

/// The feel of the deck under your thumb. Each mechanical event has its own
/// tap, so a key going down, a key coming up and the door are told apart.
@MainActor
enum Haptics {
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)

    /// Where the on/off setting is kept. Settings writes it; this reads it.
    static let settingKey = "hapticsOn"
    private static var on: Bool {
        UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true
    }

    /// Wakes the haptic engine so the first tap is not late.
    static func warmUp() {
        rigid.prepare()
        light.prepare()
        heavy.prepare()
    }

    /// A key driven down to its latch.
    static func keyDown() {
        guard on else { return }
        rigid.impactOccurred(intensity: 1.0)
        light.prepare()
    }

    /// A key springing back up.
    static func keyUp() {
        guard on else { return }
        light.impactOccurred(intensity: 0.7)
        rigid.prepare()
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

    /// One notch of the volume fader.
    static func detent() {
        guard on else { return }
        light.impactOccurred(intensity: 0.4)
    }

    /// One beat of the motor while the tape winds.
    static func windTick() {
        guard on else { return }
        soft.impactOccurred(intensity: 0.45)
    }
}
