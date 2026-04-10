import SwiftUI

/// 記事選択画面
///
/// 記事タイトルと難易度選択 UI を表示し、
/// スタートボタンで `QuizView` に遷移する。
///
/// Phase 8: 答えが見えてしまうため記事プレビュー本文の表示を廃止。
/// タイトルのみ大きく表示する。
///
/// 記事取得・クイズ生成は `ArticleSelectViewModel` に委譲する。
struct ArticleSelectView: View {

    // MARK: - Layout constants

    private static let verticalSpacing: CGFloat = 20
    private static let cornerRadius: CGFloat = 10
    private static let themeColor = Color(red: 0.2, green: 0.4, blue: 0.8)

    // MARK: - Input

    let articleTitle: String

    // MARK: - State

    @State private var viewModel: ArticleSelectViewModel
    @State private var selectedDifficulty: QuizDifficulty = .normal

    /// スタートボタン押下からクイズ生成完了までのローディング状態
    ///
    /// Phase 8: ボタン押下のフィードバックが無く「押せたかどうか分からない」
    /// という実機フィードバックを受けて追加。`true` の間はボタンを
    /// `ProgressView` 付きの「クイズを生成中...」表示に切り替え、二重押下も防ぐ。
    @State private var isGeneratingQuiz: Bool = false

    /// ルート `HomeView` から渡される共有ナビゲーションスタック
    ///
    /// スタートボタン押下時に `QuizRoute` を append することで
    /// `QuizView` に遷移する。Phase 7 で追加。
    @Binding var navigationPath: NavigationPath

    // MARK: - Init

    init(
        articleTitle: String,
        wikipediaService: WikipediaServiceProtocol = WikipediaService(),
        navigationPath: Binding<NavigationPath>
    ) {
        self.articleTitle = articleTitle
        self._viewModel = State(initialValue: ArticleSelectViewModel(
            articleTitle: articleTitle,
            wikipediaService: wikipediaService
        ))
        self._navigationPath = navigationPath
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.verticalSpacing) {
                Text(articleTitle)
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top)

                if viewModel.isLoading {
                    loadingIndicator
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                } else {
                    loadedContent
                }
            }
            .padding()
        }
        .navigationTitle("記事選択")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadArticle()
        }
    }

    // MARK: - Sub views

    private var loadingIndicator: some View {
        ProgressView("記事を取得中...")
            .frame(maxWidth: .infinity)
            .padding()
    }

    /// 記事取得完了後に表示する難易度選択＋スタートボタン
    ///
    /// Phase 8: 答えが見えてしまうため記事プレビュー本文の表示は廃止し、
    /// 「準備できたよ」というシンプルな案内に置き換えている。
    private var loadedContent: some View {
        VStack(alignment: .leading, spacing: Self.verticalSpacing) {
            Text("記事の準備ができました。難易度を選んでスタートしてください。")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            Text("難易度を選んでください")
                .font(.headline)
                .padding(.top)

            ForEach(QuizDifficulty.allCases, id: \.self) { difficulty in
                difficultyButton(for: difficulty)
            }

            startButton
                .padding(.top)
        }
    }

    /// 1 つの難易度を表すボタン（選択中は強調表示）
    private func difficultyButton(for difficulty: QuizDifficulty) -> some View {
        Button {
            selectedDifficulty = difficulty
        } label: {
            HStack {
                Text(difficulty.displayName)
                    .fontWeight(selectedDifficulty == difficulty ? .bold : .regular)
                Spacer()
                Text(Self.difficultyDescription(difficulty))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if selectedDifficulty == difficulty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(
                selectedDifficulty == difficulty
                    ? Color.blue.opacity(0.1)
                    : Color(.systemGray6)
            )
            .cornerRadius(Self.cornerRadius)
        }
        .buttonStyle(.plain)
    }

    /// クイズ開始ボタン
    ///
    /// タップ時に `QuizGenerator` でクイズを生成し、
    /// 共有 `navigationPath` に `QuizRoute` を append して `QuizView` へ遷移する。
    ///
    /// Phase 8: クイズ生成は同期処理だが大きな記事だと体感で 1〜2 秒固まるため、
    /// `isGeneratingQuiz` フラグでローディング表示を出してフィードバックを返す。
    /// `Task.yield()` を一度挟んで描画を更新したあとに重い生成処理を実行する。
    private var startButton: some View {
        Button {
            startQuiz()
        } label: {
            HStack(spacing: 8) {
                if isGeneratingQuiz {
                    ProgressView()
                        .tint(.white)
                    Text("クイズを生成中...")
                } else {
                    Text("スタート")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Self.themeColor)
            .foregroundColor(.white)
            .cornerRadius(Self.cornerRadius)
        }
        .disabled(viewModel.fullText.isEmpty || isGeneratingQuiz)
    }

    /// スタートボタン押下時の処理
    ///
    /// 1. ローディング状態へ遷移してボタン表示を切り替える
    /// 2. `Task.yield()` で UI 更新を一度走らせる
    /// 3. クイズを生成して画面遷移
    /// 4. ローディング状態を解除（遷移済みでも安全なように必ず実行）
    private func startQuiz() {
        guard !isGeneratingQuiz else { return }
        isGeneratingQuiz = true
        Task { @MainActor in
            // UI に "クイズを生成中..." を反映する隙を与える
            await Task.yield()
            defer { isGeneratingQuiz = false }
            guard let quiz = viewModel.startQuiz(difficulty: selectedDifficulty) else {
                return
            }
            navigationPath.append(
                QuizRoute(quiz: quiz, articleTitle: articleTitle)
            )
        }
    }

    // MARK: - Helpers

    /// 難易度ごとの説明テキスト
    private static func difficultyDescription(_ difficulty: QuizDifficulty) -> String {
        switch difficulty {
        case .easy: return "10%を穴埋め"
        case .normal: return "25%を穴埋め"
        case .hard: return "50%を穴埋め"
        }
    }
}
