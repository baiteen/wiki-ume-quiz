import XCTest
@testable import WikiUmeQuiz

/// WikipediaService の単体テスト。
///
/// ネットワーク呼び出しを伴うテストは外部依存を避けるため URLProtocol スタブを使用する。
/// HTML パースや URL 構築などの純粋ロジックは直接呼び出してテストする。
final class WikipediaServiceTests: XCTestCase {

    // MARK: - HTML パース

    func test_extractTextAndLinks_basicHTML_returnsTextAndLinks() {
        let html = """
        <html><body>
          <p>東京タワーは<a href="./東京都">東京都</a>港区にある電波塔です。</p>
          <p>1958年に竣工した観光名所である。</p>
          <script>alert("test");</script>
          <table><tr><td>除外されるべき内容</td></tr></table>
        </body></html>
        """
        let service = WikipediaService()
        let (text, links) = service.extractTextAndLinks(html: html)

        XCTAssertTrue(text.contains("東京タワー"), "本文にタイトルが含まれるべき")
        XCTAssertTrue(text.contains("1958年"), "2段落目が含まれるべき")
        XCTAssertFalse(text.contains("除外されるべき内容"), "table の内容は除外されるべき")
        XCTAssertFalse(text.contains("alert"), "script の内容は除外されるべき")
        XCTAssertTrue(links.contains("東京都"), "内部リンクテキストが収集されるべき")
    }

    func test_extractTextAndLinks_removesEditSectionsAndReferences() {
        let html = """
        <p>これは記事本文の十分な長さの段落です。</p>
        <span class="mw-editsection">[編集]</span>
        <sup class="reference">[1]</sup>
        """
        let service = WikipediaService()
        let (text, _) = service.extractTextAndLinks(html: html)

        XCTAssertTrue(text.contains("記事本文"))
        XCTAssertFalse(text.contains("編集"), "編集リンクは除外されるべき")
        XCTAssertFalse(text.contains("[1]"), "reference は除外されるべき")
    }

    func test_extractTextAndLinks_shortParagraphIsSkipped() {
        // 10文字以下のパラグラフは除外（プロトタイプに準拠）
        let html = "<p>短い</p><p>これは十分な長さのパラグラフです。</p>"
        let service = WikipediaService()
        let (text, _) = service.extractTextAndLinks(html: html)

        XCTAssertFalse(text.contains("短い"), "10文字以下は除外されるべき")
        XCTAssertTrue(text.contains("これは十分な長さのパラグラフです"))
    }

    func test_extractTextAndLinks_collectsInternalLinksOnly() {
        // 外部リンク (http://) は除外、内部リンク (./) のみ収集
        let html = """
        <p>これはリンクを含むテストの段落です。</p>
        <a href="./内部リンク">内部</a>
        <a href="https://example.com">外部</a>
        """
        let service = WikipediaService()
        let (_, links) = service.extractTextAndLinks(html: html)

        XCTAssertTrue(links.contains("内部"), "内部リンクは収集されるべき")
        XCTAssertFalse(links.contains("外部"), "外部リンクは除外されるべき")
    }

    func test_extractTextAndLinks_filtersSingleCharacterLinks() {
        // 1文字のリンクは除外する（プロトタイプに準拠: >= 2文字）
        let html = """
        <p>リンクテキストの長さをテストします。</p>
        <a href="./あ">あ</a>
        <a href="./東京">東京</a>
        """
        let service = WikipediaService()
        let (_, links) = service.extractTextAndLinks(html: html)

        XCTAssertFalse(links.contains("あ"), "1文字リンクは除外されるべき")
        XCTAssertTrue(links.contains("東京"))
    }

    func test_extractTextAndLinks_decodesHTMLEntities() {
        let html = "<p>AT&amp;T は電話会社の略称として知られています。</p>"
        let service = WikipediaService()
        let (text, _) = service.extractTextAndLinks(html: html)

        XCTAssertTrue(text.contains("AT&T"), "HTML エンティティはデコードされるべき")
    }

    // MARK: - URL構築

    func test_makeSearchURL_containsCorrectParameters() {
        let url = WikipediaService.makeSearchURL(query: "東京タワー", limit: 10)
        let absoluteString = url.absoluteString

        XCTAssertTrue(absoluteString.contains("ja.wikipedia.org"))
        XCTAssertTrue(absoluteString.contains("action=opensearch"))
        XCTAssertTrue(absoluteString.contains("limit=10"))
        XCTAssertTrue(absoluteString.contains("format=json"))
        XCTAssertTrue(absoluteString.contains("namespace=0"))
        // URL エンコード後の「東京」= %E6%9D%B1%E4%BA%AC
        XCTAssertTrue(absoluteString.contains("%E6%9D%B1%E4%BA%AC"))
    }

    func test_makeArticleURL_containsEncodedTitle() {
        let url = WikipediaService.makeArticleURL(title: "東京タワー")
        let absoluteString = url.absoluteString

        XCTAssertTrue(absoluteString.contains("rest_v1/page/html"))
        XCTAssertTrue(absoluteString.contains("%E6%9D%B1%E4%BA%AC"))
    }

    // MARK: - Decoder

    func test_decodeSearchResponse_returnsTitles() throws {
        // Wikipedia opensearch API のレスポンス形式: [query, [titles], [descriptions], [urls]]
        let json = """
        ["東京タワー", ["東京タワー", "東京スカイツリー"], ["desc1", "desc2"], ["url1", "url2"]]
        """.data(using: .utf8)!
        let titles = try WikipediaService.decodeSearchResponse(json)
        XCTAssertEqual(titles, ["東京タワー", "東京スカイツリー"])
    }

    func test_decodeSearchResponse_emptyResult() throws {
        let json = """
        ["存在しないクエリ", [], [], []]
        """.data(using: .utf8)!
        let titles = try WikipediaService.decodeSearchResponse(json)
        XCTAssertEqual(titles, [])
    }

    func test_decodeSearchResponse_invalidFormat_throws() {
        let json = """
        {"error": "invalid"}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try WikipediaService.decodeSearchResponse(json)) { error in
            guard case WikipediaServiceError.decodingError = error else {
                XCTFail("decodingError を期待: \(error)")
                return
            }
        }
    }

    // MARK: - Network (URLProtocol スタブ)

    func test_search_withEmptyQuery_returnsEmptyArray() async throws {
        let service = WikipediaService(session: .shared)
        let results = try await service.search(query: "")
        XCTAssertEqual(results, [], "空クエリは空配列を返すべき")
    }

    func test_search_successfulResponse_returnsTitles() async throws {
        let responseJSON = """
        ["東京タワー", ["東京タワー", "東京スカイツリー"], [], []]
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseJSON)
        }

        let service = WikipediaService(session: Self.makeMockSession())
        let results = try await service.search(query: "東京")
        XCTAssertEqual(results, ["東京タワー", "東京スカイツリー"])
    }

    func test_search_setsUserAgentHeader() async throws {
        let expectation = self.expectation(description: "User-Agent が設定される")
        MockURLProtocol.requestHandler = { request in
            // URLProtocol では request.allHTTPHeaderFields が参照される
            let userAgent = request.value(forHTTPHeaderField: "User-Agent")
            XCTAssertNotNil(userAgent, "User-Agent ヘッダーが必要")
            XCTAssertTrue(userAgent?.contains("WikiUmeQuiz") == true)
            expectation.fulfill()

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let body = "[\"q\", [], [], []]".data(using: .utf8)!
            return (response, body)
        }

        let service = WikipediaService(session: Self.makeMockSession())
        _ = try await service.search(query: "test")
        await fulfillment(of: [expectation], timeout: 5)
    }

    func test_search_httpError_throwsInvalidResponse() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let service = WikipediaService(session: Self.makeMockSession())
        do {
            _ = try await service.search(query: "test")
            XCTFail("エラーがスローされるべき")
        } catch WikipediaServiceError.invalidResponse {
            // 期待どおり
        } catch {
            XCTFail("invalidResponse を期待: \(error)")
        }
    }

    func test_fetchArticle_successfulResponse_returnsTextAndLinks() async throws {
        let html = """
        <html><body>
        <p>東京タワーは<a href="./東京都">東京都</a>港区にある電波塔です。</p>
        </body></html>
        """
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, html.data(using: .utf8)!)
        }

        let service = WikipediaService(session: Self.makeMockSession())
        let (text, links) = try await service.fetchArticle(title: "東京タワー")
        XCTAssertTrue(text.contains("東京タワー"))
        XCTAssertTrue(links.contains("東京都"))
    }

    func test_fetchArticle_emptyTitle_throwsInvalidURL() async {
        let service = WikipediaService()
        do {
            _ = try await service.fetchArticle(title: "")
            XCTFail("エラーがスローされるべき")
        } catch WikipediaServiceError.invalidURL {
            // 期待どおり
        } catch {
            XCTFail("invalidURL を期待: \(error)")
        }
    }

    // MARK: - Helpers

    /// MockURLProtocol を注入した URLSession を生成する
    private static func makeMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

// MARK: - MockURLProtocol

/// URLSession のリクエストをインターセプトしてテストデータを返すスタブ
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    /// テストから設定するレスポンスハンドラ
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: NSError(
                domain: "MockURLProtocol",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "requestHandler が未設定"]
            ))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // 何もしない
    }
}
