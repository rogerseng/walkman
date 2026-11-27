import Foundation

/// The settings, by the key each is stored under. Everything defaults to on
/// except automatic flipping.
enum Prefs {
    static let sounds = "soundEffectsOn"
    static let hiss = "tapeHissOn"
    static let haptics = "hapticsOn"
    static let glare = "glareOn"
    static let levelLights = "levelLightsOn"
    static let playOnClose = "playOnCloseOn"
    static let autoFlip = "autoFlipOn"
    /// The tape slurs up to speed on play and down to a stop on stop.
    static let tapeRamp = "tapeRampOn"
    /// Kept on each device separately, so one can opt out without the others.
    static let iCloudSync = "iCloudSyncOn"
    /// Which skin the case wears: a `Skin` raw value.
    static let skin = "skin"
    /// Which player the closed phone is: "tape" or "mp3".
    static let player = "player"
    /// Set once the introduction has been seen.
    static let introSeen = "introSeen"

    static func isOn(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? (key != autoFlip)
    }
}
