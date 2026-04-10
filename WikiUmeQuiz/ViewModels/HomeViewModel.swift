import Foundation
import Observation
import SwiftData

/// ホーム画面の ViewModel
///
/// 責務:
/// - 検索クエリ `query` の保持
/// - 検索の実行（`performSearch`）
/// - 検索結果・ローディング・エラーメッセージの状態管理
/// - 最近プレイした記事一覧の読み込み（Phase 6）
///
/// `@Observable` を採用し SwiftUI から状態変更を購読する。
/// debounce（500ms）は View 側で `onChange` + `Task.sleep` で実装するため、
/// ここでは同期的に呼び出されるだけの素直な API にしている。
@MainActor
@Observable
final class HomeViewModel {

    // MARK: - Constants

    /// 「最近プレイした記事」セクションに表示する最大件数
    static let recentHistoriesLimit: Int = 10

    // MARK: - Dependencies

    private let wikipediaService: WikipediaServiceProtocol

    // MARK: - State

    /// 検索クエリ（SwiftUI の searchable とバインド）
    var query: String = ""

    /// 検索結果の記事タイトル一覧
    private(set) var searchResults: [String] = []

    /// 検索中フラグ
    private(set) var isSearching: Bool = false

    /// エラーメッセージ（nil のとき UI に表示しない）
    private(set) var errorMessage: String?

    /// 最近プレイした履歴（最新順・最大 `recentHistoriesLimit` 件）
    private(set) var recentHistories: [PlayHistory] = []

    // MARK: - Init

    init(wikipediaService: WikipediaServiceProtocol) {
        self.wikipediaService = wikipediaService
    }

    // MARK: - Recent histories

    /// 最近プレイした履歴を SwiftData から読み込む
    ///
    /// - Parameter context: `@Environment(\.modelContext)` から渡される `ModelContext`
    ///
    /// View 側の `.task` などから呼ばれる想定。
    /// 呼び出しごとに `PlayHistoryRepository` を生成するが、
    /// Repository は軽量なラッパーのためコストは小さい。
    func loadRecentHistories(context: ModelContext) {
        let repository = PlayHistoryRepository(context: context)
        self.recentHistories = repository.fetchRecent(limit: Self.recentHistoriesLimit)
    }

    // MARK: - Actions

    /// 現在の `query` で検索を実行する
    ///
    /// - 空クエリ（空白のみ含む）の場合は検索結果とエラーをクリアして即終了。
    /// - 成功時は `searchResults` を更新。
    /// - `WikipediaServiceError` の場合は `errorDescription` を表示する。
    func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            let results = try await wikipediaService.search(
                query: trimmed,
                limit: WikipediaService.defaultSearchLimit
            )
            self.searchResults = results
        } catch let error as WikipediaServiceError {
            self.errorMessage = error.errorDescription ?? "検索に失敗しました"
            self.searchResults = []
        } catch {
            self.errorMessage = "検索に失敗しました"
            self.searchResults = []
        }
    }
}
