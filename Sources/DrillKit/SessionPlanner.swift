import Foundation

/// Builds practice sessions out of a question bank.
///
/// The rule that matters: show questions the learner has not seen yet, and only
/// start repeating once the fresh pool runs out. A naive `shuffled().prefix(n)`
/// re-serves the same questions while dozens remain untouched, which learners
/// notice immediately and read as a broken app.
public struct SessionPlanner<Topic: QuizTopic> {
    private let bank: [Question<Topic>]

    public init(bank: [Question<Topic>]) {
        self.bank = bank
    }

    public func questions(in topic: Topic) -> [Question<Topic>] {
        bank.filter { $0.topic == topic }
    }

    /// Picks `count` questions from `topic`, preferring ones not in `seen`.
    ///
    /// Falls back to already-seen questions only to fill the remainder, so a
    /// session is always full-length even late in a topic.
    public func session(topic: Topic,
                        count: Int,
                        seen: Set<Int> = [],
                        using generator: inout some RandomNumberGenerator) -> [Question<Topic>] {
        let pool = questions(in: topic)
        let fresh = pool.filter { !seen.contains($0.id) }.shuffled(using: &generator)
        guard fresh.count < count else { return Array(fresh.prefix(count)) }

        let repeats = pool.filter { seen.contains($0.id) }.shuffled(using: &generator)
        return Array((fresh + repeats).prefix(count))
    }

    public func session(topic: Topic, count: Int, seen: Set<Int> = []) -> [Question<Topic>] {
        var generator = SystemRandomNumberGenerator()
        return session(topic: topic, count: count, seen: seen, using: &generator)
    }

    /// A balanced set spanning every topic, for a first-run level check.
    ///
    /// Remainder questions go to the earliest topics rather than being dropped,
    /// so the total always equals `count` when the bank can supply it.
    public func diagnostic(count: Int,
                           using generator: inout some RandomNumberGenerator) -> [Question<Topic>] {
        let topics = Array(Topic.allCases)
        guard !topics.isEmpty, count > 0 else { return [] }

        let base = count / topics.count
        let remainder = count % topics.count

        return topics.enumerated().flatMap { index, topic -> [Question<Topic>] in
            let quota = base + (index < remainder ? 1 : 0)
            return Array(questions(in: topic).shuffled(using: &generator).prefix(quota))
        }
    }

    public func diagnostic(count: Int) -> [Question<Topic>] {
        var generator = SystemRandomNumberGenerator()
        return diagnostic(count: count, using: &generator)
    }
}
