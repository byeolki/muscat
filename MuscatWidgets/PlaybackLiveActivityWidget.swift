import ActivityKit
import MuscatKit
import SwiftUI
import WidgetKit

/// Shared palette from MuscatKit's design system.
private let accent = Color.appAccent

/// Lock screen + Dynamic Island UI for `PlaybackActivityAttributes` (defined in
/// MuscatKit so both the app and this extension share the same type). Text-only by
/// design — see the comment on `PlaybackActivityAttributes` for why artwork isn't here.
struct PlaybackLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlaybackActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.appBackground)
                .activitySystemActionForegroundColor(accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                        .font(.title2)
                        .foregroundStyle(context.state.isPlaying ? accent : .secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.state.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.currentSeconds, total: max(context.state.duration, 1))
                        .tint(accent)
                }
            } compactLeading: {
                Image(systemName: "music.note")
                    .foregroundStyle(accent)
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                    .foregroundStyle(context.state.isPlaying ? accent : .secondary)
            } minimal: {
                Image(systemName: "music.note")
                    .foregroundStyle(accent)
            }
        }
    }
}

private struct LockScreenView: View {
    let state: PlaybackActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(state.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(state.artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                ProgressView(value: state.currentSeconds, total: max(state.duration, 1))
                    .tint(accent)
            }

            Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                .foregroundStyle(accent)
                .font(.title2)
        }
        .padding()
    }
}
