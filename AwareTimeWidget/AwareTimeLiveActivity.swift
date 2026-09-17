import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen card + Dynamic Island presentation (spec §3.4).
struct AwareTimeLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AwareTimeActivityAttributes.self) { context in
            LockScreenCard(state: context.state, attributes: context.attributes)
                .activityBackgroundTint(Color.awareInk.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.level.symbolName)
                        .font(.title3)
                        .foregroundStyle(Color.aware(for: context.state.level))
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.minutesUsed)′")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.aware(for: context.state.level))
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.headline)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(value: context.state.progress)
                            .tint(Color.aware(for: context.state.level))
                        Text(context.state.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.level.symbolName)
                    .foregroundStyle(Color.aware(for: context.state.level))
            } compactTrailing: {
                Text("\(context.state.minutesUsed)′")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.aware(for: context.state.level))
            } minimal: {
                Image(systemName: context.state.level.symbolName)
                    .foregroundStyle(Color.aware(for: context.state.level))
            }
            .keylineTint(Color.aware(for: context.state.level))
        }
    }
}

private struct LockScreenCard: View {

    let state: AwareTimeActivityAttributes.ContentState
    let attributes: AwareTimeActivityAttributes

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: state.level.symbolName)
                    .font(.headline)
                    .foregroundStyle(Color.aware(for: state.level))

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(state.detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(state.minutesUsed)")
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.aware(for: state.level))
                    Text("phút")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            ProgressView(value: state.progress)
                .tint(Color.aware(for: state.level))

            HStack {
                Text("AwareTime · \(attributes.watchedCount) mục đang theo dõi")
                Spacer()
                Text("Chặn ở \(state.shieldAtMinutes)′")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.55))
        }
        .padding(14)
    }
}
