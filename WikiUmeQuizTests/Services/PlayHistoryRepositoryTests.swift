import XCTest
import SwiftData
@testable import WikiUmeQuiz

/// `PlayHistoryRepository` の単体テスト
///
/// - in-memory な `ModelContainer` を使い、ディスク I/O を伴わずに検証する。
/// - 責務範囲: `save` による永続化、`fetchRecent` による最新順ソートと
///   limit の尊重、空状態での挙動。
/// - SwiftData の `ModelContext` は `@MainActor` 文脈から扱うため、
///   テストメソッドは `@MainActor` とする。
@MainActor
final class PlayHistoryRepositoryTests: XCTestCase {

    // MARK: - Helpers

    /// 各テストで独立した in-memory ModelContext を生成する
    private func makeInMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PlayHistory.self,
            configurations: config
        )
        return ModelContext(container)
    }

    // MARK: - save

    /// `save` が 1 件の履歴を正しく永続化すること
    func test_save_persistsPlayHistory() throws {
        let context = try makeInMemoryContext()
        let repo = PlayHistoryRepository(context: context)

        repo.save(
            articleTitle: "東京タワー",
            difficulty: .normal,
            score: 28,
            correctCount: 8,
            totalCount: 10,
            timeSeconds: 120,
            hintsUsed: 2
        )

        let histories = repo.fetchRecent(limit: 10)
        XCTAssertEqual(histories.count, 1)
        XCTAssertEqual(histories[0].articleTitle, "東京タワー")
        XCTAssertEqual(histories[0].difficulty, QuizDifficulty.normal.rawValue)
        XCTAssertEqual(histories[0].score, 28)
        XCTAssertEqual(histories[0].correctCount, 8)
        XCTAssertEqual(histories[0].totalCount, 10)
        XCTAssertEqual(histories[0].timeSeconds, 120)
        XCTAssertEqual(histories[0].hintsUsed, 2)
    }

    // MARK: - fetchRecent sort order

    /// `fetchRecent` が `playedAt` の降順（最新優先）で返すこと
    func test_fetchRecent_orderedByMostRecent() throws {
        let context = try makeInMemoryContext()
        let repo = PlayHistoryRepository(context: context)

        // 時刻を手動で指定して順序を制御する
        let history1 = PlayHistory(
            articleTitle: "A",
            difficulty: QuizDifficulty.easy.rawValue,
            score: 5,
            correctCount: 5,
            totalCount: 10,
            timeSeconds: 60,
            hintsUsed: 0,
            playedAt: Date(timeIntervalSince1970: 1000)
        )
        let history2 = PlayHistory(
            articleTitle: "B",
            difficulty: QuizDifficulty.normal.rawValue,
            score: 10,
            correctCount: 5,
            totalCount: 10,
            timeSeconds: 60,
            hintsUsed: 0,
            playedAt: Date(timeIntervalSince1970: 3000)
        )
        let history3 = PlayHistory(
            articleTitle: "C",
            difficulty: QuizDifficulty.hard.rawValue,
            score: 15,
            correctCount: 5,
            totalCount: 10,
            timeSeconds: 60,
            hintsUsed: 0,
            playedAt: Date(timeIntervalSince1970: 2000)
        )

        context.insert(history1)
        context.insert(history2)
        context.insert(history3)
        try context.save()

        let histories = repo.fetchRecent(limit: 10)
        XCTAssertEqual(histories.count, 3)
        XCTAssertEqual(histories[0].articleTitle, "B") // 最新
        XCTAssertEqual(histories[1].articleTitle, "C")
        XCTAssertEqual(histories[2].articleTitle, "A") // 最古
    }

    // MARK: - fetchRecent limit

    /// `fetchRecent(limit:)` が上限件数を厳守すること
    func test_fetchRecent_limitRespected() throws {
        let context = try makeInMemoryContext()
        let repo = PlayHistoryRepository(context: context)

        // 15 件投入して、10 件で打ち切られることを確認する
        let totalInserted = 15
        for index in 0..<totalInserted {
            let history = PlayHistory(
                articleTitle: "記事\(index)",
                difficulty: QuizDifficulty.normal.rawValue,
                score: index,
                correctCount: index,
                totalCount: 10,
                timeSeconds: 60,
                hintsUsed: 0,
                playedAt: Date(timeIntervalSince1970: TimeInterval(index * 100))
            )
            context.insert(history)
        }
        try context.save()

        let histories = repo.fetchRecent(limit: 10)
        XCTAssertEqual(histories.count, 10)
    }

    // MARK: - fetchRecent empty

    /// 0 件のときは空配列を返すこと
    func test_fetchRecent_empty_returnsEmpty() throws {
        let context = try makeInMemoryContext()
        let repo = PlayHistoryRepository(context: context)

        let histories = repo.fetchRecent(limit: 10)
        XCTAssertEqual(histories.count, 0)
    }
}
