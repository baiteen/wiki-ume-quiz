import XCTest
@testable import WikiUmeQuiz

/// ArticleSelectViewModel の単体テスト
///
/// モックの WikipediaService を使い、記事取得・プレビュー生成・クイズ生成の挙動を検証する。
final class ArticleSelectViewModelTests: XCTestCase {

    // MARK: - 記事取得成功

    @MainActor
    func test_loadArticle_populatesPreview() async {
        let mock = MockWikipediaService()
        mock.articleResult = (
            "東京タワーは高さ333メートルの電波塔です。赤と白の塗装が特徴。",
            ["電波塔"]
        )
        let vm = ArticleSelectViewModel(articleTitle: "東京タワー", wikipediaService: mock)
        await vm.loadArticle()

        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.previewText.contains("東京タワー"))
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.fullText.isEmpty)
    }

    // MARK: - 記事取得エラー

    @MainActor
    func test_loadArticle_error_setsErrorMessage() async {
        let mock = MockWikipediaService()
        mock.shouldFail = true
        let vm = ArticleSelectViewModel(articleTitle: "東京タワー", wikipediaService: mock)
        await vm.loadArticle()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.fullText.isEmpty)
    }

    // MARK: - クイズ生成

    @MainActor
    func test_startQuiz_returnsQuizWithSelectedDifficulty() async {
        let mock = MockWikipediaService()
        // カタカナ語・数字・リンクを含み、候補が必ず抽出されるテキスト
        mock.articleResult = (
            "東京タワーは高さ333メートル、1958年竣工の電波塔。東京都にあります。",
            ["電波塔", "東京都"]
        )
        let vm = ArticleSelectViewModel(articleTitle: "東京タワー", wikipediaService: mock)
        await vm.loadArticle()

        let quiz = vm.startQuiz(difficulty: .normal)
        XCTAssertNotNil(quiz)
        XCTAssertEqual(quiz?.difficulty, .normal)
    }

    @MainActor
    func test_startQuiz_beforeLoad_returnsNil() {
        let mock = MockWikipediaService()
        let vm = ArticleSelectViewModel(articleTitle: "東京タワー", wikipediaService: mock)
        let quiz = vm.startQuiz(difficulty: .easy)
        XCTAssertNil(quiz, "読み込み前はクイズを生成できない")
    }
}
