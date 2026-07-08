import ActivityKit
import MuscatKit
import SwiftUI
import WidgetKit

/// Lock screen + Dynamic Island UI for `PlaybackActivityAttributes` (defined in
/// MuscatKit so both the app and this extension share the same type). Text-only by
/// design — see the comment on `PlaybackActivityAttributes` for why artwork isn't here.
struct PlaybackLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlaybackActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "music.note")
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                        .font(.title2)
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
                        .tint(.white)
                }
            } compactLeading: {
                Image(systemName: "music.note")
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
            } minimal: {
                Image(systemName: "music.note")
            }
        }
    }
}

private struct LockScreenView: View {
    let state: PlaybackActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.title)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text(state.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(state.artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                ProgressView(value: state.currentSeconds, total: max(state.duration, 1))
                    .tint(.white)
            }

            Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                .foregroundStyle(.white)
                .font(.title2)
        }
        .padding()
    }
}
