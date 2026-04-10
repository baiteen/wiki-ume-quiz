import SwiftUI

/// 記事選択画面
///
/// 記事のプレビュー（冒頭 3 行）と難易度選択 UI を表示し、
/// スタートボタンで `QuizView` に遷移する。
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
    @State private var quizToStart: Quiz?

    // MARK: - Init

    init(
        articleTitle: String,
        wikipediaService: WikipediaServiceProtocol = WikipediaService()
    ) {
        self.articleTitle = articleTitle
        self._viewModel = State(initialValue: ArticleSelectViewModel(
            articleTitle: articleTitle,
            wikipediaService: wikipediaService
        ))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.verticalSpacing) {
                Text(articleTitle)
                    .font(.title2.bold())

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
        .navigationDestination(item: $quizToStart) { quiz in
            QuizView(
                viewModel: QuizViewModel(quiz: quiz, articleTitle: articleTitle)
            )
        }
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

    /// 記事取得完了後に表示するプレビュー＋難易度選択＋スタートボタン
    private var loadedContent: some View {
        VStack(alignment: .leading, spacing: Self.verticalSpacing) {
            Text(viewModel.previewText)
                .font(.body)
                .foregroundStyle(.secondary)

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
    private var startButton: some View {
        Button {
            if let quiz = viewModel.startQuiz(difficulty: selectedDifficulty) {
                quizToStart = quiz
            }
        } label: {
            Text("スタート")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Self.themeColor)
                .foregroundColor(.white)
                .cornerRadius(Self.cornerRadius)
        }
        .disabled(viewModel.fullText.isEmpty)
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
