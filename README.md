# DrillKit

A small Swift package for the parts every exam-prep app needs and nobody enjoys
writing twice: scoring a diagnostic, planning practice sessions that don't repeat
themselves, and keeping a review list of the questions a learner got wrong.

Extracted from two shipped iOS apps — [KIIP RU](#) and [TOPIK Daily](#) — where
these rules were the difference between an app that feels smart and one that
feels broken.

Built by [Sergei Atanov](https://www.linkedin.com/in/sergei-atanov-96b966428/).
Available for SwiftUI iOS work, App Store troubleshooting and TestFlight support:
[Fiverr gig](http://www.fiverr.com/s/8xd4QbV).

```swift
.package(url: "https://github.com/aihanhook-ops/DrillKit", from: "1.0.0")
```

## Usage

Define your own topics:

```swift
enum Topic: String, QuizTopic {
    case vocabulary, grammar, reading, listening
}
```

Score a first-run diagnostic and find out what to teach first:

```swift
let planner = SessionPlanner(bank: questions)
let quiz = planner.diagnostic(count: 15)

let result = Diagnostic.score(questions: quiz, answers: answers)
result.accuracy          // 0.6
result.weakestTopic      // .listening
result.band(thresholds: [(0.8, "advanced"), (0.45, "intermediate")],
            fallback: "beginner")   // "intermediate"
```

Plan a practice session that respects what the learner has already seen:

```swift
let session = planner.session(topic: .listening, count: 5, seen: seenIDs)
```

Keep a review list that survives app launches without a database:

```swift
@AppStorage("mistakes") private var stored = ""

var log = MistakeLog(rawValue: stored)
log.record(correct: [12, 15], wrong: [23])
stored = log.rawValue
```

## Three decisions worth explaining

**Sessions prefer unseen questions.** The obvious implementation is
`pool.shuffled().prefix(count)`. It re-serves questions the learner just answered
while dozens sit untouched, and users read that as a bug. `SessionPlanner` draws
from the unseen pool first and only falls back to repeats to fill the remainder,
so a session is always full length even at the end of a topic.

**The weakest topic is deterministic.** When two topics tie, ties break by
declaration order rather than by whatever the dictionary hands back. A daily plan
that changes its mind between launches on identical data looks broken.

**The mistake log is a sorted string, not a database.** A few hundred integer ids
do not justify Core Data. Sorting on write keeps the stored value stable, so it
isn't rewritten on every launch. Malformed entries are skipped rather than
crashing — content files are edited by hand and eventually will be wrong.

## Tests

22 tests covering the edges that actually bite: empty banks, division by zero on
an unanswered diagnostic, requesting more questions than exist, tie-breaking,
malformed storage strings, and the fresh/repeat fallback. Shuffling is tested
with a seeded generator so results are reproducible.

```
swift test
```

## Requirements

iOS 16+ / macOS 13+, Swift 5.9. No dependencies.

## License

MIT
