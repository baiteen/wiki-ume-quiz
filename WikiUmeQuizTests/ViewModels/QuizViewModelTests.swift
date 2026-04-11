import XCTest
@testable import WikiUmeQuiz

/// `QuizViewModel` の振る舞いを検証するテスト
///
/// TDD で先に本ファイルを作成し、次に `QuizViewModel` を実装する。
/// ここでは ViewModel の状態遷移のみをテストし、SwiftUI Viewの描画は目視確認に委ねる。
final class QuizViewModelTests: XCTestCase {

    // MARK: - Fixture

    /// テスト用のクイズを生成する
    ///
    /// 3 問構成（カタカナ / 数字 / リンク）で、`QuizGenerator.checkAnswer`
    /// による表記ゆれ許容判定が効くことも併せて検証する。
    private func makeQuiz() -> Quiz {
        let blanks = [
            QuizQuestion(number: 1, answer: "タワー", type: .katakana),
            QuizQuestion(number: 2, answer: "1958", type: .number),
            QuizQuestion(number: 3, answer: "東京都", type: .link),
        ]
        return Quiz(
            displayText: "[1:____]は[2:____]年竣工、[3:____]にある。",
            blanks: blanks,
            difficulty: .normal
        )
    }

    // MARK: - 初期状態

    @MainActor
    func test_initialState_hasZeroProgress() {
        let vm = QuizViewModel(quiz: makeQuiz(), articleTitle: "東京タワー")
        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertEqual(vm.totalCount, 3)
        XCTAssertEqual(vm.correctCount, 0)
        XCTAssertEqual(vm.hintsUsed, 0)
        XCTAssertEqual(vm.elapsedSeconds, 0)
        XCTAssertFalse(vm.isCompleted)
        XCTAssertEqual(vm.results.count, 0)
    }

    // MARK: - 解答送信

    @MainActor
    func test_submitCorrectAnswer_incrementsCorrectCount() {
        let vm = QuizViewModel(quiz: makeQuiz(), articleTitle: "東京タワー")
        vm.submitAnswer("タワー")
        XCTAssertEqual(vm.correctCount, 1)
        XCTAssertEqual(vm.currentIndex, 1)
        XCTAssertTrue(vm.results[0].isCorrect)
        XCTAssertEqual(vm.results[0].userAnswer, "タワー")
        XCTAssertEqual(vm.results[0].correctAnswer, "タワー")
    }

    @MainActor
    func test_submitIncorrectAnswer_recordsCorrectAnswer() {
        let vm = QuizViewModel(quiz: makeQuiz(), articleTitle: "東京タワー")
        vm.submitAnswer("タイマー") // 不正解
        XCTAssertEqual(vm.correctCount, 0)
        XCTAssertEqual(vm.currentIndex, 1)
        XCTAssertFalse(vm.results[0].isCorrect)
        XCTAssertEqual(vm.results[0].userAnswer, "タイマー")
        XCTAssertEqual(vm.results[0].correctAnswer, "タワー")
    }

    @MainActor
    func test_submitAnswer_tolerantComparison() {
        // StringNormalizer によりカタカナ<->ひらがな差を吸収することを確認する
        let vm = QuizViewModel(quiz: makeQuiz(), articleTitle: "東京タワー")
        vm.submitAnswer("たわー")
        XCTAssertEqual(vm.correctCount, 1)
    }

    @MainActor
    func test_submitAnswer_allQuestions_completes() {
        let vm = QuizViewModel(quiz: makeQuiz(), articleTitle: "東京タワー")
        vm.submitAnswer("タワー")
        vm.submitAnswer("1958")
        vm.submitAnswer("東京都")
        XCTAssertTrue(vm.isCompleted)
        XCTAssertEqual(vm.correctCount, 3)
        XCTAssertEqual(vm.results.count, 3)
    }

    @MainActor
    func test_submitAnswer_afterCompleted_noOp() {
        let vm = QuizViewModel(quiz: makeQuiz(), articleTitle: "東京タワー")
        vm.giveUp()
        let beforeCorrect = vm.correctCount
        let beforeCount = vm.results.count
        vm.submitAnswer("タワー")
        XCTAssertEqual(vm.correctCount, beforeCorrect)
        XCTAssertEqual(vm.results.count, beforeCount)
    }

    // MARK: - ヒント

    @MainActor
    func test_useHint_returnsFirstCharacter() {
        let vm = QuizViewModel(quiz: makeQuiz(), articleTitle: "東京タワー")
        let hint = vm.useHint()
        XCTAssertEqual(hint, "タ")
        XCTAssertEqual(vm.hintsUsed, 1)
    }

    @MainActor
    func test_useHint_multipleCallsOnSameQuestion_countsEachCall() {
        let vm = QuizViewModel(quiz: makeQuiz(), articleTitle: "東京タワー")
        _ = vm.useHint()
        _ = vm.useHint()
        XCTAssertEqual(vm.hintsUsed, 2)
    }

    // MARK: - ギブアップ

    @MainActor
    func test_giveUp_fillsRemainingAsIncorrectAndCompletes() {
        let vm = QuizViewModel(quiz: makeQuiz(), articleTitle: "東京タワー")
        vm.submitAnswer("タワー") // 1問目正解
        vm.giveUp()
        XCTAssertTrue(vm.isCompleted)
        XCTAssertEqual(vm.correctCount, 1)
        XCTAssertEqual(vm.results.count, 3)
        XCTAssertFalse(vm.results[1].isCorrect)
        XCTAssertFalse(vm.results[2].isCorrect)
        // ギブアップ分は userAnswer が空
        XCTAssertEqual(vm.results[1].userAnswer, "")
        XCTAssertEqual(vm.results[2].userAnswer, "")
    }

    // MARK: - タイマー

    @MainActor
    func test_timer_startAndStop_updatesElapsed() async {
        let vm = QuizViewModel(quiz: makeQuiz(), articleTitle: "東京タワー")
        vm.startTimer()
        try? await Task.sleep(for: .milliseconds(1100))
        vm.stopTimer()
        XCTAssertGreaterThanOrEqual(vm.elapsedSeconds, 1)
    }

    // MARK: - 表示用プロパティ

    @MainActor
    func test_progressText_formatsCurrentOverTotal() {
        let vm = QuizViewModel(quiz: makeQuiz(), articleTitle: "東京タワー")
        XCTAssertEqual(vm.progressText, "1/3")
        vm.submitAnswer("タワー")
        XCTAssertEqual(vm.progressText, "2/3")
    }

    @MainActor
    func test_elapsedTimeText_isMmSsFormat() {
        let vm = QuizViewModel(quiz: makeQuiz(), articleTitle: "東京タワー")
        XCTAssertEqual(vm.elapsedTimeText, "00:00")
    }

    // MARK: - 周辺文脈抽出 (B案 1問1画面集中型)

    /// B 案用のフィクスチャ：多段の文と複数の穴埋めを含む displayText
    private func makeContextQuiz() -> Quiz {
        // 5 つの文にそれぞれ穴埋めを散らす
        let displayText =
            "AAA。" +
            "[1:____]は第一の文。" +
            "BBB。" +
            "[2:____]は第三の文、そこに[3:____]もある。" +
            "CCC。"
        let blanks = [
            QuizQuestion(number: 1, answer: "甲", type: .link),
            QuizQuestion(number: 2, answer: "乙", type: .link),
            QuizQuestion(number: 3, answer: "丙", type: .link),
        ]
        return Quiz(displayText: displayText, blanks: blanks, difficulty: .normal)
    }

    @MainActor
    func test_contextForCurrentQuestion_returnsNilWhenCompleted() {
        let vm = QuizViewModel(quiz: makeQuiz(), articleTitle: "東京タワー")
        vm.giveUp()
        XCTAssertNil(vm.contextForCurrentQuestion())
    }

    @MainActor
    func test_contextForCurrentQuestion_firstQuestion_returnsBeforeAndAfter() {
        let vm = QuizViewModel(quiz: makeContextQuiz(), articleTitle: "サンプル")
        let ctx = vm.contextForCurrentQuestion()
        XCTAssertNotNil(ctx)
        XCTAssertEqual(ctx?.beforeText, "AAA。")
        XCTAssertEqual(ctx?.currentSentence, "[1:____]は第一の文。")
        XCTAssertEqual(ctx?.afterText, "BBB。")
    }

    @MainActor
    func test_contextForCurrentQuestion_secondQuestion_skipsConsumedSentences() {
        // 問1解答後、問2は「[2:____]は第三の文、そこに[3:____]もある。」の文
        let vm = QuizViewModel(quiz: makeContextQuiz(), articleTitle: "サンプル")
        vm.submitAnswer("甲")
        let ctx = vm.contextForCurrentQuestion()
        XCTAssertEqual(ctx?.beforeText, "BBB。")
        XCTAssertEqual(ctx?.currentSentence, "[2:____]は第三の文、そこに[3:____]もある。")
        XCTAssertEqual(ctx?.afterText, "CCC。")
    }

    @MainActor
    func test_contextForCurrentQuestion_multipleBlanksInSameSentence_staysInSameSentence() {
        // 問2の次は問3だが、問3も「[2:____]は第三の文、そこに[3:____]もある。」の同一文にある
        let vm = QuizViewModel(quiz: makeContextQuiz(), articleTitle: "サンプル")
        vm.submitAnswer("甲") // 問1 完了
        vm.submitAnswer("乙") // 問2 完了、現在は問3
        let ctx = vm.contextForCurrentQuestion()
        XCTAssertEqual(ctx?.currentSentence, "[2:____]は第三の文、そこに[3:____]もある。")
        XCTAssertEqual(ctx?.beforeText, "BBB。")
        XCTAssertEqual(ctx?.afterText, "CCC。")
    }

    @MainActor
    func test_contextForCurrentQuestion_atBeginning_hasEmptyBefore() {
        let quiz = Quiz(
            displayText: "[1:____]は冒頭。BBB。",
            blanks: [QuizQuestion(number: 1, answer: "甲", type: .link)],
            difficulty: .normal
        )
        let vm = QuizViewModel(quiz: quiz, articleTitle: "サンプル")
        let ctx = vm.contextForCurrentQuestion()
        XCTAssertEqual(ctx?.beforeText, "")
        XCTAssertEqual(ctx?.currentSentence, "[1:____]は冒頭。")
        XCTAssertEqual(ctx?.afterText, "BBB。")
    }

    @MainActor
    func test_contextForCurrentQuestion_atEnd_hasEmptyAfter() {
        let quiz = Quiz(
            displayText: "AAA。[1:____]は末尾。",
            blanks: [QuizQuestion(number: 1, answer: "甲", type: .link)],
            difficulty: .normal
        )
        let vm = QuizViewModel(quiz: quiz, articleTitle: "サンプル")
        let ctx = vm.contextForCurrentQuestion()
        XCTAssertEqual(ctx?.beforeText, "AAA。")
        XCTAssertEqual(ctx?.currentSentence, "[1:____]は末尾。")
        XCTAssertEqual(ctx?.afterText, "")
    }

    @MainActor
    func test_contextForCurrentQuestion_singleSentence_hasEmptyBothSides() {
        let quiz = Quiz(
            displayText: "[1:____]は単独",
            blanks: [QuizQuestion(number: 1, answer: "甲", type: .link)],
            difficulty: .normal
        )
        let vm = QuizViewModel(quiz: quiz, articleTitle: "サンプル")
        let ctx = vm.contextForCurrentQuestion()
        XCTAssertEqual(ctx?.beforeText, "")
        XCTAssertEqual(ctx?.currentSentence, "[1:____]は単独")
        XCTAssertEqual(ctx?.afterText, "")
    }

    @MainActor
    func test_contextForCurrentQuestion_surroundingLines2_takesMoreSentences() {
        let quiz = Quiz(
            displayText: "AAA。BBB。[1:____]は中央。CCC。DDD。",
            blanks: [QuizQuestion(number: 1, answer: "甲", type: .link)],
            difficulty: .normal
        )
        let vm = QuizViewModel(quiz: quiz, articleTitle: "サンプル")
        let ctx = vm.contextForCurrentQuestion(surroundingLines: 2)
        XCTAssertEqual(ctx?.beforeText, "AAA。BBB。")
        XCTAssertEqual(ctx?.currentSentence, "[1:____]は中央。")
        XCTAssertEqual(ctx?.afterText, "CCC。DDD。")
    }
}
