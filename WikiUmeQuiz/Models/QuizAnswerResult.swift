import Foundation

/// 1 問分の回答結果
///
/// `QuizViewModel` が各問題の解答送信・ギブアップ時に生成し、
/// 結果画面（Phase 4）で一覧表示する際にも利用する。
/// `Hashable` は `NavigationPath` で `ResultRoute` などに含めて遷移するために必要。
struct QuizAnswerResult: Identifiable, Equatable, Hashable {
    /// SwiftUI 一覧描画用の ID
    let id: UUID
    /// 出題番号（`QuizQuestion.number` と対応）
    let questionNumber: Int
    /// 正解文字列（原文そのまま）
    let correctAnswer: String
    /// ユーザーが入力した文字列（ギブアップ時は空文字）
    let userAnswer: String
    /// 正誤フラグ
    let isCorrect: Bool

    init(
        id: UUID = UUID(),
        questionNumber: Int,
        correctAnswer: String,
        userAnswer: String,
        isCorrect: Bool
    ) {
        self.id = id
        self.questionNumber = questionNumber
        self.correctAnswer = correctAnswer
        self.userAnswer = userAnswer
        self.isCorrect = isCorrect
    }
}
