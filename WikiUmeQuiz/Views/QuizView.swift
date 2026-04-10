import SwiftUI

/// クイズ画面
///
/// 責務:
/// - 穴埋めテキストの表示
/// - 現在の問題への入力（TextField + 決定ボタン）
/// - ヒント／ギブアップ操作
/// - 経過時間・進捗・直近の解答結果の表示
///
/// クイズの状態管理は `QuizViewModel` に委譲する。
/// Phase 7 以降は完了時に親 `HomeView` 由来の `navigationPath` に
/// `ResultRoute` を append して `ResultView` へ遷移する。
struct QuizView: View {

    // MARK: - Layout constants

    private static let bodyFontSize: CGFloat = 16
    private static let recentResultsCount: Int = 3

    // MARK: - State

    @State var viewModel: QuizViewModel
    @State private var userInput: String = ""
    @FocusState private var isInputFocused: Bool

    /// 共有ナビゲーションスタック。完了時に `ResultRoute` を append する。
    @Binding var navigationPath: NavigationPath

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            header
            Divider()

            ScrollView {
                Text(viewModel.quiz.displayText)
                    .font(.system(size: Self.bodyFontSize))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            if let question = viewModel.currentQuestion {
                currentQuestionSection(question)
            }

            recentResultsSection
        }
        .navigationTitle(viewModel.articleTitle)
        .navigationBarTitleDisplayMode(.inline)
        // 完了後にスワイプで戻ってもクイズ途中状態に戻れないようにする
        .navigationBarBackButtonHidden(viewModel.isCompleted)
        .onAppear {
            viewModel.startTimer()
            isInputFocused = true
        }
        .onDisappear {
            viewModel.stopTimer()
        }
        .onChange(of: viewModel.isCompleted) { _, completed in
            if completed {
                navigateToResult()
            }
        }
    }

    // MARK: - Navigation

    /// `QuizViewModel` の状態から `ResultRoute` を構築し、
    /// `navigationPath` に append してリザルト画面へ遷移する
    private func navigateToResult() {
        let route = ResultRoute(
            articleTitle: viewModel.articleTitle,
            difficulty: viewModel.quiz.difficulty,
            correctCount: viewModel.correctCount,
            totalCount: viewModel.totalCount,
            timeSeconds: viewModel.elapsedSeconds,
            hintsUsed: viewModel.hintsUsed,
            results: viewModel.results
        )
        navigationPath.append(route)
    }

    // MARK: - Header

    /// 経過時間・進捗・ギブアップボタンを表示するヘッダー
    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("⏱ \(viewModel.elapsedTimeText)")
                    .font(.system(.body, design: .monospaced))
                Text("問 \(viewModel.progressText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("ギブアップ", role: .destructive) {
                viewModel.giveUp()
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Current question input

    /// 現在の問題に対する入力欄とヒントボタンを表示する
    private func currentQuestionSection(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("問\(question.number)（\(typeLabel(question.type))）")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField("ここに答えを入力", text: $userInput)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .submitLabel(.done)
                    .onSubmit { submit() }
                Button("決定") { submit() }
                    .disabled(userInput.isEmpty)
            }
            HStack {
                Button("ヒント (1文字目)") {
                    let hint = viewModel.useHint()
                    if !hint.isEmpty {
                        userInput = hint
                        isInputFocused = true
                    }
                }
                .font(.caption)
                Spacer()
                Text("ヒント使用: \(viewModel.hintsUsed)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Recent results

    /// 直近の解答結果を表示する（画面下部）
    private var recentResultsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(viewModel.results.suffix(Self.recentResultsCount))) { result in
                HStack {
                    Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.isCorrect ? .green : .red)
                    Text("問\(result.questionNumber)")
                        .font(.caption)
                    Text(result.userAnswer.isEmpty ? "(未回答)" : result.userAnswer)
                        .font(.caption)
                        .strikethrough(!result.isCorrect)
                    if !result.isCorrect {
                        Text("→ \(result.correctAnswer)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    /// 入力内容を ViewModel に送信する
    private func submit() {
        guard !userInput.isEmpty else { return }
        viewModel.submitAnswer(userInput)
        userInput = ""
        isInputFocused = true
    }

    /// `BlankType` を日本語ラベルに変換する
    private func typeLabel(_ type: BlankType) -> String {
        switch type {
        case .katakana: return "カタカナ語"
        case .number: return "数字"
        case .link: return "関連語"
        case .paren: return "括弧内"
        }
    }
}

// MARK: - Preview

#Preview {
    let quiz = Quiz(
        displayText: "[1:____]は高さ[2:____]メートルの[3:____]です。",
        blanks: [
            QuizQuestion(number: 1, answer: "タワー", type: .katakana),
            QuizQuestion(number: 2, answer: "333", type: .number),
            QuizQuestion(number: 3, answer: "電波塔", type: .link),
        ],
        difficulty: .normal
    )
    return QuizViewPreviewWrapper(quiz: quiz)
}

/// `QuizView` のプレビュー用ラッパー
///
/// `@State` の `NavigationPath` を生成して `Binding` を渡すための容器。
private struct QuizViewPreviewWrapper: View {
    let quiz: Quiz
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            QuizView(
                viewModel: QuizViewModel(quiz: quiz, articleTitle: "東京タワー"),
                navigationPath: $path
            )
        }
    }
}
