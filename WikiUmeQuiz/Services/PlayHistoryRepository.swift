import Foundation
import SwiftData

/// プレイ履歴（`PlayHistory`）の永続化を担うリポジトリ
///
/// 責務:
/// - `PlayHistory` の保存（`save`）
/// - 最近のプレイ履歴を最新順に取得（`fetchRecent`）
///
/// 設計方針:
/// - SwiftData の `ModelContext` は `@MainActor` 文脈で扱うのが安全なため
///   クラス自体に `@MainActor` を付与する。View / ViewModel 層からの呼び出しは
///   いずれも MainActor 上で行われる想定。
/// - 例外は呼び出し側に伝搬させず、このリポジトリ内で握りつぶさずに
///   原因特定可能な `print` ログで記録する（品質基準: トラブル時のログ）。
/// - SOLID: 単一責任（永続化のみ）/ DIP（`ModelContext` を注入）。
@MainActor
final class PlayHistoryRepository {

    // MARK: - Dependencies

    /// SwiftData の操作対象コンテキスト。
    /// 呼び出し元（View の `@Environment(\.modelContext)` など）から注入する。
    private let context: ModelContext

    // MARK: - Init

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Save

    /// プレイ履歴を 1 件保存する
    ///
    /// - Parameters:
    ///   - articleTitle: 出題元の Wikipedia 記事タイトル
    ///   - difficulty: 難易度
    ///   - score: 計算済みスコア
    ///   - correctCount: 正解数
    ///   - totalCount: 問題総数
    ///   - timeSeconds: クリアにかかった秒数
    ///   - hintsUsed: ヒント使用回数
    ///
    /// `playedAt` には呼び出し時点の `Date()` を記録する。
    /// 同じ記事を複数回プレイした場合も別レコードとして保存する（仕様）。
    func save(
        articleTitle: String,
        difficulty: QuizDifficulty,
        score: Int,
        correctCount: Int,
        totalCount: Int,
        timeSeconds: Int,
        hintsUsed: Int
    ) {
        let history = PlayHistory(
            articleTitle: articleTitle,
            difficulty: difficulty.rawValue,
            score: score,
            correctCount: correctCount,
            totalCount: totalCount,
            timeSeconds: timeSeconds,
            hintsUsed: hintsUsed,
            playedAt: Date()
        )
        context.insert(history)
        do {
            try context.save()
        } catch {
            // ユーザー体験を壊さないため throw せず、原因特定用ログのみ残す
            print("[PlayHistoryRepository] save failed: \(error)")
        }
    }

    // MARK: - Fetch

    /// 最近のプレイ履歴を取得する（最新順）
    ///
    /// - Parameter limit: 取得する最大件数
    /// - Returns: `playedAt` 降順にソートされた履歴配列。
    ///            失敗時・0 件時は空配列を返す。
    func fetchRecent(limit: Int) -> [PlayHistory] {
        var descriptor = FetchDescriptor<PlayHistory>(
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        do {
            return try context.fetch(descriptor)
        } catch {
            print("[PlayHistoryRepository] fetch failed: \(error)")
            return []
        }
    }
}
