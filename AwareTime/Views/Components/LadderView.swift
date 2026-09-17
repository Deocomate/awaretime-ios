import SwiftUI

/// Visual summary of the three escalation levels.
struct LadderView: View {

    let ladder: [LadderStep]
    let reachedMinutes: Int

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(ladder.enumerated()), id: \.element.id) { position, step in
                LadderRow(
                    step: step,
                    reached: reachedMinutes >= step.minutes,
                    isLast: position == ladder.count - 1
                )
            }
        }
    }
}

private struct LadderRow: View {

    let step: LadderStep
    let reached: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(reached ? Color.aware(for: step.level) : Color.secondary.opacity(0.25))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(
                                Color.aware(for: step.level).opacity(reached ? 0.35 : 0),
                                lineWidth: 5
                            )
                    )
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(step.level.shortTitle) · \(step.minutes) phút")
                        .font(.subheadline.weight(.semibold))
                    if reached {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.aware(for: step.level))
                    }
                }
                Text(step.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 14)

            Spacer(minLength: 0)
        }
    }
}
