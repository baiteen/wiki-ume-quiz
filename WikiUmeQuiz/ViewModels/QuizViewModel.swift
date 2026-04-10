import Foundation
import Observation

/// クイズ画面の ViewModel
///
/// `@Observable` を採用し SwiftUI から状態変更を購読する。
/// 責務:
/// - 現在の問題・進捗・解答結果の保持
/// - 解答送信時の正誤判定（`QuizGenerator.checkAnswer` へ委譲）
/// - ヒント使用回数のカウント
/// - ギブアップ処理
/// - 経過時間タイマー
///
/// UI 上の副作用（フォーカス制御やフィードバック表示）は View 側の責務とする。
@MainActor
@Observable
final class QuizViewModel {

    // MARK: - Constants

    /// タイマー更新間隔（ミリ秒）。UI 更新コストを抑えるため 500ms とする
    private static let timerTickMilliseconds = 500

    /// 周辺文脈抽出時の既定前後文数（B案 1問1画面集中型 UI 用）
    ///
    /// 現問題を含む文の前後、それぞれ何文を併せて表示するかのデフォルト値。
    /// View 側から必要に応じて任意の値を渡せる。
    static let defaultSurroundingLines: Int = 1

    /// 文の区切り文字（日本語句点）
    ///
    /// `splitIntoSentences` で使用する。Wikipedia 本文は句点「。」で文が区切られる前提。
    private static let sentenceTerminator: Character = "。"

    // MARK: - Input

    /// 出題対象のクイズ
    let quiz: Quiz
    /// 出典記事タイトル（結果画面・ナビゲーションタイトル用）
    let articleTitle: String

    // MARK: - State

    /// 現在の問題インデックス（0 始まり）
    private(set) var currentIndex: Int = 0
    /// これまでの解答結果（順序は `quiz.blanks` と同じ）
    private(set) var results: [QuizAnswerResult] = []
    /// ヒント使用回数（問題をまたいで累積）
    private(set) var hintsUsed: Int = 0
    /// 経過秒数（整数秒で UI 更新）
    private(set) var elapsedSeconds: Int = 0
    /// クイズ完了フラグ
    private(set) var isCompleted: Bool = false

    // MARK: - Derived

    /// 全問題数
    var totalCount: Int { quiz.blanks.count }

    /// 正解数
    var correctCount: Int { results.filter { $0.isCorrect }.count }

    /// 現在の問題（完了済みの場合は nil）
    var currentQuestion: QuizQuestion? {
        guard currentIndex < quiz.blanks.count else { return nil }
        return quiz.blanks[currentIndex]
    }

    /// 進捗テキスト（例: "3/20"）
    ///
    /// 完了後は `totalCount/totalCount` にクランプする。
    var progressText: String {
        let current = min(currentIndex + 1, totalCount)
        return "\(current)/\(totalCount)"
    }

    /// 経過時間テキスト（mm:ss）
    var elapsedTimeText: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Timer state

    /// バックグラウンドで回るタイマータスク
    private var timerTask: Task<Void, Never>?
    /// 開始時刻。`stopTimer` 時に経過秒数を計算する際に使用
    private var timerStart: Date?

    // MARK: - Init

    init(quiz: Quiz, articleTitle: String) {
        self.quiz = quiz
        self.articleTitle = articleTitle
    }

    // MARK: - Timer Actions

    /// タイマーを開始する
    ///
    /// 既に開始済みの場合は no-op。`View.onAppear` から呼び出すことを想定。
    ///
    /// Task は `@MainActor` 文脈で生成し、内部の `tick()` 呼び出しがそのまま
    /// MainActor 上で実行されるようにする（Swift 6 の actor 分離に準拠）。
    func startTimer() {
        guard timerTask == nil else { return }
        let start = Date()
        timerStart = start
        elapsedSeconds = 0
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(QuizViewModel.timerTickMilliseconds))
                self?.tick()
            }
        }
    }

    /// タイマーを停止する
    ///
    /// 完了直前に呼び出すことで、最後の `tick` を待たずに正確な秒数を反映する。
    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        if let start = timerStart {
            elapsedSeconds = Int(Date().timeIntervalSince(start))
        }
    }

    /// 周期的に経過秒数を更新する
    private func tick() {
        guard let start = timerStart else { return }
        elapsedSeconds = Int(Date().timeIntervalSince(start))
    }

    // MARK: - Quiz Actions

    /// 現在の問題に解答を送信する
    ///
    /// - Parameter userInput: ユーザー入力文字列
    ///
    /// 完了後・問題が無い場合は何もしない。
    /// 正誤判定は `QuizGenerator.checkAnswer` に委譲する。
    func submitAnswer(_ userInput: String) {
        guard !isCompleted else { return }
        guard let question = currentQuestion else { return }

        let isCorrect = QuizGenerator.checkAnswer(userInput: userInput, question: question)
        let result = QuizAnswerResult(
            questionNumber: question.number,
            correctAnswer: question.answer,
            userAnswer: userInput,
            isCorrect: isCorrect
        )
        results.append(result)
        currentIndex += 1

        if currentIndex >= quiz.blanks.count {
            complete()
        }
    }

    /// 現在の問題のヒント（正解の 1 文字目）を取得する
    ///
    /// - Returns: 1 文字目の文字列。完了済み・問題なしの場合は空文字。
    ///
    /// 呼び出しごとに `hintsUsed` がインクリメントされる（スコア計算用）。
    @discardableResult
    func useHint() -> String {
        guard !isCompleted, let question = currentQuestion else { return "" }
        hintsUsed += 1
        return String(question.answer.prefix(1))
    }

    /// 残りの問題を全て不正解扱いで埋めて完了状態へ遷移する
    ///
    /// 既解答分は保持し、未解答分のみ空文字・不正解として記録する。
    func giveUp() {
        guard !isCompleted else { return }
        while currentIndex < quiz.blanks.count {
            let question = quiz.blanks[currentIndex]
            results.append(QuizAnswerResult(
                questionNumber: question.number,
                correctAnswer: question.answer,
                userAnswer: "",
                isCorrect: false
            ))
            currentIndex += 1
        }
        complete()
    }

    // MARK: - Context Extraction (B案 1問1画面集中型)

    /// 現問題を中心とした周辺文脈を返す
    ///
    /// `quiz.displayText` を句点「。」で文に分割し、現問題の
    /// `[N:____]` プレースホルダを含む文と、その前後 `surroundingLines` 文を
    /// 切り出して `QuizContext` として返す。
    ///
    /// - Parameter surroundingLines: 前後それぞれに含める文の数（既定: 1）
    /// - Returns: 現問題が存在しない（完了済み or 問題なし）場合は `nil`
    ///
    /// View 側では `currentSentence` 中の `[N:____]` を装飾して描画する。
    func contextForCurrentQuestion(
        surroundingLines: Int = QuizViewModel.defaultSurroundingLines
    ) -> QuizContext? {
        guard let current = currentQuestion else { return nil }

        let marker = "[\(current.number):____]"
        let sentences = Self.splitIntoSentences(quiz.displayText)

        guard let currentIdx = sentences.firstIndex(where: { $0.contains(marker) }) else {
            return nil
        }

        let beforeStart = max(0, currentIdx - surroundingLines)
        let afterEnd = min(sentences.count - 1, currentIdx + surroundingLines)

        let beforeText = sentences[beforeStart..<currentIdx].joined()
        let currentSentence = sentences[currentIdx]
        let afterText: String
        if currentIdx + 1 <= afterEnd {
            afterText = sentences[(currentIdx + 1)...afterEnd].joined()
        } else {
            afterText = ""
        }

        return QuizContext(
            beforeText: beforeText,
            currentSentence: currentSentence,
            afterText: afterText
        )
    }

    /// テキストを句点で文に分割する
    ///
    /// 句点は各文の末尾に保持される（"AAA。BBB。" → ["AAA。", "BBB。"]）。
    /// 末尾に句点のない断片も 1 文として返す（"AAA" → ["AAA"]）。
    ///
    /// DRY の観点から static 関数として切り出し、将来 StringNormalizer 等から
    /// 再利用できる形にしておく。
    private static func splitIntoSentences(_ text: String) -> [String] {
        var result: [String] = []
        var buffer = ""
        for char in text {
            buffer.append(char)
            if char == sentenceTerminator {
                result.append(buffer)
                buffer = ""
            }
        }
        if !buffer.isEmpty {
            result.append(buffer)
        }
        return result
    }

    // MARK: - Private

    /// クイズを完了状態にしてタイマーを停止する
    private func complete() {
        isCompleted = true
        stopTimer()
    }
}
