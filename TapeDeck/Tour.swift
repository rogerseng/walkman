import SwiftUI

/// The hands-on tour of the tape deck. Rather than reading about the keys,
/// the listener is asked to do each thing on the real deck, and the tour
/// waits until they have: choose a tape, play, stop, skip, wind, and flip.
@MainActor
final class Tour: ObservableObject {
    enum Step: Int, CaseIterable {
        case chooseTape, play, stop, skip, wind, flip, finished

        var title: String {
            switch self {
            case .chooseTape: return "Choose a tape"
            case .play: return "Press play"
            case .stop: return "Press stop"
            case .skip: return "Skip a song"
            case .wind: return "Wind the tape"
            case .flip: return "Turn the tape over"
            case .finished: return "You're all set"
            }
        }

        var instruction: String {
            switch self {
            case .chooseTape:
                return "Press the music key to open your shelf, then pick any album or playlist."
            case .play:
                return "Press the play key. It stays down while the tape plays."
            case .stop:
                return "Press stop. Play pops up, and the tape waits right where it is."
            case .skip:
                return "Tap fast forward once to jump to the next song."
            case .wind:
                return "Now press and hold rewind. The tape winds back until you let go."
            case .flip:
                return "Double-tap the tape to turn it over to the other side."
            case .finished:
                return "That is the whole deck. You can take this tour again from Settings."
            }
        }

        /// The symbol of the key to press, so that key can be lit up.
        var key: String? {
            switch self {
            case .chooseTape: return "music.note"
            case .play: return "play.fill"
            case .stop: return "stop.fill"
            case .skip: return "forward.fill"
            case .wind: return "backward.fill"
            case .flip, .finished: return nil
            }
        }

        /// This step is done on the tape itself, not a key.
        var onTape: Bool { self == .flip }
    }

    @Published private(set) var step: Step?

    var isActive: Bool { step != nil }

    func start(hasTape: Bool) {
        step = hasTape ? .play : .chooseTape
    }

    func end() {
        step = nil
    }

    /// Moves on from `done`, if that is the step being shown.
    func completed(_ done: Step) {
        guard step == done, let next = Step(rawValue: done.rawValue + 1) else { return }
        Haptics.seat()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { step = next }
    }

    func skipStep() {
        guard let step else { return }
        completed(step)
    }
}

private struct TourKeyKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// The symbol of the key the tour wants pressed next, if any.
    var tourKey: String? {
        get { self[TourKeyKey.self] }
        set { self[TourKeyKey.self] = newValue }
    }
}

/// A ring that breathes around whatever the tour wants touched.
struct TourPulse: View {
    var corner: CGFloat
    @Environment(\.playerTheme) private var theme
    @State private var bright = false

    var body: some View {
        RoundedRectangle(cornerRadius: corner)
            .strokeBorder(theme.accentColor, lineWidth: 3)
            .shadow(color: theme.accentColor, radius: bright ? 10 : 2)
            .opacity(bright ? 1 : 0.35)
            .padding(-6)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { bright = true }
            }
    }
}

/// The card that says what to do next.
struct TourCard: View {
    @ObservedObject var tour: Tour
    @Environment(\.playerTheme) private var theme

    var body: some View {
        if let step = tour.step {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(step == .finished ? "TOUR" : "TRY IT  \(step.rawValue + 1) OF \(Tour.Step.finished.rawValue)")
                        .font(Typeface.display(11))
                        .tracking(1.4)
                        .foregroundColor(theme.secondaryColor)
                    Spacer(minLength: 0)
                    if step != .finished {
                        Button("End tour") { tour.end() }
                            .font(Typeface.display(12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                Text(step.title)
                    .font(Typeface.display(20))
                    .foregroundColor(.white)
                Text(step.instruction)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer(minLength: 0)
                    if step == .finished {
                        Button("Done") { tour.end() }
                            .buttonStyle(PlainKeyButtonStyle())
                    } else if step == .flip || step == .skip {
                        // A tape with one side, or a single, cannot do these.
                        Button("Skip this step") { tour.skipStep() }
                            .font(Typeface.display(13))
                            .foregroundColor(theme.accentColor)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.82))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.accentColor.opacity(0.7), lineWidth: 1.5))
            )
            .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(step)
        }
    }
}
