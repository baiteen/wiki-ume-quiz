import Foundation

/// 現問題を中心とした周辺文脈
///
/// B 案「1 問 1 画面集中型」UI で使用する。
/// `Quiz.displayText` から現問題を含む「文」を特定し、その前後 N 文を
/// 切り出した結果を保持する。
///
/// - `beforeText` / `afterText` は単なる表示テキストとして扱う
/// - `currentSentence` には `[N:____]` プレースホルダが原文のまま残っており、
///   `QuizView` 側で AttributedString に装飾してから描画する
///
/// 文の区切りは句点「。」とする。末尾に句点のない断片も 1 文として扱う。
struct QuizContext: Equatable {
    /// 現問題を含む文より前にある文（連結済み）。
    ///
    /// 現問題が先頭の文に含まれている場合は空文字になる。
    let beforeText: String

    /// 現問題を含む文。
    ///
    /// `[N:____]` プレースホルダを含んだ原文のまま保持する。
    let currentSentence: String

    /// 現問題を含む文より後にある文（連結済み）。
    ///
    /// 現問題が末尾の文に含まれている場合は空文字になる。
    let afterText: String
}
