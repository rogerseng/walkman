import MusicKit
import SwiftUI
import UIKit

/// The introduction shown the first time the app is opened: what Cassety is,
/// how the deck works, connecting Apple Music, and a few choices to start with.
struct OnboardingView: View {
    @EnvironmentObject private var model: PlayerModel
    /// Called when the introduction is finished or skipped.
    var done: () -> Void

    @AppStorage(Prefs.iCloudSync) private var iCloudOn = true
    @AppStorage(Prefs.lockScreenTape) private var lockScreenTapeOn = true
    @State private var page = 0

    private let lastPage = 3

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") { done() }
                    .font(Typeface.display(16))
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(page == lastPage ? 0 : 1)
                    .disabled(page == lastPage)
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)

            TabView(selection: $page) {
                welcome.tag(0)
                howItWorks.tag(1)
                appleMusic.tag(2)
                choices.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                Haptics.keyDown()
                if page == lastPage {
                    done()
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                Text(page == lastPage ? "Start listening" : "Next")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(PlainKeyButtonStyle())
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            // A dusk sky with the eighties stripe along the foot
            LinearGradient(colors: [Color(red: 0.07, green: 0.02, blue: 0.18),
                                    Color(red: 0.20, green: 0.06, blue: 0.40),
                                    Color(red: 0.52, green: 0.11, blue: 0.50)],
                           startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .bottom) { RetroStripes().frame(height: 10) }
                .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
    }

    // MARK: Pages

    private var welcome: some View {
        Page {
            CassetteView(title: "Welcome", subtitle: "Side A", progress: 0.3, motion: .playing)
                .frame(maxWidth: 300)
                .padding(.bottom, 8)
            Wordmark(size: 40)
                .foregroundColor(.white)
                .shadow(color: Skin.hotPink, radius: 10)
                .shadow(color: Skin.hotPink.opacity(0.7), radius: 22)
            Text("Your Apple Music, on tape.")
                .font(Typeface.display(21))
                .foregroundColor(Skin.cyan)
            Text("Albums and playlists become cassettes with two sides. Put one in, press play, and watch the reels turn.")
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var howItWorks: some View {
        Page {
            Text("How the deck works")
                .font(Typeface.display(27))
                .foregroundColor(.white)
            Text("After this, a short tour has you try each one on the deck yourself.")
                .foregroundColor(.white.opacity(0.7))
            VStack(alignment: .leading, spacing: 16) {
                tip("play.fill", "Play and stop", "They are a pair. Press one in and the other pops out.")
                tip("forward.fill", "Skip or wind", "Tap fast forward or rewind to skip a song. Hold to wind the tape.")
                tip("arrow.triangle.2.circlepath", "Two sides", "When a side runs out the music stops. Double-tap the tape to turn it over.")
                tip("rectangle.portrait.on.rectangle.portrait", "Open and close", "Open the phone to choose a tape. Close it to start playing.")
                tip("music.note", "Your tapes", "The music key opens your shelf, where you can also record mixtapes.")
            }
        }
    }

    private var appleMusic: some View {
        Page {
            Image(systemName: "music.note")
                .font(.system(size: 54, weight: .bold))
                .foregroundColor(.white)
            Text("Connect Apple Music")
                .font(Typeface.display(27))
                .foregroundColor(.white)
            Text("Cassety plays music from your Apple Music library and catalogue. It needs your permission, and an Apple Music subscription.")
                .foregroundColor(.white.opacity(0.7))

            switch model.authStatus {
            case .authorized:
                Label("Apple Music is connected", systemImage: "checkmark.circle.fill")
                    .font(Typeface.display(17))
                    .foregroundColor(.white)
                    .padding(.top, 6)
            case .notDetermined:
                Button {
                    Task { await model.requestAccess() }
                } label: {
                    Text("Connect Apple Music").padding(.horizontal, 20).padding(.vertical, 12)
                }
                .buttonStyle(PlainKeyButtonStyle())
                .padding(.top, 6)
            default:
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Turn on access in Settings").padding(.horizontal, 20).padding(.vertical, 12)
                }
                .buttonStyle(PlainKeyButtonStyle())
                .padding(.top, 6)
                Text("Access was turned down before. You can allow it in Settings.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var choices: some View {
        Page {
            Text("A few choices")
                .font(Typeface.display(27))
                .foregroundColor(.white)
            Text("You can change all of these later in Settings.")
                .foregroundColor(.white.opacity(0.7))

            VStack(spacing: 0) {
                Toggle("Sync mixtapes and settings with iCloud", isOn: $iCloudOn)
                    .padding(.vertical, 10)
                Divider().overlay(Color.white.opacity(0.15))
                Toggle("Show the tape on the lock screen", isOn: $lockScreenTapeOn)
                    .padding(.vertical, 10)
                Divider().overlay(Color.white.opacity(0.15))
                ThemePicker()
                    .padding(.vertical, 5)
            }
            .foregroundColor(.white)
            .tint(Skin.hotPink)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
            .multilineTextAlignment(.leading)
        }
    }

    private func tip(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typeface.display(17)).foregroundColor(.white)
                Text(text).font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One page of the introduction: its contents centred, scrolling if the
/// screen is short.
private struct Page<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                content
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 26)
            .padding(.top, 10)
            .padding(.bottom, 50)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// A round sample of a skin's colour, ringed when it is the one in use.
struct SkinSwatch: View {
    let skin: Skin
    let chosen: Bool

    var body: some View {
        Circle()
            .fill(skin.swatch)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            .frame(width: 30, height: 30)
            .padding(4)
            .overlay(Circle().strokeBorder(Color.white.opacity(chosen ? 0.95 : 0), lineWidth: 2))
    }
}
