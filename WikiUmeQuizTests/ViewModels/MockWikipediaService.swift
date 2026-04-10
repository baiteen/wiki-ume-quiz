import Foundation
@testable import WikiUmeQuiz

/// ViewModel テスト用の WikipediaService モック
///
/// 任意の検索結果・記事内容を事前に仕込める。`shouldFail` を true に
/// すると全メソッドが `WikipediaServiceError.invalidResponse` を投げる。
final class MockWikipediaService: WikipediaServiceProtocol, @unchecked Sendable {
    var searchResult: [String] = []
    var articleResult: (text: String, links: [String]) = ("", [])
    var shouldFail: Bool = false

    func search(query: String, limit: Int) async throws -> [String] {
        if shouldFail { throw WikipediaServiceError.invalidResponse }
        return searchResult
    }

    func fetchArticle(title: String) async throws -> (text: String, links: [String]) {
        if shouldFail { throw WikipediaServiceError.invalidResponse }
        return articleResult
    }
}
