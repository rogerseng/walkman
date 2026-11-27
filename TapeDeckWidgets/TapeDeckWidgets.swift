import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct TapeDeckWidgets: WidgetBundle {
    var body: some Widget {
        TapeLiveActivity()
    }
}

private enum Palette {
    static let body = Color(red: 0.08, green: 0.02, blue: 0.19)
    static let ink = Color(red: 0.07, green: 0.10, blue: 0.33)
    static let accent = Color(red: 1.0, green: 0.24, blue: 0.64)
    static let oxide = Color(red: 0.24, green: 0.18, blue: 0.14)
}

struct TapeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TapeActivityAttributes.self) { context in
            LockScreenTapeView(state: context.state)
                .activityBackgroundTint(Palette.body)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ReelView(state: context.state, fill: 1 - context.state.progress, size: 46)
                        .clipShape(Circle())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ReelView(state: context.state, fill: context.state.progress, size: 46)
                        .clipShape(Circle())
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text(context.state.title).font(.system(size: 14, weight: .bold))
                        Text(context.state.subtitle).font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TapeKeys(isPlaying: context.state.isPlaying)
                }
            } compactLeading: {
                ReelView(state: context.state, fill: 0, size: 24)
            } compactTrailing: {
                ReelView(state: context.state, fill: 0, size: 24)
            } minimal: {
                ReelView(state: context.state, fill: 0, size: 24)
            }
        }
    }
}

/// The lock screen banner: the clear cassette on the left, track and keys on the right.
struct LockScreenTapeView: View {
    let state: TapeActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            MiniCassette(state: state, width: 168)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.title.isEmpty ? " " : state.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(state.subtitle.isEmpty ? " " : state.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .lineLimit(1)
                Group {
                    if state.isPlaying {
                        ProgressView(timerInterval: state.clock, countsDown: false,
                                     label: { EmptyView() }, currentValueLabel: { EmptyView() })
                    } else {
                        ProgressView(value: state.progress)
                    }
                }
                .tint(Palette.accent)
                TapeKeys(isPlaying: state.isPlaying)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }
}

/// The clear cassette, small. Same construction as the one in the app: a
/// faint shell, the two tape packs with their hubs, then the see-through
/// artwork of the shell front, then the handwriting on the label.
/// Measurements are in millimetres of a 100 x 63 mm shell.
struct MiniCassette: View {
    let state: TapeActivityAttributes.ContentState
    var width: CGFloat

    var body: some View {
        let u = width / 100
        let tint = state.tintColor
        ZStack {
            RoundedRectangle(cornerRadius: 2.6 * u)
                .fill((tint ?? .white).opacity(tint == nil ? 0.14 : 0.30))
            ZStack {
                ReelView(state: state, fill: 1 - state.progress, size: 50 * u)
                    .position(x: 29.5 * u, y: 28.5 * u)
                ReelView(state: state, fill: state.progress, size: 50 * u)
                    .position(x: 70.5 * u, y: 28.5 * u)
            }
            .frame(width: 100 * u, height: 63 * u)
            .clipShape(RoundedRectangle(cornerRadius: 2.6 * u))

            Image("CassetteFrontSmall")
                .resizable()
                .interpolation(.high)

            // Side letter
            Text(state.side)
                .font(.system(size: 3.4 * u, weight: .bold))
                .foregroundColor(Color(white: 0.17))
                .frame(width: 4.6 * u, height: 4.6 * u)
                .overlay(Circle().strokeBorder(Color(white: 0.17), lineWidth: 0.26 * u))
                .position(x: 22.6 * u, y: 8.4 * u)

            Text(state.title.isEmpty ? " " : state.title)
                .font(.custom("PermanentMarker-Regular", fixedSize: 4.5 * u))
                .foregroundColor(Palette.ink.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 58 * u, height: 5.0 * u, alignment: .bottomLeading)
                .position(x: 56 * u, y: 6.3 * u)
        }
        .frame(width: 100 * u, height: 63 * u)
        .accessibilityHidden(true)
    }
}

/// One reel: a ring of wound tape around a clear hub that steps round once a
/// second. `size` is the diameter of a full reel; the hub is two fifths of it.
struct ReelView: View {
    let state: TapeActivityAttributes.ContentState
    /// 0 for an empty reel, 1 for a full one.
    var fill: Double
    var size: CGFloat

    var body: some View {
        let hub = size * 0.40
        let full = size / 2
        let bare = hub / 2
        let clamped = CGFloat(min(max(fill, 0), 1))
        let radius = (bare * bare + clamped * (full * full - bare * bare)).squareRoot() + size * 0.01
        ZStack {
            // Wound tape, as a ring: the hub in the middle is clear
            Circle()
                .strokeBorder(Palette.oxide, lineWidth: max(0, radius - bare * 0.96))
                .frame(width: 2 * radius, height: 2 * radius)
            // The TapeReels font draws every digit as a hub at a different angle,
            // so the last digit of a running timer is a turning hub. Showing just
            // that digit means pinning the text to the right and clipping the rest.
            Group {
                if state.isPlaying {
                    Text(timerInterval: state.clock, countsDown: false)
                } else {
                    Text("0")
                }
            }
            .font(.custom("TapeReels", fixedSize: hub))
            .foregroundColor(Color.white.opacity(0.78))
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .fixedSize()
            .frame(width: hub, height: hub, alignment: .trailing)
            .clipped()
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct TapeKeys: View {
    var isPlaying: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: PreviousTapeTrackIntent()) {
                key("backward.fill", accent: false)
            }
            .accessibilityLabel("Previous track")
            Button(intent: TogglePlayTapeIntent()) {
                key(isPlaying ? "pause.fill" : "play.fill", accent: true)
            }
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
            Button(intent: NextTapeTrackIntent()) {
                key("forward.fill", accent: false)
            }
            .accessibilityLabel("Next track")
        }
        .buttonStyle(.plain)
    }

    private func key(_ symbol: String, accent: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(accent ? Palette.accent.opacity(0.92) : Color.white.opacity(0.22)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.3), lineWidth: 0.75))
    }
}

private extension TapeActivityAttributes.ContentState {
    var tintColor: Color? {
        guard let tint, tint.count >= 3 else { return nil }
        return Color(red: tint[0], green: tint[1], blue: tint[2])
    }

    /// The span the lock screen clock runs over. Never empty or backwards.
    var clock: ClosedRange<Date> {
        trackStart...max(trackEnd, trackStart.addingTimeInterval(1))
    }
}
