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
    /// Cassette player in blue painted metal with a silver side and a red
    /// play key.
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

    /// What the personal-build players are called. The words are left out
    /// of the build that goes to the App Store altogether.
    static let wheelWord: String = {
        #if DEBUG
        return "click wheel"
        #else
        return "player"
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
        case .wheelBlack: return "Black \(Self.wheelWord)"
        case .wheelSilver: return "Silver \(Self.wheelWord)"
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

    /// The play key: orange, hot pink on the neon skin, or red on the blue
    /// one. Face when up, face when pressed in, and the side of the key.
    var accentUp: [Color] {
        switch self {
        case .neon: return [Color(red: 1.0, green: 0.40, blue: 0.74), Color(red: 0.92, green: 0.14, blue: 0.54)]
        case .blue: return [Color(red: 0.95, green: 0.27, blue: 0.24), Color(red: 0.80, green: 0.13, blue: 0.13)]
        default: return [Color(red: 0.99, green: 0.56, blue: 0.18), Color(red: 0.88, green: 0.40, blue: 0.08)]
        }
    }

    var accentDown: [Color] {
        switch self {
        case .neon: return [Color(red: 0.62, green: 0.08, blue: 0.37), Color(red: 0.50, green: 0.05, blue: 0.30)]
        case .blue: return [Color(red: 0.58, green: 0.09, blue: 0.09), Color(red: 0.46, green: 0.06, blue: 0.06)]
        default: return [Color(red: 0.66, green: 0.28, blue: 0.05), Color(red: 0.55, green: 0.22, blue: 0.03)]
        }
    }

    var accentWall: [Color] {
        switch self {
        case .neon: return [Color(red: 0.56, green: 0.06, blue: 0.33), Color(red: 0.32, green: 0.03, blue: 0.20)]
        case .blue: return [Color(red: 0.55, green: 0.08, blue: 0.08), Color(red: 0.34, green: 0.04, blue: 0.04)]
        default: return [Color(red: 0.62, green: 0.27, blue: 0.05), Color(red: 0.40, green: 0.16, blue: 0.02)]
        }
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
        return isPale ? Color.black.opacity(0.34) : Color.white.opacity(0.36)
    }

    /// Lines of text printed on the case, such as the song under the window.
    var note: Color {
        isPale ? Color.black.opacity(0.78) : Color.white.opacity(0.85)
    }

    /// The clock and status icons at the top of the Duo's rail are drawn in
    /// white, so a pale case needs a dark plate behind them.
    var needsStatusPlate: Bool { hasPalePanel }

    /// A word in outline lettering above the tape window, if the case has one.
    var caseWord: String? { nil }

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

/// The colours that go with a skin everywhere outside the player itself: the
/// shelf, the open phone, the lock screen tape and the buttons. So whichever
/// case is chosen, the whole app is in its colours.
struct PlayerTheme: Equatable {
    /// Red, green and blue, 0...1.
    typealias RGB = [Double]

    /// Behind lists and screens.
    let background: RGB
    /// The open phone's backdrop, top to bottom.
    let dusk: [RGB]
    /// Buttons, icons and the play key's colour.
    let accent: RGB
    /// Headings and quieter highlights.
    let secondary: RGB
    /// Text on an accent-coloured button.
    let accentInk: RGB

    static func color(_ rgb: RGB) -> Color { Color(red: rgb[0], green: rgb[1], blue: rgb[2]) }

    var backgroundColor: Color { Self.color(background) }
    var duskColors: [Color] { dusk.map(Self.color) }
    var accentColor: Color { Self.color(accent) }
    var secondaryColor: Color { Self.color(secondary) }
    var accentInkColor: Color { Self.color(accentInk) }

    /// Nine numbers for the lock screen: the background, the accent, and the
    /// colour for symbols drawn on the accent.
    var lockScreen: [Double] { background + accent + accentInk }
}

extension Skin {
    private static let orange: PlayerTheme.RGB = [0.99, 0.56, 0.18]
    private static let darkInk: PlayerTheme.RGB = [0.10, 0.04, 0.02]

    var theme: PlayerTheme {
        switch self {
        case .neon:
            return PlayerTheme(background: [0.06, 0.02, 0.15],
                               dusk: [[0.07, 0.02, 0.18], [0.20, 0.06, 0.40], [0.55, 0.12, 0.50]],
                               accent: [1.0, 0.24, 0.64], secondary: [0.30, 0.94, 1.0],
                               accentInk: [0.10, 0.02, 0.13])
        case .smoke, .wheelBlack:
            return PlayerTheme(background: [0.05, 0.05, 0.06],
                               dusk: [[0.04, 0.04, 0.05], [0.11, 0.11, 0.12], [0.24, 0.15, 0.08]],
                               accent: Self.orange, secondary: [0.80, 0.80, 0.82],
                               accentInk: Self.darkInk)
        case .yellow:
            return PlayerTheme(background: [0.09, 0.07, 0.02],
                               dusk: [[0.08, 0.06, 0.01], [0.22, 0.16, 0.03], [0.58, 0.42, 0.04]],
                               accent: [1.0, 0.80, 0.12], secondary: [1.0, 0.92, 0.62],
                               accentInk: [0.12, 0.09, 0.0])
        case .blue:
            return PlayerTheme(background: [0.04, 0.07, 0.15],
                               dusk: [[0.04, 0.07, 0.15], [0.12, 0.20, 0.36], [0.30, 0.42, 0.62]],
                               accent: [0.95, 0.30, 0.27], secondary: [0.80, 0.86, 0.94],
                               accentInk: [0.10, 0.01, 0.01])
        case .wheelSilver:
            return PlayerTheme(background: [0.07, 0.07, 0.08],
                               dusk: [[0.07, 0.07, 0.08], [0.20, 0.20, 0.22], [0.45, 0.46, 0.50]],
                               accent: [0.35, 0.62, 1.0], secondary: [0.86, 0.87, 0.90],
                               accentInk: [0.02, 0.05, 0.12])
        }
    }
}

private struct PlayerThemeKey: EnvironmentKey {
    static let defaultValue = Skin.standard.theme
}

extension EnvironmentValues {
    /// The colours of the chosen skin, set once at the top of the app.
    var playerTheme: PlayerTheme {
        get { self[PlayerThemeKey.self] }
        set { self[PlayerThemeKey.self] = newValue }
    }
}

