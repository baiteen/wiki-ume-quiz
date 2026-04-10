import XCTest
@testable import WikiUmeQuiz

final class QuizGeneratorTests: XCTestCase {

    // MARK: - 候補抽出

    func test_extractCandidates_katakanaWords() {
        let text = "東京タワーは電波塔。エッフェル塔もある。"
        let candidates = QuizGenerator.extractCandidates(text: text, linkTexts: [])
        let words = candidates.map { $0.word }
        XCTAssertTrue(words.contains("タワー"))
        XCTAssertTrue(words.contains("エッフェル"))
    }

    func test_extractCandidates_numbers3DigitsOrMore() {
        // 3桁以上の数字だけを候補にする（プロトタイプに準拠）
        let text = "1958年に建設。高さ333メートル。創立は10年前。"
        let candidates = QuizGenerator.extractCandidates(text: text, linkTexts: [])
        let numbers = candidates.filter { $0.type == .number }.map { $0.word }
        XCTAssertTrue(numbers.contains("1958"))
        XCTAssertTrue(numbers.contains("333"))
        XCTAssertFalse(numbers.contains("10"))  // 2桁は除外
    }

    func test_extractCandidates_linkTextsIncluded() {
        let text = "東京タワーは東京都にある。"
        let candidates = QuizGenerator.extractCandidates(text: text, linkTexts: ["東京都"])
        let linkWords = candidates.filter { $0.type == .link }.map { $0.word }
        XCTAssertTrue(linkWords.contains("東京都"))
    }

    func test_extractCandidates_excludesShortWords() {
        // 2文字未満は除外
        let text = "あアイ"
        let candidates = QuizGenerator.extractCandidates(text: text, linkTexts: [])
        XCTAssertFalse(candidates.contains { $0.word == "ア" })
    }

    func test_extractCandidates_overlappingRangesResolved() {
        // 位置が重複する候補は長い方を優先
        let text = "東京タワー"
        let candidates = QuizGenerator.extractCandidates(text: text, linkTexts: ["タワー", "東京タワー"])
        // 重複があっても最終的に候補は非重複であることを確認
        var lastEnd = -1
        for c in candidates.sorted(by: { $0.startIndex < $1.startIndex }) {
            XCTAssertGreaterThanOrEqual(c.startIndex, lastEnd)
            lastEnd = c.endIndex
        }
    }

    // MARK: - generateQuiz

    func test_generateQuiz_respectsEasyDifficulty() {
        // かんたん: 候補の10%
        let text = String(repeating: "タワー テスト メートル ", count: 20)  // たくさんの候補
        let quiz = QuizGenerator.generate(text: text, linkTexts: [], difficulty: .easy)
        XCTAssertGreaterThan(quiz.blanks.count, 0)
        XCTAssertLessThanOrEqual(quiz.blanks.count, 20)  // 最大20問制限
    }

    func test_generateQuiz_respectsHardDifficulty() {
        let text = String(repeating: "タワー テスト メートル ", count: 20)
        let quizEasy = QuizGenerator.generate(text: text, linkTexts: [], difficulty: .easy)
        let quizHard = QuizGenerator.generate(text: text, linkTexts: [], difficulty: .hard)
        // hard は easy より穴埋め数が多いはず
        XCTAssertGreaterThanOrEqual(quizHard.blanks.count, quizEasy.blanks.count)
    }

    func test_generateQuiz_maxTwentyBlanks() {
        // 100個の候補があっても20問まで
        let text = (1...100).map { _ in "タワー" }.joined(separator: " ")
        let quiz = QuizGenerator.generate(text: text, linkTexts: [], difficulty: .hard)
        XCTAssertLessThanOrEqual(quiz.blanks.count, 20)
    }

    func test_generateQuiz_displayTextContainsBlanks() {
        let text = "東京タワーは高さ333メートルです。"
        let quiz = QuizGenerator.generate(text: text, linkTexts: [], difficulty: .hard)
        XCTAssertTrue(quiz.displayText.contains("[") && quiz.displayText.contains("____"))
    }

    func test_generateQuiz_emptyTextReturnsNoBlanks() {
        let quiz = QuizGenerator.generate(text: "", linkTexts: [], difficulty: .normal)
        XCTAssertEqual(quiz.blanks.count, 0)
    }

    func test_generateQuiz_blanksHaveSequentialNumbers() {
        let text = "東京タワー 電波塔 1958年 333メートル 港区"
        let quiz = QuizGenerator.generate(text: text, linkTexts: [], difficulty: .hard)
        let numbers = quiz.blanks.map { $0.number }
        XCTAssertEqual(numbers, Array(1...quiz.blanks.count))
    }

    // MARK: - checkAnswer

    func test_checkAnswer_exactMatch() {
        let question = QuizQuestion(number: 1, answer: "タワー", type: .katakana)
        XCTAssertTrue(QuizGenerator.checkAnswer(userInput: "タワー", question: question))
    }

    func test_checkAnswer_katakanaToHiragana() {
        let question = QuizQuestion(number: 1, answer: "タワー", type: .katakana)
        XCTAssertTrue(QuizGenerator.checkAnswer(userInput: "たわー", question: question))
    }

    func test_checkAnswer_fullwidthNumberToHalfwidth() {
        let question = QuizQuestion(number: 1, answer: "1958", type: .number)
        XCTAssertTrue(QuizGenerator.checkAnswer(userInput: "１９５８", question: question))
    }

    func test_checkAnswer_trimsWhitespace() {
        let question = QuizQuestion(number: 1, answer: "タワー", type: .katakana)
        XCTAssertTrue(QuizGenerator.checkAnswer(userInput: " タワー ", question: question))
    }

    func test_checkAnswer_incorrect() {
        let question = QuizQuestion(number: 1, answer: "タワー", type: .katakana)
        XCTAssertFalse(QuizGenerator.checkAnswer(userInput: "タイマー", question: question))
    }
}
