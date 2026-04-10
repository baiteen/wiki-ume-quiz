import SwiftUI

/// ホーム画面
///
/// 責務:
/// - Wikipedia 記事検索（`.searchable` + debounce 500ms）
/// - 検索結果一覧の表示
/// - カテゴリ一覧（`Category`）の表示と、カテゴリ別記事一覧への遷移
/// - 記事選択時の `ArticleSelectView` への遷移
///
/// Phase 6 で「最近プレイした記事」を SwiftData から表示する想定。
struct HomeView: View {

    // MARK: - Constants

    /// 検索入力の debounce 時間（ミリ秒）
    private static let searchDebounceMilliseconds = 500

    // MARK: - State

    @State private var viewModel: HomeViewModel
    @State private var searchTask: Task<Void, Never>?

    /// View 注入のために WikipediaService を DI できるようにする
    private let wikipediaService: WikipediaServiceProtocol

    init(wikipediaService: WikipediaServiceProtocol = WikipediaService()) {
        self.wikipediaService = wikipediaService
        self._viewModel = State(
            initialValue: HomeViewModel(wikipediaService: wikipediaService)
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                statusSection

                if shouldShowEmptyResults {
                    Text("検索結果がありません")
                        .foregroundStyle(.secondary)
                }

                if !viewModel.searchResults.isEmpty {
                    Section("検索結果") {
                        ForEach(viewModel.searchResults, id: \.self) { title in
                            NavigationLink(value: title) {
                                Text(title)
                            }
                        }
                    }
                }

                categoriesSection
            }
            .navigationTitle("ウィキうめクイズ")
            .navigationDestination(for: String.self) { title in
                ArticleSelectView(
                    articleTitle: title,
                    wikipediaService: wikipediaService
                )
            }
            .searchable(text: $viewModel.query, prompt: "記事を検索")
            .onChange(of: viewModel.query) { _, _ in
                scheduleSearch()
            }
        }
    }

    // MARK: - Sections

    /// 検索中インジケータとエラーメッセージを表示する行
    @ViewBuilder
    private var statusSection: some View {
        if viewModel.isSearching {
            HStack {
                ProgressView()
                Text("検索中...")
                    .foregroundStyle(.secondary)
            }
        }
        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundStyle(.red)
                .font(.caption)
        }
    }

    /// カテゴリ一覧セクション
    private var categoriesSection: some View {
        Section("カテゴリ") {
            ForEach(Category.allCases) { category in
                NavigationLink {
                    CategoryArticlesView(
                        category: category,
                        wikipediaService: wikipediaService
                    )
                } label: {
                    Label(category.rawValue, systemImage: category.iconName)
                }
            }
        }
    }

    // MARK: - Derived

    /// 「検索結果がありません」を表示すべきか
    private var shouldShowEmptyResults: Bool {
        return viewModel.searchResults.isEmpty
            && !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isSearching
            && viewModel.errorMessage == nil
    }

    // MARK: - Search scheduling

    /// 入力が変わるたびに呼び出され、debounce してから検索を実行する
    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(Self.searchDebounceMilliseconds))
            guard !Task.isCancelled else { return }
            await viewModel.performSearch()
        }
    }
}

// MARK: - Category Articles View

/// カテゴリ別のおすすめ記事一覧画面
///
/// `Category.recommendedArticles` に定義された固定リストを表示し、
/// タップで `ArticleSelectView` に遷移する。
struct CategoryArticlesView: View {
    let category: Category
    let wikipediaService: WikipediaServiceProtocol

    var body: some View {
        List(category.recommendedArticles, id: \.self) { title in
            NavigationLink(value: title) {
                Text(title)
            }
        }
        .navigationTitle(category.rawValue)
        .navigationDestination(for: String.self) { title in
            ArticleSelectView(
                articleTitle: title,
                wikipediaService: wikipediaService
            )
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView(wikipediaService: PreviewMockWikipediaService())
}

/// SwiftUI プレビュー専用のモック
private struct PreviewMockWikipediaService: WikipediaServiceProtocol {
    func search(query: String, limit: Int) async throws -> [String] {
        ["東京タワー", "東京都", "東京スカイツリー"]
    }

    func fetchArticle(title: String) async throws -> (text: String, links: [String]) {
        ("プレビュー記事本文。高さ333メートルの電波塔です。", ["電波塔"])
    }
}
