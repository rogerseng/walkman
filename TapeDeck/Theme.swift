import SwiftUI
import UIKit

/// A theme is what the closed phone looks like: which player it is, and what
/// colour its case is. It is the one thing people choose; behind it are two
/// stored settings, the player and the skin.
struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    /// "tape" or "mp3".
    let player: String
    let skin: Skin

    /// The themes a person can choose from. The two click wheel themes are
    /// only in builds run from Xcode (see `Skin.includesClickWheel`).
    static var offered: [Theme] {
        var list = [
            Theme(id: "tape-neon", name: "Tape player", detail: "Retro 80s", player: "tape", skin: .neon),
            Theme(id: "tape-smoke", name: "Tape player", detail: "Black", player: "tape", skin: .smoke),
            Theme(id: "tape-yellow", name: "Tape player", detail: "Yellow", player: "tape", skin: .yellow),
            Theme(id: "tape-blue", name: "Tape player", detail: "Blue", player: "tape", skin: .blue),
            Theme(id: "mp3-neon", name: "MP3 player", detail: "Retro 80s", player: "mp3", skin: .neon),
            Theme(id: "mp3-smoke", name: "MP3 player", detail: "Black", player: "mp3", skin: .smoke)
        ]
        if Skin.includesClickWheel {
            list.append(Theme(id: "wheel-black", name: "Click wheel", detail: "Black",
                              player: "mp3", skin: .wheelBlack))
            list.append(Theme(id: "wheel-silver", name: "Click wheel", detail: "Silver",
                              player: "mp3", skin: .wheelSilver))
        }
        return list
    }

    /// The theme the stored settings add up to.
    static func current(player: String, skinName: String) -> Theme {
        let all = offered
        let skin = Skin(rawValue: skinName) ?? Skin.standard
        if skin.isWheel, let wheel = all.first(where: { $0.skin == skin }) { return wheel }
        let colour: Skin = skin.isWheel ? Skin.standard : skin
        // A colour the player does not come in falls back to that player's first.
        return all.first { $0.player == player && $0.skin == colour }
            ?? all.first { $0.player == player } ?? all[0]
    }
}

/// The list of themes, for a settings form or the introduction. Tapping one
/// applies it at once.
struct ThemePicker: View {
    @AppStorage(Prefs.player) private var player = "tape"
    @AppStorage(Prefs.skin) private var skinName = Skin.standard.rawValue

    var body: some View {
        let chosen = Theme.current(player: player, skinName: skinName)
        ForEach(Theme.offered) { theme in
            Button {
                Haptics.detent()
                player = theme.player
                skinName = theme.skin.rawValue
            } label: {
                HStack(spacing: 12) {
                    SkinSwatch(skin: theme.skin, chosen: theme == chosen)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(theme.name).foregroundColor(.primary)
                        Text(theme.detail).font(.footnote).foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                    if theme == chosen {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(theme.name), \(theme.detail)")
            .accessibilityAddTraits(theme == chosen ? .isSelected : [])
        }
    }
}

/// Web pages the app links to from Settings. The pages are in the `website`
/// folder. A row is shown only when its address is set.
enum AppLinks {
    static let privacyPolicy = "https://cassety.com/privacy.html"
    static let support = "https://cassety.com/support.html"
}

/// The app's three typefaces, so every screen uses them the same way.
///  - Display: Righteous, the face of the wordmark and the website. Headings,
///    buttons, and lettering moulded or engraved on the players.
///  - Marker: Permanent Marker. Anything written on a tape: its name, on
///    the label, the shelf spine, the lock screen and everywhere else a
///    tape is named.
///  - Everything else, the reading text, is the system font.
enum Typeface {
    static let displayName = "Righteous-Regular"
    static let markerName = "PermanentMarker-Regular"

    /// Scales with the reader's text size.
    static func display(_ size: CGFloat) -> Font { .custom(displayName, size: size) }
    /// Fixed, for lettering that is part of the drawing.
    static func displayFixed(_ size: CGFloat) -> Font { .custom(displayName, fixedSize: size) }
    static func marker(_ size: CGFloat) -> Font { .custom(markerName, size: size) }
    static func markerFixed(_ size: CGFloat) -> Font { .custom(markerName, fixedSize: size) }

    /// Navigation bar titles in the display face, as on the website.
    @MainActor
    static func styleNavigationBars() {
        let bar = UINavigationBar.appearance()
        if let inline = UIFont(name: displayName, size: 19) {
            bar.titleTextAttributes = [.font: inline]
        }
        if let large = UIFont(name: displayName, size: 34) {
            bar.largeTitleTextAttributes = [.font: large]
        }
    }
}
