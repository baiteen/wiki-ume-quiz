import SwiftUI

/// クイズ画面
///
/// 責務:
/// - 穴埋めテキストの表示（Phase 8 で AttributedString ハイライトに刷新）
/// - 現在の問題への入力（TextField + 決定ボタン）
/// - ヒント／ギブアップ操作
/// - 経過時間・進捗・直近の解答結果の表示
///
/// クイズの状態管理は `QuizViewModel` に委譲する。
/// Phase 7 以降は完了時に親 `HomeView` 由来の `navigationPath` に
/// `ResultRoute` を append して `ResultView` へ遷移する。
///
/// Phase 8 UX 改善:
/// - `[N:____]` を AttributedString で装飾し、現在の問題はオレンジ背景でハイライト、
///   未来の問題はグレー、解答済みは正解→緑、不正解→赤打消し線で表示する。
/// - 画面上部に「いまの もんだい」バッジを大きく表示し、現在の問題が
///   どこを探すべきかを直感的に伝える。
struct QuizView: View {

    // MARK: - Layout constants

    private static let bodyFontSize: CGFloat = 17
    private static let recentResultsCount: Int = 3
    private static let badgeCornerRadius: CGFloat = 12

    // MARK: - Highlight constants

    /// 現在の問題ハイライト背景色
    private static let currentBlankBackground = Color.orange
    /// 現在の問題ハイライト文字色
    private static let currentBlankForeground = Color.white
    /// 未来の問題（未解答）の文字色
    private static let upcomingBlankForeground = Color.gray
    /// 正解時の文字色
    private static let correctAnswerForeground = Color.green
    /// 不正解時の文字色
    private static let incorrectAnswerForeground = Color.red
    /// バッジ背景色
    private static let badgeBackground = Color.orange.opacity(0.15)

    // MARK: - Blank rendering

    /// 各穴埋めの表示状態
    ///
    /// `attributedDisplayText` を構築する際に各穴埋めをどの装飾で
    /// 描画するか決定するために使用する内部列挙型。
    private enum BlankDisplayState {
        /// 現在解答中の問題
        case current
        /// まだ出題前の問題
        case upcoming
        /// 解答済みかつ正解
        case correct(answer: String)
        /// 解答済みかつ不正解
        case incorrect(userAnswer: String, correctAnswer: String)
    }

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

            // Phase 8: 画面上部の「いまの もんだい」バッジ
            // 本文中の穴埋めを探さなくても、現在問題が常時はっきり見えるようにする
            if let current = viewModel.currentQuestion {
                currentQuestionBadge(current)
            }

            Divider()

            ScrollView {
                Text(attributedDisplayText)
                    .font(.system(size: Self.bodyFontSize))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
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

    // MARK: - Attributed display text

    /// 穴埋め箇所をハイライトした本文
    ///
    /// `viewModel.quiz.displayText` 中の `[N:____]` パターンを順に検索し、
    /// 各穴埋めの状態（現在 / 未来 / 正解 / 不正解）に応じた装飾を適用する。
    ///
    /// - 現在: オレンジ背景・白文字・太字
    /// - 未来: グレー文字・下線（まだ未出題）
    /// - 正解: 緑色・太字で正解の文字列に置換
    /// - 不正解: 赤色・打消し線で「ユーザー入力（正解）」に置換
    private var attributedDisplayText: AttributedString {
        var text = AttributedString(viewModel.quiz.displayText)

        for blank in viewModel.quiz.blanks {
            let marker = "[\(blank.number):____]"
            guard let range = text.range(of: marker) else { continue }

            let state = blankState(for: blank)
            applyBlankDecoration(state: state, range: range, in: &text)
        }

        return text
    }

    /// 1 つの穴埋めに対する装飾を `AttributedString` に適用する
    ///
    /// - Parameters:
    ///   - state: 穴埋めの表示状態
    ///   - range: `[N:____]` プレースホルダの範囲
    ///   - text: 装飾対象の `AttributedString`（in-out）
    private func applyBlankDecoration(
        state: BlankDisplayState,
        range: Range<AttributedString.Index>,
        in text: inout AttributedString
    ) {
        switch state {
        case .current:
            text[range].font = .system(size: Self.bodyFontSize, weight: .bold)
            text[range].backgroundColor = Self.currentBlankBackground
            text[range].foregroundColor = Self.currentBlankForeground

        case .upcoming:
            text[range].foregroundColor = Self.upcomingBlankForeground
            text[range].underlineStyle = .single

        case .correct(let answer):
            var replacement = AttributedString(answer)
            replacement.foregroundColor = Self.correctAnswerForeground
            replacement.font = .system(size: Self.bodyFontSize, weight: .bold)
            text.replaceSubrange(range, with: replacement)

        case .incorrect(let userAnswer, let correctAnswer):
            // 未回答の場合は "(未回答)" の代替表示にする
            let displayedUserAnswer = userAnswer.isEmpty ? "(未回答)" : userAnswer
            var replacement = AttributedString("\(displayedUserAnswer) (\(correctAnswer))")
            replacement.foregroundColor = Self.incorrectAnswerForeground
            replacement.font = .system(size: Self.bodyFontSize, weight: .bold)
            replacement.strikethroughStyle = .single
            text.replaceSubrange(range, with: replacement)
        }
    }

    /// 指定の穴埋めが現時点でどの状態にあるかを判定する
    ///
    /// 解答済み（results に存在）→ 現在問題（currentQuestion と一致）→ それ以外（未来）
    /// の優先順位で評価する。
    private func blankState(for blank: QuizQuestion) -> BlankDisplayState {
        if let result = viewModel.results.first(where: { $0.questionNumber == blank.number }) {
            if result.isCorrect {
                return .correct(answer: result.correctAnswer)
            } else {
                return .incorrect(
                    userAnswer: result.userAnswer,
                    correctAnswer: result.correctAnswer
                )
            }
        }
        if let current = viewModel.currentQuestion, current.number == blank.number {
            return .current
        }
        return .upcoming
    }

    // MARK: - Current question badge

    /// 画面上部の「いまの もんだい」バッジ
    ///
    /// 大きな文字で現在の問題番号と種別を表示し、
    /// プレイヤーが本文中の穴埋めを見失わないようにする。
    private func currentQuestionBadge(_ question: QuizQuestion) -> some View {
        VStack(spacing: 4) {
            Text("いまの もんだい")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text("問 \(question.number)")
                    .font(.title2.bold())
                Text("[\(typeLabel(question.type))]")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Self.badgeBackground)
        .cornerRadius(Self.badgeCornerRadius)
        .padding(.horizontal)
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
