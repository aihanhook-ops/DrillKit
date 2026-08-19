import XCTest
@testable import DrillKit

enum TestTopic: String, QuizTopic {
    case vocabulary, grammar, reading
}

/// Deterministic generator so shuffle-dependent behaviour is actually testable.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64 = 42) { state = seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

private func makeQuestion(_ id: Int, _ topic: TestTopic, answer: Int = 0) -> Question<TestTopic> {
    Question(id: id, topic: topic, prompt: "Q\(id)",
             options: ["a", "b", "c", "d"], answerIndex: answer)
}

final class QuestionTests: XCTestCase {
    func testIsCorrectMatchesAnswerIndex() {
        let question = makeQuestion(1, .vocabulary, answer: 2)
        XCTAssertTrue(question.isCorrect(2))
        XCTAssertFalse(question.isCorrect(0))
    }

    func testCodableRoundTrip() throws {
        let question = makeQuestion(7, .grammar, answer: 3)
        let data = try JSONEncoder().encode(question)
        let decoded = try JSONDecoder().decode(Question<TestTopic>.self, from: data)
        XCTAssertEqual(question, decoded)
    }
}

final class DiagnosticTests: XCTestCase {
    func testScoreCountsCorrectAnswers() {
        let questions = [makeQuestion(1, .vocabulary, answer: 1),
                         makeQuestion(2, .vocabulary, answer: 2)]
        let result = Diagnostic.score(questions: questions, answers: [1: 1, 2: 0])
        XCTAssertEqual(result.correct, 1)
        XCTAssertEqual(result.total, 2)
        XCTAssertEqual(result.accuracy, 0.5)
    }

    func testUnansweredQuestionsCountAsWrong() {
        let questions = [makeQuestion(1, .vocabulary), makeQuestion(2, .vocabulary)]
        let result = Diagnostic.score(questions: questions, answers: [:])
        XCTAssertEqual(result.correct, 0)
        XCTAssertEqual(result.accuracy, 0)
    }

    func testWeakestTopicPicksLowestAccuracy() {
        let questions = [makeQuestion(1, .vocabulary), makeQuestion(2, .grammar)]
        // vocabulary right, grammar wrong
        let result = Diagnostic.score(questions: questions, answers: [1: 0, 2: 3])
        XCTAssertEqual(result.weakestTopic, .grammar)
    }

    func testWeakestTopicIgnoresTopicsWithNoQuestions() {
        let questions = [makeQuestion(1, .grammar, answer: 1)]
        let result = Diagnostic.score(questions: questions, answers: [1: 1])
        // .reading has no questions and must not be reported as weakest
        XCTAssertEqual(result.weakestTopic, .grammar)
    }

    func testWeakestTopicTieBreaksByDeclarationOrder() {
        let questions = [makeQuestion(1, .vocabulary), makeQuestion(2, .grammar)]
        let result = Diagnostic.score(questions: questions, answers: [:])
        // both at 0% — vocabulary is declared first, so it wins deterministically
        XCTAssertEqual(result.weakestTopic, .vocabulary)
    }

    func testEmptyDiagnosticDoesNotDivideByZero() {
        let result = Diagnostic<TestTopic>.score(questions: [], answers: [:])
        XCTAssertEqual(result.accuracy, 0)
        XCTAssertNil(result.weakestTopic)
    }

    func testBandUsesHighestMatchingThreshold() {
        let questions = (1...10).map { makeQuestion($0, .vocabulary) }
        let answers = Dictionary(uniqueKeysWithValues: (1...9).map { ($0, 0) })
        let result = Diagnostic.score(questions: questions, answers: answers)
        let band = result.band(thresholds: [(0.8, "advanced"), (0.45, "intermediate")],
                               fallback: "beginner")
        XCTAssertEqual(band, "advanced")
    }

    func testBandFallsBackWhenNoThresholdMatches() {
        let questions = (1...10).map { makeQuestion($0, .vocabulary) }
        let result = Diagnostic.score(questions: questions, answers: [1: 0])
        let band = result.band(thresholds: [(0.8, "advanced"), (0.45, "intermediate")],
                               fallback: "beginner")
        XCTAssertEqual(band, "beginner")
    }
}

final class SessionPlannerTests: XCTestCase {
    private var bank: [Question<TestTopic>] {
        (1...10).map { makeQuestion($0, .vocabulary) }
            + (11...15).map { makeQuestion($0, .grammar) }
    }

    func testSessionPrefersUnseenQuestions() {
        let planner = SessionPlanner(bank: bank)
        var generator = SeededGenerator()
        let seen: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
        let session = planner.session(topic: .vocabulary, count: 3,
                                      seen: seen, using: &generator)
        XCTAssertEqual(session.count, 3)
        XCTAssertTrue(session.allSatisfy { !seen.contains($0.id) },
                      "fresh questions remained but a seen one was served")
    }

    func testSessionFallsBackToSeenWhenFreshPoolIsShort() {
        let planner = SessionPlanner(bank: bank)
        var generator = SeededGenerator()
        let seen = Set(1...8)
        let session = planner.session(topic: .vocabulary, count: 5,
                                      seen: seen, using: &generator)
        XCTAssertEqual(session.count, 5, "session must stay full length")
        XCTAssertTrue(session.contains { !seen.contains($0.id) })
    }

    func testSessionNeverExceedsAvailableQuestions() {
        let planner = SessionPlanner(bank: bank)
        var generator = SeededGenerator()
        let session = planner.session(topic: .grammar, count: 99, using: &generator)
        XCTAssertEqual(session.count, 5)
    }

    func testSessionOnlyReturnsRequestedTopic() {
        let planner = SessionPlanner(bank: bank)
        var generator = SeededGenerator()
        let session = planner.session(topic: .grammar, count: 5, using: &generator)
        XCTAssertTrue(session.allSatisfy { $0.topic == .grammar })
    }

    func testDiagnosticDistributesRemainderInsteadOfDroppingIt() {
        let planner = SessionPlanner(bank: bank)
        var generator = SeededGenerator()
        // 7 across 3 topics = 2 each + 1 remainder; .reading has no questions
        let questions = planner.diagnostic(count: 7, using: &generator)
        XCTAssertEqual(questions.filter { $0.topic == .vocabulary }.count, 3)
        XCTAssertEqual(questions.filter { $0.topic == .grammar }.count, 2)
    }

    func testDiagnosticWithZeroCountIsEmpty() {
        let planner = SessionPlanner(bank: bank)
        var generator = SeededGenerator()
        XCTAssertTrue(planner.diagnostic(count: 0, using: &generator).isEmpty)
    }
}

final class MistakeLogTests: XCTestCase {
    func testRawValueRoundTrip() {
        let log = MistakeLog(ids: [5, 1, 3])
        XCTAssertEqual(log.rawValue, "1,3,5", "ids must be sorted for stable storage")
        XCTAssertEqual(MistakeLog(rawValue: log.rawValue), log)
    }

    func testEmptyRawValueParsesToEmptyLog() {
        XCTAssertTrue(MistakeLog(rawValue: "").isEmpty)
    }

    func testMalformedEntriesAreIgnoredRatherThanCrashing() {
        let log = MistakeLog(rawValue: "1,,abc,3,")
        XCTAssertEqual(log.ids, [1, 3])
    }

    func testRecordAddsWrongAndClearsCorrect() {
        var log = MistakeLog(ids: [1, 2, 3])
        log.record(correct: [1, 2], wrong: [7])
        XCTAssertEqual(log.ids, [3, 7])
    }

    func testAnsweringCorrectlyClearsAPreviousMistake() {
        var log = MistakeLog(ids: [4])
        log.record(correct: [4])
        XCTAssertTrue(log.isEmpty)
    }

    func testRecordingTheSameMistakeTwiceDoesNotDuplicate() {
        var log = MistakeLog(ids: [9])
        log.record(wrong: [9])
        XCTAssertEqual(log.count, 1)
    }
}
