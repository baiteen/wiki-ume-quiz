import SwiftUI

/// クイズ画面（B案: 1 問 1 画面集中型）
///
/// 責務:
/// - 現在の穴埋め問題を画面中央に「？？？？」として大きく表示する
/// - 現問題を含む文の前後文脈（既定で前後 1 文ずつ）を小さく表示する
/// - 現在の問題への入力（TextField + 決定ボタン）
/// - ヒント／ギブアップ操作
/// - 経過時間・進捗・直近の解答結果の表示
///
/// 方針変更（2026-04-11 CEO判断）:
/// 従来の A 案「本文全体表示型」ではクイズ中に Wikipedia 記事全文を読む
/// 体験が強制され、穴埋め箇所を視覚的に見つけづらい課題があった。
/// CEO から「大人向け／読書体験いらない／すぐ」との判断を受けて B 案に刷新。
/// 全文スクロールを廃止し、現問題だけにフォーカスする。
///
/// 文の切り出しロジック:
/// `QuizViewModel.contextForCurrentQuestion()` が `Quiz.displayText` を
/// 句点「。」で分割し、現問題を含む文の前後 N 文を返す。
/// 本 View は得られた前/現/後のテキスト中の `[N:____]` プレースホルダを
/// `AttributedString` で装飾して描画する。
struct QuizView: View {

    // MARK: - Layout constants

    /// 現問題（中央大表示）のフォントサイズ
    private static let currentSentenceFontSize: CGFloat = 22
    /// 周辺文脈（前後の文）のフォントサイズ
    private static let contextFontSize: CGFloat = 13
    /// 現問題カードの角丸
    private static let currentCardCornerRadius: CGFloat = 16
    /// 周辺文脈ブロックの最大高さ（スクロール許容）
    private static let contextBlockMaxHeight: CGFloat = 90
    /// 直近の解答結果を何件まで表示するか
    private static let recentResultsCount: Int = 3

    // MARK: - Highlight constants

    /// 現問題の「？？？？」プレースホルダ背景色
    private static let currentBlankBackground = Color.orange
    /// 現問題の「？？？？」プレースホルダ文字色
    private static let currentBlankForeground = Color.white
    /// 未来（未解答）の穴埋めの文字色
    private static let upcomingBlankForeground = Color.gray
    /// 正解時の文字色
    private static let correctAnswerForeground = Color.green
    /// 不正解時の文字色
    private static let incorrectAnswerForeground = Color.red
    /// 現問題カードの背景色
    private static let currentCardBackground = Color.orange.opacity(0.12)

    // MARK: - Blank display placeholders

    /// 現問題をプレースホルダで表示する際の文字列
    private static let currentPlaceholderText = "？？？？"
    /// 未来問題をプレースホルダで表示する際の文字列
    private static let upcomingPlaceholderText = "＿＿＿＿"

    // MARK: - Blank rendering

    /// 各穴埋めの表示状態
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
        VStack(spacing: 12) {
            header

            Divider()

            if let question = viewModel.currentQuestion,
               let context = viewModel.contextForCurrentQuestion() {
                focusedQuizArea(question: question, context: context)
            } else {
                // 完了直後の空状態（自動で ResultView へ遷移する）
                Spacer()
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

    // MARK: - Focused quiz area (B案 コア)

    /// B 案の中心領域：前方文脈 / 現問題 / 後方文脈 を縦に並べる
    ///
    /// - Parameters:
    ///   - question: 現在出題中の `QuizQuestion`
    ///   - context: `QuizViewModel.contextForCurrentQuestion()` が返す周辺文脈
    private func focusedQuizArea(question: QuizQuestion, context: QuizContext) -> some View {
        VStack(spacing: 12) {
            contextBlock(text: context.beforeText, alignment: .leading)

            currentQuestionCard(question: question, sentence: context.currentSentence)

            contextBlock(text: context.afterText, alignment: .leading)
        }
        .padding(.horizontal)
    }

    /// 前後の文脈を小さめのグレーテキストで表示するブロック
    ///
    /// 空文字（冒頭／末尾問題のケース）では空の `Color.clear` を返し、
    /// レイアウト上の隙間を潰さないようにする。
    @ViewBuilder
    private func contextBlock(text: String, alignment: HorizontalAlignment) -> some View {
        if text.isEmpty {
            // スペースを確保しない（高さ 0）
            Color.clear.frame(height: 0)
        } else {
            ScrollView {
                Text(decoratedText(text))
                    .font(.system(size: Self.contextFontSize))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: Self.contextBlockMaxHeight)
        }
    }

    /// 中央に大きく表示する現問題カード
    ///
    /// 現問題の文を `AttributedString` で装飾し、
    /// `[現問題番号:____]` は「？？？？」にハイライト表示する。
    /// 同一文に含まれる他の穴埋め（解答済み／未来）は通常装飾で描画する。
    private func currentQuestionCard(question: QuizQuestion, sentence: String) -> some View {
        VStack(spacing: 8) {
            Text("問 \(question.number)  [\(typeLabel(question.type))]")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(decoratedText(sentence))
                .font(.system(size: Self.currentSentenceFontSize, weight: .medium))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Self.currentCardBackground)
                .cornerRadius(Self.currentCardCornerRadius)
        }
    }

    // MARK: - Attributed decoration

    /// 指定テキストに含まれる全ての `[N:____]` プレースホルダを装飾する
    ///
    /// 解答済み／現問題／未来 の状態に応じて置換・装飾を適用する。
    /// 前方文脈・現問題文・後方文脈のいずれにも共通して使える。
    private func decoratedText(_ raw: String) -> AttributedString {
        var text = AttributedString(raw)

        for blank in viewModel.quiz.blanks {
            let marker = "[\(blank.number):____]"
            guard let range = text.range(of: marker) else { continue }

            let state = blankState(for: blank)
            applyBlankDecoration(state: state, range: range, in: &text)
        }

        return text
    }

    /// 1 つの穴埋めに対する装飾を `AttributedString` に適用する
    private func applyBlankDecoration(
        state: BlankDisplayState,
        range: Range<AttributedString.Index>,
        in text: inout AttributedString
    ) {
        switch state {
        case .current:
            var replacement = AttributedString(Self.currentPlaceholderText)
            replacement.font = .system(size: Self.currentSentenceFontSize, weight: .bold)
            replacement.backgroundColor = Self.currentBlankBackground
            replacement.foregroundColor = Self.currentBlankForeground
            text.replaceSubrange(range, with: replacement)

        case .upcoming:
            var replacement = AttributedString(Self.upcomingPlaceholderText)
            replacement.foregroundColor = Self.upcomingBlankForeground
            text.replaceSubrange(range, with: replacement)

        case .correct(let answer):
            var replacement = AttributedString(answer)
            replacement.foregroundColor = Self.correctAnswerForeground
            replacement.font = .system(size: Self.currentSentenceFontSize, weight: .bold)
            text.replaceSubrange(range, with: replacement)

        case .incorrect(let userAnswer, let correctAnswer):
            let displayedUserAnswer = userAnswer.isEmpty ? "(未回答)" : userAnswer
            var replacement = AttributedString("\(displayedUserAnswer) (\(correctAnswer))")
            replacement.foregroundColor = Self.incorrectAnswerForeground
            replacement.font = .system(size: Self.currentSentenceFontSize, weight: .bold)
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
        displayText: "東京タワーは、東京都港区芝公園にある電波塔である。正式名称は[1:____]。高さは[2:____]メートルで、完成当時は自立式鉄塔として世界一の高さだった。塔の愛称として[3:____]が広く親しまれている。",
        blanks: [
            QuizQuestion(number: 1, answer: "日本電波塔", type: .link),
            QuizQuestion(number: 2, answer: "333", type: .number),
            QuizQuestion(number: 3, answer: "タワー", type: .katakana),
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
