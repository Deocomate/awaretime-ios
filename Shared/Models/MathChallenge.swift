import Foundation

/// A two-choice arithmetic question used as the friction gate on the shield.
///
/// The shield screen only offers two buttons, so the challenge is always a
/// question plus exactly two candidate answers.
struct MathChallenge: Codable, Equatable {
    var question: String
    var primaryAnswer: String
    var secondaryAnswer: String
    var correctIsPrimary: Bool

    var correctAnswer: String { correctIsPrimary ? primaryAnswer : secondaryAnswer }

    static func make() -> MathChallenge {
        let a = Int.random(in: 6...19)
        let b = Int.random(in: 6...19)
        let useMultiplication = Bool.random()

        let question: String
        let answer: Int
        if useMultiplication {
            let small = Int.random(in: 3...9)
            let other = Int.random(in: 3...9)
            question = "\(small) × \(other) = ?"
            answer = small * other
        } else if Bool.random() {
            question = "\(a) + \(b) = ?"
            answer = a + b
        } else {
            let high = max(a, b) + Int.random(in: 5...20)
            let low = min(a, b)
            question = "\(high) − \(low) = ?"
            answer = high - low
        }

        // A decoy that is close enough to require actually doing the maths.
        var decoy = answer
        while decoy == answer {
            let delta = [-9, -7, -5, -4, -3, -2, 2, 3, 4, 5, 7, 9].randomElement() ?? 3
            decoy = max(0, answer + delta)
        }

        let correctIsPrimary = Bool.random()
        return MathChallenge(
            question: question,
            primaryAnswer: correctIsPrimary ? "\(answer)" : "\(decoy)",
            secondaryAnswer: correctIsPrimary ? "\(decoy)" : "\(answer)",
            correctIsPrimary: correctIsPrimary
        )
    }
}
