import Foundation

/// Wikipedia と通信するサービスのインターフェース
///
/// ViewModel のテスト時にモックを差し替えられるように protocol 化している。
/// Phase 1 で実装した `WikipediaService` をそのまま適合させる。
///
/// `Sendable` 適合: @MainActor 隔離された ViewModel から非隔離の非同期メソッドを
/// 呼び出すため、実装を Swift 6 の並行性チェックで安全に渡せるようにする。
protocol WikipediaServiceProtocol: Sendable {
    /// 記事タイトルを検索する
    /// - Parameters:
    ///   - query: 検索クエリ
    ///   - limit: 最大取得件数
    func search(query: String, limit: Int) async throws -> [String]

    /// 記事本文と内部リンク一覧を取得する
    /// - Parameter title: 記事タイトル
    func fetchArticle(title: String) async throws -> (text: String, links: [String])
}

extension WikipediaServiceProtocol {
    /// プロトコルではデフォルト引数が使えないため、
    /// `limit` 省略時に既定件数で呼び出せるヘルパーを提供する。
    func search(query: String) async throws -> [String] {
        return try await search(query: query, limit: WikipediaService.defaultSearchLimit)
    }
}

extension WikipediaService: WikipediaServiceProtocol {}
