import SwiftUI

/// In-app rendering of the blocking screen.
///
/// The real screen is drawn by `ShieldConfigurationExtension` from the same
/// `ShieldPresentation`, so this preview stays honest about what the user will
/// actually see.
struct ShieldPreviewView: View {

    let presentation: ShieldPresentation

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.awareCalm.opacity(0.18))
                    .frame(width: 92, height: 92)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text(presentation.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(presentation.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                Text(presentation.primaryButtonTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        Capsule().fill(
                            presentation.snoozeQuotaReached ? Color.awareAlert : Color.awareCalm
                        )
                    )

                if let secondary = presentation.secondaryButtonTitle {
                    Text(secondary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.awareInk.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
