import SwiftUI

struct StatusPill: View {

    enum Tone {
        case neutral, good, warn, bad

        var color: Color {
            switch self {
            case .neutral: return .secondary
            case .good: return .awareMint
            case .warn: return .awareAmber
            case .bad: return .awareAlert
            }
        }
    }

    let text: String
    var systemImage: String?
    var tone: Tone = .neutral

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tone.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(tone.color.opacity(0.14))
        )
    }
}
