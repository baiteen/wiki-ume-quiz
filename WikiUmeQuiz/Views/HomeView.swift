import SwiftUI
import SwiftData

/// ホーム画面
///
/// 責務:
/// - Wikipedia 記事検索（`.searchable` + debounce 500ms）
/// - 検索結果一覧の表示
/// - カテゴリ一覧（`Category`）の表示と、カテゴリ別記事一覧への遷移
/// - 記事選択時の `ArticleSelectView` への遷移
/// - 最近プレイした記事一覧（SwiftData 永続化）の表示
struct HomeView: View {

    // MARK: - Constants

    /// 検索入力の debounce 時間（ミリ秒）
    private static let searchDebounceMilliseconds = 500

    // MARK: - State

    @State private var viewModel: HomeViewModel
    @State private var searchTask: Task<Void, Never>?

    /// SwiftData のモデルコンテキスト（履歴読込に使用）
    @Environment(\.modelContext) private var modelContext

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

                recentHistoriesSection

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
            .task {
                // 画面表示時に最近プレイした履歴を読み込む
                viewModel.loadRecentHistories(context: modelContext)
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

    /// 「最近プレイした記事」セクション
    ///
    /// SwiftData から読み込んだ履歴を最新順に最大 `HomeViewModel.recentHistoriesLimit` 件表示する。
    /// 空の場合はセクションごと非表示にする。
    @ViewBuilder
    private var recentHistoriesSection: some View {
        if !viewModel.recentHistories.isEmpty {
            Section("最近プレイした記事") {
                ForEach(viewModel.recentHistories) { history in
                    NavigationLink(value: history.articleTitle) {
                        recentHistoryRow(history)
                    }
                }
            }
        }
    }

    /// 最近プレイ 1 行の表示
    private func recentHistoryRow(_ history: PlayHistory) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(history.articleTitle)
            HStack {
                Text(QuizDifficulty(rawValue: history.difficulty)?.displayName ?? "-")
                Spacer()
                Text("スコア \(history.score)")
                Text("\(history.correctCount)/\(history.totalCount)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
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
        .modelContainer(for: PlayHistory.self, inMemory: true)
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
