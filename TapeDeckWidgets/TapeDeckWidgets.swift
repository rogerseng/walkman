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
    static let body = Color(red: 0.13, green: 0.21, blue: 0.45)
    static let cream = Color(red: 0.95, green: 0.91, blue: 0.81)
    static let ink = Color(red: 0.10, green: 0.12, blue: 0.35)
    static let orange = Color(red: 0.96, green: 0.48, blue: 0.13)
    static let tape = Color(red: 0.30, green: 0.18, blue: 0.11)
    static let dark = Color(red: 0.09, green: 0.07, blue: 0.06)
    static let hub = Color(white: 0.93)
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
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ReelView(state: context.state, fill: context.state.progress, size: 46)
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
                ReelView(state: context.state, fill: 1 - context.state.progress, size: 22)
            } compactTrailing: {
                ReelView(state: context.state, fill: context.state.progress, size: 22)
            } minimal: {
                ReelView(state: context.state, fill: 0.5, size: 22)
            }
        }
    }
}

/// The lock screen banner: a small cassette on the left, track and keys on the right.
struct LockScreenTapeView: View {
    let state: TapeActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 5) {
                Text(state.title.isEmpty ? " " : state.title)
                    .font(.custom("MarkerFelt-Wide", fixedSize: 15))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 18) {
                    ReelView(state: state, fill: 1 - state.progress, size: 56)
                    ReelView(state: state, fill: state.progress, size: 56)
                }
                .frame(width: 150, height: 44)
                .background(Palette.dark)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .padding(8)
            .frame(width: 166)
            .background(RoundedRectangle(cornerRadius: 8).fill(Palette.cream))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.black.opacity(0.5), lineWidth: 1))

            VStack(alignment: .leading, spacing: 8) {
                Text(state.subtitle.isEmpty ? " " : state.subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Group {
                    if state.isPlaying {
                        ProgressView(timerInterval: state.clock, countsDown: false,
                                     label: { EmptyView() }, currentValueLabel: { EmptyView() })
                    } else {
                        ProgressView(value: state.progress)
                    }
                }
                .tint(Palette.orange)
                TapeKeys(isPlaying: state.isPlaying)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }
}

/// One reel: the wound tape, with a hub that steps round once a second.
struct ReelView: View {
    let state: TapeActivityAttributes.ContentState
    /// 0 for an empty reel, 1 for a full one.
    var fill: Double
    /// Diameter of a full reel.
    var size: CGFloat

    var body: some View {
        let hub = size * 0.40
        let full = size / 2
        let bare = hub / 2 + size * 0.03
        let clamped = CGFloat(min(max(fill, 0), 1))
        let pack = 2 * (bare * bare + clamped * (full * full - bare * bare)).squareRoot()
        ZStack {
            Circle().fill(Palette.tape).frame(width: pack, height: pack)
            Circle().fill(Palette.dark).frame(width: hub * 0.9, height: hub * 0.9)
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
            .foregroundColor(Palette.hub)
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
            .foregroundColor(accent ? .white : Color(white: 0.15))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 6).fill(accent ? Palette.orange : Color(white: 0.85)))
    }
}

private extension TapeActivityAttributes.ContentState {
    /// The span the lock screen clock runs over. Never empty or backwards.
    var clock: ClosedRange<Date> {
        trackStart...max(trackEnd, trackStart.addingTimeInterval(1))
    }
}
