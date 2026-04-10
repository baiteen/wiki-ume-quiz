import Foundation

// MARK: - Errors

/// WikipediaService が発生しうるエラー
enum WikipediaServiceError: LocalizedError, Equatable {
    case invalidURL
    case networkError(String)
    case invalidResponse
    case decodingError(String)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URLが不正です"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .invalidResponse:
            return "サーバーからの応答が不正です"
        case .decodingError(let message):
            return "データの解析に失敗しました: \(message)"
        case .emptyResult:
            return "記事が見つかりませんでした"
        }
    }
}

// MARK: - Service

/// Wikipedia API と連携して記事を検索・取得し、HTML をプレーンテキストとリンクに変換するサービス。
///
/// - `search(query:)` opensearch API で記事タイトルを検索
/// - `fetchArticle(title:)` REST API v1 でHTMLを取得しテキスト＋リンクに変換
/// - `extractTextAndLinks(html:)` HTML パース（純粋関数、単体テスト用）
///
/// URLSession を注入可能にすることでモックテストをサポートする。
final class WikipediaService {

    // MARK: - Constants

    /// 検索結果のデフォルト件数
    static let defaultSearchLimit = 10

    /// 記事本文として採用するパラグラフの最小文字数
    private static let minimumParagraphLength = 10

    /// 内部リンクテキストとして採用する最小文字数
    private static let minimumLinkTextLength = 2

    /// ネットワークリクエストのタイムアウト（秒）
    private static let requestTimeout: TimeInterval = 15

    /// Wikipedia の API エンドポイント
    private static let baseAPIURL = URL(string: "https://ja.wikipedia.org/w/api.php")!

    /// Wikipedia REST API v1 のエンドポイント
    private static let baseRestURL = URL(string: "https://ja.wikipedia.org/api/rest_v1/page/html/")!

    /// User-Agent ヘッダー（Wikipedia API のガイドラインに従う）
    private static let userAgent = "WikiUmeQuiz/1.0 (baiteen contact@example.com)"

    // MARK: - Properties

    private let session: URLSession

    // MARK: - Init

    /// - Parameter session: テスト時に MockURLProtocol 付きの URLSession を注入できる
    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    /// Wikipedia の opensearch API で記事タイトルを検索する。
    /// - Parameters:
    ///   - query: 検索クエリ
    ///   - limit: 最大取得件数（デフォルト 10 件）
    /// - Returns: 記事タイトル配列
    func search(query: String, limit: Int = WikipediaService.defaultSearchLimit) async throws -> [String] {
        guard !query.isEmpty else { return [] }
        let url = Self.makeSearchURL(query: query, limit: limit)
        let data = try await fetchData(from: url)
        return try Self.decodeSearchResponse(data)
    }

    /// 記事タイトルから Wikipedia REST API v1 でHTMLを取得し、プレーンテキストとリンクに変換する。
    /// - Parameter title: 記事タイトル
    /// - Returns: (本文テキスト, 内部リンクテキスト配列)
    func fetchArticle(title: String) async throws -> (text: String, links: [String]) {
        guard !title.isEmpty else {
            throw WikipediaServiceError.invalidURL
        }
        let url = Self.makeArticleURL(title: title)
        let data = try await fetchData(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw WikipediaServiceError.invalidResponse
        }
        return extractTextAndLinks(html: html)
    }

    // MARK: - URL builders

    /// opensearch API の URL を構築する
    static func makeSearchURL(query: String, limit: Int) -> URL {
        var components = URLComponents(url: baseAPIURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "opensearch"),
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "namespace", value: "0"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url else {
            // URLComponents が成功前提なので通常は到達しない
            return baseAPIURL
        }
        return url
    }

    /// REST API v1 の記事URLを構築する
    static func makeArticleURL(title: String) -> URL {
        // Wikipedia REST API ではタイトルはパーセントエンコードが必要。
        // `appendingPathComponent` は既存の `%` を再エンコードするため文字列連結で組み立てる。
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        guard let url = URL(string: baseRestURL.absoluteString + encoded) else {
            return baseRestURL
        }
        return url
    }

    // MARK: - Response decoder

    /// opensearch API のレスポンスからタイトル配列を取り出す。
    /// レスポンス形式: `[query, [titles], [descriptions], [urls]]`
    static func decodeSearchResponse(_ data: Data) throws -> [String] {
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw WikipediaServiceError.decodingError("JSON パース失敗: \(error.localizedDescription)")
        }
        guard let array = jsonObject as? [Any] else {
            throw WikipediaServiceError.decodingError("レスポンスが配列形式ではありません")
        }
        guard array.count >= 2, let titles = array[1] as? [String] else {
            throw WikipediaServiceError.decodingError("タイトル配列が取得できませんでした")
        }
        return titles
    }

    // MARK: - HTML parser

    /// HTML からプレーンテキストと内部リンクテキスト一覧を抽出する。
    ///
    /// 除去対象: `<script>`, `<style>`, `<table>`, `<sup>`, 編集リンク, reference 類
    /// 抽出対象: `<p>` と `<li>` のテキスト（10文字超のみ）、`./` で始まるhref の内部リンク
    func extractTextAndLinks(html: String) -> (text: String, links: [String]) {
        var cleaned = html

        // 1. 中身ごと除去すべきタグ
        let tagsToRemove = ["script", "style", "table", "sup"]
        for tag in tagsToRemove {
            cleaned = Self.removeTagWithContents(in: cleaned, tag: tag)
        }

        // 2. mw-editsection クラスの span を除去（編集リンク）
        cleaned = Self.removeElementsWithClass(in: cleaned, tag: "span", className: "mw-editsection")

        // 3. 内部リンクテキストを収集（最小文字数フィルタ）
        let links = Self.extractInternalLinkTexts(from: cleaned)

        // 4. <p>, <li> タグの中身を抽出し、10文字超のものだけ採用
        let paragraphs = Self.extractParagraphs(from: cleaned)
            .filter { $0.count > Self.minimumParagraphLength }

        let text = paragraphs.joined(separator: "\n")
        return (text, links)
    }

    // MARK: - HTML parser helpers

    /// 指定タグを中身ごと除去する（`<script>...</script>` 全体を削除）
    static func removeTagWithContents(in html: String, tag: String) -> String {
        let pattern = "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)>"
        return html.replacingByRegex(pattern: pattern, options: [.caseInsensitive], template: "")
    }

    /// 指定タグかつ指定クラスの要素を中身ごと除去する
    static func removeElementsWithClass(in html: String, tag: String, className: String) -> String {
        // 属性順序に柔軟な正規表現（class属性に該当クラスを含むものをマッチ）
        let pattern = "<\(tag)\\b[^>]*\\bclass=[\"'][^\"']*\\b\(className)\\b[^\"']*[\"'][^>]*>[\\s\\S]*?</\(tag)>"
        return html.replacingByRegex(pattern: pattern, options: [.caseInsensitive], template: "")
    }

    /// 内部リンク（href が `./` で始まる <a>）のテキストを抽出する
    static func extractInternalLinkTexts(from html: String) -> [String] {
        // <a ... href="./..." ...>テキスト</a> のテキスト部分をキャプチャ
        let pattern = "<a\\b[^>]*\\bhref=[\"']\\./([^\"']+)[\"'][^>]*>([\\s\\S]*?)</a>"
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        } catch {
            return []
        }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        return matches.compactMap { match -> String? in
            guard match.numberOfRanges >= 3,
                  let textRange = Range(match.range(at: 2), in: html) else {
                return nil
            }
            // リンクテキスト中のタグを除去してプレーンテキスト化
            let raw = String(html[textRange])
            let stripped = stripTags(raw)
            let decoded = decodeHTMLEntities(stripped)
            let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count >= minimumLinkTextLength ? trimmed : nil
        }
    }

    /// `<p>` と `<li>` 要素のテキストを抽出する（タグ除去・エンティティデコード済み）
    static func extractParagraphs(from html: String) -> [String] {
        let pattern = "<(p|li)\\b[^>]*>([\\s\\S]*?)</\\1>"
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        } catch {
            return []
        }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        return matches.compactMap { match -> String? in
            guard match.numberOfRanges >= 3,
                  let innerRange = Range(match.range(at: 2), in: html) else {
                return nil
            }
            let inner = String(html[innerRange])
            let withoutTags = stripTags(inner)
            let decoded = decodeHTMLEntities(withoutTags)
            return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// HTML タグを全て除去してプレーンテキストにする
    static func stripTags(_ html: String) -> String {
        return html.replacingByRegex(pattern: "<[^>]+>", options: [], template: "")
    }

    /// 主要な HTML エンティティをデコードする
    static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&nbsp;", " "),
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }

    // MARK: - Network

    /// URLSession で指定URLからデータを取得する。User-Agent とタイムアウトを設定する。
    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = Self.requestTimeout

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw WikipediaServiceError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WikipediaServiceError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw WikipediaServiceError.invalidResponse
        }
        return data
    }
}

// MARK: - String Extensions

private extension String {
    /// 正規表現による置換のヘルパー。無効な正規表現は入力をそのまま返す。
    func replacingByRegex(pattern: String, options: NSRegularExpression.Options, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return self
        }
        let range = NSRange(self.startIndex..., in: self)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: template)
    }
}
