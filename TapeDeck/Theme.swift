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
    /// The MP3 player is held back from this version. Its code stays, and
    /// turning this on brings its themes back.
    static let includesMP3 = false

    static var offered: [Theme] {
        var list = [
            Theme(id: "tape-neon", name: "Tape deck", detail: "Retro 80s", player: "tape", skin: .neon),
            Theme(id: "tape-smoke", name: "Tape deck", detail: "Black", player: "tape", skin: .smoke),
            Theme(id: "tape-yellow", name: "Tape deck", detail: "Yellow", player: "tape", skin: .yellow),
            Theme(id: "tape-blue", name: "Tape deck", detail: "Blue", player: "tape", skin: .blue),
            Theme(id: "mp3-neon", name: "MP3 player", detail: "Retro 80s", player: "mp3", skin: .neon),
            Theme(id: "mp3-smoke", name: "MP3 player", detail: "Black", player: "mp3", skin: .smoke)
        ]
        if !includesMP3 { list.removeAll { $0.player == "mp3" } }
        if Skin.includesClickWheel {
            list.append(Theme(id: "wheel-black", name: Skin.wheelWord.capitalized, detail: "Black",
                              player: "mp3", skin: .wheelBlack))
            list.append(Theme(id: "wheel-silver", name: Skin.wheelWord.capitalized, detail: "Silver",
                              player: "mp3", skin: .wheelSilver))
        }
        return list
    }

    /// Puts a phone that was left on the MP3 player back on the tape deck,
    /// while that player is held back.
    static func retireMP3IfHeldBack() {
        let defaults = UserDefaults.standard
        guard !includesMP3, defaults.string(forKey: Prefs.player) == "mp3" else { return }
        let skin = Skin(rawValue: defaults.string(forKey: Prefs.skin) ?? "")
        // The click wheel of personal builds is stored as an MP3 player too.
        if Skin.includesClickWheel, skin?.isWheel == true { return }
        defaults.set("tape", forKey: Prefs.player)
    }

    /// The skin actually on show: the stored skin, as the chosen player
    /// wears it.
    static func shownSkin() -> Skin {
        let defaults = UserDefaults.standard
        return current(player: defaults.string(forKey: Prefs.player) ?? "tape",
                       skinName: defaults.string(forKey: Prefs.skin) ?? Skin.standard.rawValue).skin
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

/// The kinds of player, for grouping the themes.
enum PlayerKind: String, CaseIterable, Identifiable {
    case tape, mp3, wheel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tape: return "Tape deck"
        case .mp3: return "MP3 player"
        case .wheel: return Skin.wheelWord.capitalized
        }
    }

    func includes(_ theme: Theme) -> Bool {
        switch self {
        case .tape: return theme.player == "tape"
        case .mp3: return theme.player == "mp3" && !theme.skin.isWheel
        case .wheel: return theme.skin.isWheel
        }
    }

    /// The kinds that have themes in this build.
    static var offered: [PlayerKind] {
        allCases.filter { kind in Theme.offered.contains(where: kind.includes) }
    }
}

/// The list of themes, for a settings form or the introduction, each with a
/// small picture of the player. Tapping one applies it at once. With a kind,
/// only that kind of player is listed.
struct ThemePicker: View {
    var kind: PlayerKind?
    @AppStorage(Prefs.player) private var player = "tape"
    @AppStorage(Prefs.skin) private var skinName = Skin.standard.rawValue

    var body: some View {
        let chosen = Theme.current(player: player, skinName: skinName)
        ForEach(Theme.offered.filter { kind?.includes($0) ?? true }) { theme in
            Button {
                Haptics.detent()
                player = theme.player
                skinName = theme.skin.rawValue
            } label: {
                HStack(spacing: 12) {
                    PlayerPreview(theme: theme, chosen: theme == chosen)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(kind == nil ? theme.name : theme.detail).foregroundColor(.primary)
                        if kind == nil {
                            Text(theme.detail).font(.footnote).foregroundColor(.secondary)
                        }
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
    static let privacyPolicy = "https://casseti.com/privacy.html"
    static let support = "https://casseti.com/support.html"
    /// Where a listener writes when something goes wrong.
    static let supportEmail = "hello@casseti.com"

    /// A new email to support, already saying what went wrong (if anything)
    /// and which app, phone and iOS it happened on.
    static func supportMail(about problem: String? = nil) -> URL? {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        var body = "\n\n"
        if let problem, !problem.isEmpty { body += "What Casseti said: \(problem)\n" }
        body += "Casseti \(version) (\(build)), \(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)"
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = supportEmail
        parts.queryItems = [URLQueryItem(name: "subject", value: problem == nil ? "Casseti" : "Casseti: something went wrong"),
                            URLQueryItem(name: "body", value: body)]
        return parts.url
    }

    /// Opens that email in the listener's mail app.
    @MainActor
    static func contactSupport(about problem: String? = nil) {
        if let url = supportMail(about: problem) { UIApplication.shared.open(url) }
    }
}

/// A small link for the foot of anything that has failed: it starts an
/// email to support that says what went wrong.
struct ContactSupportLink: View {
    var problem: String
    @Environment(\.playerTheme) private var theme

    var body: some View {
        Button {
            AppLinks.contactSupport(about: problem)
        } label: {
            Label("Still stuck? Contact support", systemImage: "envelope")
                .font(.footnote)
        }
        .buttonStyle(.plain)
        .foregroundColor(theme.accentColor)
        .accessibilityHint("Starts an email to \(AppLinks.supportEmail)")
    }
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

/// A small picture of a player in its colours, for choosing a theme: the
/// tape deck with its window, reels and keys, or the MP3 player with its
/// screen and dial.
struct PlayerPreview: View {
    let theme: Theme
    var chosen = false

    private var skin: Skin { theme.skin }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        ZStack {
            if theme.player == "tape" {
                tape
            } else {
                mp3
            }
        }
        .frame(width: 46, height: 70)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.25), lineWidth: 0.75))
        .padding(3)
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(Color.white.opacity(chosen ? 0.95 : 0), lineWidth: 2))
        .accessibilityHidden(true)
    }

    private var tape: some View {
        HStack(spacing: 0) {
            // The case, with the window and the two reels
            ZStack {
                LinearGradient(colors: skin.casing, startPoint: .topLeading, endPoint: .bottomTrailing)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(white: 0.10))
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(LinearGradient(colors: skin.windowEdge, startPoint: .top, endPoint: .bottom),
                                      lineWidth: 0.75))
                    .overlay(
                        VStack(spacing: 9) {
                            reel
                            reel
                        }
                    )
                    .padding(.horizontal, 5)
                    .padding(.vertical, 9)
                if skin.hasStripes {
                    VStack(spacing: 0) {
                        Spacer()
                        HStack(spacing: 0) {
                            ForEach([Skin.cyan, .yellow, .orange, Skin.hotPink], id: \.self) { $0 }
                        }
                        .frame(height: 3)
                        .padding(.bottom, 4)
                    }
                }
            }
            // The side panel and its keys
            ZStack {
                LinearGradient(colors: skin.panel, startPoint: .top, endPoint: .bottom)
                VStack(spacing: 2.5) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(LinearGradient(colors: skin.accentUp, startPoint: .top, endPoint: .bottom))
                        .frame(height: 6)
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1.5).fill(Color(white: 0.40)).frame(height: 6)
                    }
                }
                .padding(.horizontal, 2.5)
            }
            .frame(width: 13)
        }
    }

    private var reel: some View {
        Circle()
            .fill(Color(white: 0.22))
            .overlay(Circle().fill(Color(white: 0.75)).padding(3.5))
            .frame(width: 13, height: 13)
    }

    private var mp3: some View {
        ZStack {
            LinearGradient(colors: skin.isWheel ? skin.wheelBody : skin.panel,
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(skin.theme.backgroundColor)
                    .overlay(VStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { row in
                            Capsule().fill(row == 0 ? skin.theme.accentColor : Color.white.opacity(0.4))
                                .frame(height: 2)
                        }
                    }.padding(3))
                    .frame(height: 22)
                Circle()
                    .fill(skin.isWheel
                          ? AnyShapeStyle(LinearGradient(colors: skin.wheelRing, startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color(white: 0.95)))
                    .overlay(Circle().fill(Color.black.opacity(0.25)).padding(8))
                    .frame(width: 26, height: 26)
            }
            .padding(6)
        }
    }
}
