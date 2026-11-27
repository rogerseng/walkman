import SwiftUI

/// What the closed phone looks like. Two are cassette players, differing in
/// the colour of the case. Two are click-wheel players: a small screen of
/// menus above a wheel you turn to scroll.
enum Skin: String, CaseIterable, Identifiable {
    /// Cassette player in dark smoked plastic you can see the tape through.
    case smoke
    /// Cassette player in bright yellow, like the splash-proof ones of the eighties.
    case yellow
    /// Click-wheel player in black.
    case wheelBlack
    /// Click-wheel player in silver with a white wheel.
    case wheelSilver

    var id: String { rawValue }

    /// Whether the click-wheel skins are offered. They are built and working,
    /// but Apple has removed apps whose players resembled the iPod, so they
    /// must not go to the App Store. They are on in a build run straight from
    /// Xcode onto your own phone (Debug) and off in the build that is archived
    /// and uploaded for sale (Release).
    static let includesClickWheel: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// The skins a person can choose from.
    static var offered: [Skin] {
        includesClickWheel ? allCases : allCases.filter { !$0.isWheel }
    }

    static var current: Skin {
        let stored = Skin(rawValue: UserDefaults.standard.string(forKey: Prefs.skin) ?? "") ?? .smoke
        return offered.contains(stored) ? stored : .smoke
    }

    var name: String {
        switch self {
        case .smoke: return "Smoke cassette player"
        case .yellow: return "Yellow cassette player"
        case .wheelBlack: return "Black click wheel"
        case .wheelSilver: return "Silver click wheel"
        }
    }

    /// True for the click-wheel players, which replace the whole deck.
    var isWheel: Bool { self == .wheelBlack || self == .wheelSilver }

    private var isPale: Bool { self == .yellow || self == .wheelSilver }

    /// The casing over the tape, top left to bottom right. Smoke lets the
    /// tape show through dimly; yellow is very nearly solid.
    var casing: [Color] {
        if self == .yellow {
            return [Color(red: 1.00, green: 0.85, blue: 0.20).opacity(0.96),
                    Color(red: 0.98, green: 0.77, blue: 0.09).opacity(0.96),
                    Color(red: 0.91, green: 0.68, blue: 0.04).opacity(0.96)]
        }
        return [Color(white: 0.16).opacity(0.86), Color(white: 0.08).opacity(0.86),
                Color(white: 0.05).opacity(0.86)]
    }

    /// The solid panel that carries the fader and keys, top to bottom.
    var panel: [Color] {
        if self == .yellow {
            return [Color(red: 0.99, green: 0.81, blue: 0.14), Color(red: 0.95, green: 0.73, blue: 0.07),
                    Color(red: 0.87, green: 0.64, blue: 0.03)]
        }
        return [Color(white: 0.20), Color(white: 0.13), Color(white: 0.09)]
    }

    /// Lettering and marks cut into the plastic, and the thin edge of light
    /// or shadow that makes them read as cut.
    var engraving: Color {
        isPale ? Color.black.opacity(0.60) : Color.white.opacity(0.55)
    }

    var engravingEdge: Color {
        isPale ? Color.white.opacity(0.45) : Color.black.opacity(0.8)
    }

    /// Which way the engraving's edge falls: shadow above on dark plastic,
    /// light below on pale.
    var engravingEdgeOffset: CGFloat { isPale ? 0.7 : -0.7 }

    /// The faint Cassety name on the case.
    var mark: Color {
        isPale ? Color.black.opacity(0.20) : Color.white.opacity(0.22)
    }

    /// Lines of text printed on the case, such as the song under the window.
    var note: Color {
        isPale ? Color.black.opacity(0.78) : Color.white.opacity(0.85)
    }

    /// The clock and status icons at the top of the Duo's rail are drawn in
    /// white, so a pale case needs a dark plate behind them.
    var needsStatusPlate: Bool { isPale }

    /// The body of a click-wheel player, top to bottom.
    var wheelBody: [Color] {
        self == .wheelSilver
            ? [Color(white: 0.86), Color(white: 0.78), Color(white: 0.70)]
            : [Color(white: 0.15), Color(white: 0.10), Color(white: 0.07)]
    }

    /// The wheel itself, and the lettering on it.
    var wheelRing: [Color] {
        self == .wheelSilver
            ? [Color(white: 0.99), Color(white: 0.93)]
            : [Color(white: 0.24), Color(white: 0.17)]
    }

    var wheelLettering: Color {
        self == .wheelSilver ? Color(white: 0.62) : Color(white: 0.78)
    }

    /// The button in the middle of the wheel.
    var wheelCentre: [Color] {
        self == .wheelSilver
            ? [Color(white: 0.88), Color(white: 0.74)]
            : [Color(white: 0.13), Color(white: 0.07)]
    }

    /// For the picker in settings.
    var swatch: Color {
        switch self {
        case .smoke: return Color(white: 0.14)
        case .yellow: return Color(red: 0.98, green: 0.77, blue: 0.09)
        case .wheelBlack: return Color(white: 0.04)
        case .wheelSilver: return Color(white: 0.80)
        }
    }
}
