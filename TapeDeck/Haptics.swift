import UIKit

/// The feel of the deck under your thumb. Each mechanical event has its own
/// tap, so a key going down, a key coming up and the door are told apart.
@MainActor
enum Haptics {
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)

    /// Wakes the haptic engine so the first tap is not late.
    static func warmUp() {
        rigid.prepare()
        light.prepare()
        heavy.prepare()
    }

    /// A key driven down to its latch.
    static func keyDown() {
        rigid.impactOccurred(intensity: 1.0)
        light.prepare()
    }

    /// A key springing back up.
    static func keyUp() {
        light.impactOccurred(intensity: 0.7)
        rigid.prepare()
    }

    /// The cassette door opening or shutting.
    static func door() {
        heavy.impactOccurred(intensity: 1.0)
    }

    /// The cassette dropping into place.
    static func seat() {
        rigid.impactOccurred(intensity: 0.6)
    }

    /// One beat of the motor while the tape winds.
    static func windTick() {
        soft.impactOccurred(intensity: 0.45)
    }
}
