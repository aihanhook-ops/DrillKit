import Foundation

/// Per-topic accuracy plus the single weakest topic, used to decide what a
/// learner should practise next.
public struct Diagnostic<Topic: QuizTopic>: Equatable, Sendable {
    public let correct: Int
    public let total: Int
    public let accuracyByTopic: [Topic: Double]

    public var accuracy: Double {
        total == 0 ? 0 : Double(correct) / Double(total)
    }

    /// The topic with the lowest accuracy.
    ///
    /// Ties are broken by `Topic.allCases` order so the result is stable across
    /// runs — a randomly-chosen "weakest topic" makes the daily plan jump around
    /// and looks like a bug to the user.
    public var weakestTopic: Topic? {
        Topic.allCases.filter { accuracyByTopic[$0] != nil }
            .min { lhs, rhs in
                (accuracyByTopic[lhs] ?? 1) < (accuracyByTopic[rhs] ?? 1)
            }
    }

    /// Grades this result against ordered thresholds, highest band first.
    ///
    /// ```swift
    /// diagnostic.band(thresholds: [(0.8, "advanced"), (0.45, "intermediate")],
    ///                 fallback: "beginner")
    /// ```
    public func band(thresholds: [(minimumAccuracy: Double, label: String)],
                     fallback: String) -> String {
        for threshold in thresholds where accuracy >= threshold.minimumAccuracy {
            return threshold.label
        }
        return fallback
    }

    /// Scores a set of answers keyed by question id. Unanswered questions count
    /// as wrong, which is what an exam does.
    public static func score(questions: [Question<Topic>],
                             answers: [Int: Int]) -> Diagnostic<Topic> {
        let correct = questions.filter { answers[$0.id] == $0.answerIndex }.count

        var accuracyByTopic: [Topic: Double] = [:]
        for topic in Topic.allCases {
            let subset = questions.filter { $0.topic == topic }
            guard !subset.isEmpty else { continue }
            let hits = subset.filter { answers[$0.id] == $0.answerIndex }.count
            accuracyByTopic[topic] = Double(hits) / Double(subset.count)
        }

        return Diagnostic(correct: correct,
                          total: questions.count,
                          accuracyByTopic: accuracyByTopic)
    }
}
