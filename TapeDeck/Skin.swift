import SwiftUI

/// What the closed phone looks like. Two are cassette players, differing in
/// the colour of the case. Two are click-wheel players: a small screen of
/// menus above a wheel you turn to scroll.
enum Skin: String, CaseIterable, Identifiable {
    /// Cassette player in dark smoked plastic you can see the tape through.
    case smoke
    /// Cassette player in bright yellow, like the splash-proof ones of the eighties.
    case yellow
    /// Eighties neon: deep purple with hot pink and cyan, and a band of stripes.
    case neon
    /// Cassette player in blue painted metal with a silver side, like the
    /// first pocket stereos of 1979.
    case blue
    /// Click-wheel player in black.
    case wheelBlack
    /// Click-wheel player in silver with a white wheel.
    case wheelSilver

    var id: String { rawValue }

    /// The skin a new install starts with.
    static let standard: Skin = .neon

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
        let stored = Skin(rawValue: UserDefaults.standard.string(forKey: Prefs.skin) ?? "") ?? standard
        return offered.contains(stored) ? stored : standard
    }

    var name: String {
        switch self {
        case .smoke: return "Black cassette player"
        case .yellow: return "Yellow cassette player"
        case .neon: return "Retro 80s cassette player"
        case .blue: return "Blue cassette player"
        case .wheelBlack: return "Black click wheel"
        case .wheelSilver: return "Silver click wheel"
        }
    }

    /// True for the click-wheel players, which replace the whole deck.
    var isWheel: Bool { self == .wheelBlack || self == .wheelSilver }

    private var isPale: Bool { self == .yellow || self == .wheelSilver }

    /// The blue player's case is dark but its side panel is pale silver, so
    /// what sits on the panel is treated as on a pale case.
    private var hasPalePanel: Bool { isPale || self == .blue }

    /// The casing over the tape, top left to bottom right. Smoke lets the
    /// tape show through dimly; yellow is very nearly solid.
    var casing: [Color] {
        if self == .yellow {
            return [Color(red: 1.00, green: 0.85, blue: 0.20).opacity(0.96),
                    Color(red: 0.98, green: 0.77, blue: 0.09).opacity(0.96),
                    Color(red: 0.91, green: 0.68, blue: 0.04).opacity(0.96)]
        }
        if self == .blue {
            return [Color(red: 0.33, green: 0.47, blue: 0.68).opacity(0.97),
                    Color(red: 0.24, green: 0.37, blue: 0.58).opacity(0.97),
                    Color(red: 0.17, green: 0.28, blue: 0.47).opacity(0.97)]
        }
        if self == .neon {
            return [Color(red: 0.38, green: 0.10, blue: 0.58).opacity(0.93),
                    Color(red: 0.22, green: 0.06, blue: 0.44).opacity(0.93),
                    Color(red: 0.09, green: 0.03, blue: 0.26).opacity(0.93)]
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
        if self == .blue {
            return [Color(white: 0.86), Color(white: 0.76), Color(white: 0.64)]
        }
        if self == .neon {
            return [Color(red: 0.22, green: 0.08, blue: 0.42), Color(red: 0.14, green: 0.04, blue: 0.31),
                    Color(red: 0.07, green: 0.02, blue: 0.19)]
        }
        return [Color(white: 0.20), Color(white: 0.13), Color(white: 0.09)]
    }

    /// The two neon colours.
    static let hotPink = Color(red: 1.0, green: 0.24, blue: 0.64)
    static let cyan = Color(red: 0.30, green: 0.94, blue: 1.0)

    /// The play key: orange, or hot pink on the neon skin. Face when up,
    /// face when pressed in, and the side of the key.
    var accentUp: [Color] {
        self == .neon
            ? [Color(red: 1.0, green: 0.40, blue: 0.74), Color(red: 0.92, green: 0.14, blue: 0.54)]
            : [Color(red: 0.99, green: 0.56, blue: 0.18), Color(red: 0.88, green: 0.40, blue: 0.08)]
    }

    var accentDown: [Color] {
        self == .neon
            ? [Color(red: 0.62, green: 0.08, blue: 0.37), Color(red: 0.50, green: 0.05, blue: 0.30)]
            : [Color(red: 0.66, green: 0.28, blue: 0.05), Color(red: 0.55, green: 0.22, blue: 0.03)]
    }

    var accentWall: [Color] {
        self == .neon
            ? [Color(red: 0.56, green: 0.06, blue: 0.33), Color(red: 0.32, green: 0.03, blue: 0.20)]
            : [Color(red: 0.62, green: 0.27, blue: 0.05), Color(red: 0.40, green: 0.16, blue: 0.02)]
    }

    /// The cut edge of the tape window, from its top left round to its
    /// bottom right. On the neon skin it glows.
    var windowEdge: [Color] {
        self == .neon
            ? [Self.hotPink, Self.cyan, Self.hotPink]
            : [Color.white.opacity(0.75), Color.white.opacity(0.18), Color.white.opacity(0.45)]
    }

    /// Whether the case carries the band of eighties stripes.
    var hasStripes: Bool { self == .neon }

    /// Lettering and marks cut into the plastic, and the thin edge of light
    /// or shadow that makes them read as cut.
    var engraving: Color {
        if self == .neon { return Self.cyan.opacity(0.85) }
        return hasPalePanel ? Color.black.opacity(0.60) : Color.white.opacity(0.55)
    }

    var engravingEdge: Color {
        hasPalePanel ? Color.white.opacity(0.45) : Color.black.opacity(0.8)
    }

    /// Which way the engraving's edge falls: shadow above on dark plastic,
    /// light below on pale.
    var engravingEdgeOffset: CGFloat { hasPalePanel ? 0.7 : -0.7 }

    /// The faint Cassety name on the case.
    var mark: Color {
        if self == .neon { return Self.hotPink.opacity(0.85) }
        if self == .blue { return Color.white.opacity(0.55) }
        return isPale ? Color.black.opacity(0.20) : Color.white.opacity(0.22)
    }

    /// Lines of text printed on the case, such as the song under the window.
    var note: Color {
        isPale ? Color.black.opacity(0.78) : Color.white.opacity(0.85)
    }

    /// The clock and status icons at the top of the Duo's rail are drawn in
    /// white, so a pale case needs a dark plate behind them.
    var needsStatusPlate: Bool { hasPalePanel }

    /// A word in outline lettering above the tape window, if the case has one.
    var caseWord: String? { self == .blue ? "STEREO" : nil }

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
            ? [Color(white: 0.90), Color(white: 0.84)]
            : [Color(white: 0.15), Color(white: 0.11)]
    }

    /// For the picker in settings.
    var swatch: Color {
        switch self {
        case .smoke: return Color(white: 0.14)
        case .yellow: return Color(red: 0.98, green: 0.77, blue: 0.09)
        case .neon: return Color(red: 0.86, green: 0.16, blue: 0.62)
        case .blue: return Color(red: 0.24, green: 0.37, blue: 0.58)
        case .wheelBlack: return Color(white: 0.04)
        case .wheelSilver: return Color(white: 0.80)
        }
    }
}
