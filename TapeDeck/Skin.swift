import SwiftUI

/// The colour of the player's case. The cassette, the keys and the fader cap
/// are the same in every skin; what changes is the plastic around them and
/// the lettering moulded into it.
enum Skin: String, CaseIterable, Identifiable {
    /// Dark smoked plastic you can see the tape through.
    case smoke
    /// Bright yellow, like the splash-proof players of the eighties.
    case yellow

    var id: String { rawValue }

    static var current: Skin {
        Skin(rawValue: UserDefaults.standard.string(forKey: Prefs.skin) ?? "") ?? .smoke
    }

    var name: String {
        switch self {
        case .smoke: return "Smoke"
        case .yellow: return "Yellow"
        }
    }

    /// The casing over the tape, top left to bottom right. Smoke lets the
    /// tape show through dimly; yellow is very nearly solid.
    var casing: [Color] {
        switch self {
        case .smoke:
            return [Color(white: 0.16).opacity(0.86), Color(white: 0.08).opacity(0.86),
                    Color(white: 0.05).opacity(0.86)]
        case .yellow:
            return [Color(red: 1.00, green: 0.85, blue: 0.20).opacity(0.96),
                    Color(red: 0.98, green: 0.77, blue: 0.09).opacity(0.96),
                    Color(red: 0.91, green: 0.68, blue: 0.04).opacity(0.96)]
        }
    }

    /// The solid panel that carries the fader and keys, top to bottom.
    var panel: [Color] {
        switch self {
        case .smoke:
            return [Color(white: 0.20), Color(white: 0.13), Color(white: 0.09)]
        case .yellow:
            return [Color(red: 0.99, green: 0.81, blue: 0.14), Color(red: 0.95, green: 0.73, blue: 0.07),
                    Color(red: 0.87, green: 0.64, blue: 0.03)]
        }
    }

    /// Lettering and marks cut into the plastic, and the thin edge of light
    /// or shadow that makes them read as cut.
    var engraving: Color {
        self == .smoke ? Color.white.opacity(0.55) : Color.black.opacity(0.60)
    }

    var engravingEdge: Color {
        self == .smoke ? Color.black.opacity(0.8) : Color.white.opacity(0.45)
    }

    /// Which way the engraving's edge falls: shadow above on dark plastic,
    /// light below on pale.
    var engravingEdgeOffset: CGFloat { self == .smoke ? -0.7 : 0.7 }

    /// The faint Cassety name on the case.
    var mark: Color {
        self == .smoke ? Color.white.opacity(0.22) : Color.black.opacity(0.20)
    }

    /// Lines of text printed on the case, such as the song under the window.
    var note: Color {
        self == .smoke ? Color.white.opacity(0.85) : Color.black.opacity(0.78)
    }

    /// The clock and status icons at the top of the Duo's rail are drawn in
    /// white, so a pale case needs a dark plate behind them.
    var needsStatusPlate: Bool { self == .yellow }

    /// For the picker in settings.
    var swatch: Color {
        self == .smoke ? Color(white: 0.14) : Color(red: 0.98, green: 0.77, blue: 0.09)
    }
}
