import Foundation

/// The set of question ids a learner has got wrong and not yet fixed.
///
/// Stored as a sorted comma-separated string so it drops straight into
/// `@AppStorage` / `UserDefaults` without a database or a custom encoder —
/// the whole point being that a review list of a few hundred ids does not
/// justify Core Data.
public struct MistakeLog: Equatable, Sendable {
    public private(set) var ids: Set<Int>

    public init(ids: Set<Int> = []) {
        self.ids = ids
    }

    public init(rawValue: String) {
        self.ids = Set(rawValue.split(separator: ",").compactMap { Int($0) })
    }

    /// Sorted so the stored string is stable — an unsorted set would rewrite
    /// storage on every launch and make diffs meaningless.
    public var rawValue: String {
        ids.sorted().map(String.init).joined(separator: ",")
    }

    public var isEmpty: Bool { ids.isEmpty }
    public var count: Int { ids.count }

    /// Records the outcome of a session: wrong answers are added, correct ones
    /// clear an existing entry. A question answered correctly this round is
    /// removed even if it was wrong before — that is the point of review.
    public mutating func record(correct: Set<Int> = [], wrong: Set<Int> = []) {
        ids.subtract(correct)
        ids.formUnion(wrong)
    }

    public func contains(_ id: Int) -> Bool {
        ids.contains(id)
    }
}
