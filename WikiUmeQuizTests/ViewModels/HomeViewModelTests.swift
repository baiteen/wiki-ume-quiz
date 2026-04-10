import XCTest
@testable import WikiUmeQuiz

/// HomeViewModel の単体テスト
///
/// モックの WikipediaService を注入し、検索結果のハンドリングと
/// エラー時の挙動を検証する。
final class HomeViewModelTests: XCTestCase {

    // MARK: - 初期状態

    @MainActor
    func test_initialState_emptyQuery_noResults() {
        let vm = HomeViewModel(wikipediaService: MockWikipediaService())
        XCTAssertEqual(vm.query, "")
        XCTAssertEqual(vm.searchResults.count, 0)
        XCTAssertFalse(vm.isSearching)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - 検索成功

    @MainActor
    func test_search_populatesResults() async {
        let mock = MockWikipediaService()
        mock.searchResult = ["東京タワー", "東京都"]
        let vm = HomeViewModel(wikipediaService: mock)
        vm.query = "東京"
        await vm.performSearch()
        XCTAssertEqual(vm.searchResults, ["東京タワー", "東京都"])
        XCTAssertFalse(vm.isSearching)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - 空クエリ

    @MainActor
    func test_search_emptyQuery_clearsResults() async {
        let mock = MockWikipediaService()
        mock.searchResult = ["東京タワー"]
        let vm = HomeViewModel(wikipediaService: mock)
        vm.query = "東京"
        await vm.performSearch()
        vm.query = ""
        await vm.performSearch()
        XCTAssertEqual(vm.searchResults.count, 0)
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor
    func test_search_whitespaceOnlyQuery_clearsResults() async {
        let mock = MockWikipediaService()
        mock.searchResult = ["東京タワー"]
        let vm = HomeViewModel(wikipediaService: mock)
        vm.query = "   "
        await vm.performSearch()
        XCTAssertEqual(vm.searchResults.count, 0)
    }

    // MARK: - エラー

    @MainActor
    func test_search_error_setsErrorMessage() async {
        let mock = MockWikipediaService()
        mock.shouldFail = true
        let vm = HomeViewModel(wikipediaService: mock)
        vm.query = "東京"
        await vm.performSearch()
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(vm.searchResults.count, 0)
        XCTAssertFalse(vm.isSearching)
    }
}
