import Foundation

/// A topic a question belongs to — vocabulary, road signs, whatever your domain uses.
///
/// Conform your own enum and you get diagnostics and session planning for free:
///
/// ```swift
/// enum Topic: String, QuizTopic {
///     case vocabulary, grammar, reading, listening
/// }
/// ```
public protocol QuizTopic: Hashable, CaseIterable, Codable, Sendable {}

/// A single multiple-choice question.
///
/// `answerIndex` points into `options`. It is validated on init in debug builds,
/// because a content file with an out-of-range answer is the kind of bug that
/// ships quietly and then fails in front of a user.
public struct Question<Topic: QuizTopic>: Identifiable, Codable, Equatable, Sendable {
    public let id: Int
    public let topic: Topic
    public let prompt: String
    public let options: [String]
    public let answerIndex: Int
    public let explanation: String

    public init(
        id: Int,
        topic: Topic,
        prompt: String,
        options: [String],
        answerIndex: Int,
        explanation: String = ""
    ) {
        assert(options.indices.contains(answerIndex),
               "Question \(id): answerIndex \(answerIndex) is out of range for \(options.count) options")
        self.id = id
        self.topic = topic
        self.prompt = prompt
        self.options = options
        self.answerIndex = answerIndex
        self.explanation = explanation
    }

    public func isCorrect(_ chosenIndex: Int) -> Bool {
        chosenIndex == answerIndex
    }
}
