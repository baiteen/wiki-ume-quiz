import Foundation

/// NavigationStack の値型ルート定義
///
/// Phase 7 での全体結合で導入した `NavigationPath` 駆動の画面遷移用。
/// `HomeView` で `NavigationStack(path:)` を管理し、各画面は
/// `navigationDestination(for:)` に対応する型が append されたら遷移する。
///
/// ルート間でやり取りするデータ（`Quiz`, 解答結果）は Value 型なので
/// `Hashable` を要求する `NavigationPath` にそのまま積める。
///
/// 画面 ↔ ルート対応:
/// - `String`（記事タイトル） → `ArticleSelectView`
/// - `QuizRoute` → `QuizView`
/// - `ResultRoute` → `ResultView`

/// クイズ画面への遷移ルート
///
/// 記事選択画面で難易度を選んで「スタート」を押した時点で
/// 生成済みの `Quiz` とタイトルを運ぶ。
struct QuizRoute: Hashable {
    /// 出題されるクイズ本体（`QuizGenerator.generate` の結果）
    let quiz: Quiz
    /// 出典記事タイトル（ナビゲーションタイトル・リザルト表示に使用）
    let articleTitle: String
}

/// リザルト画面への遷移ルート
///
/// `QuizView` でクイズ完了を検知したときに、`QuizViewModel` の状態から
/// 必要最小限の値をコピーして積む。`QuizViewModel` は `@Observable` の
/// クラスで `Hashable` にできないため、プリミティブにばらして渡す。
struct ResultRoute: Hashable {
    let articleTitle: String
    let difficulty: QuizDifficulty
    let correctCount: Int
    let totalCount: Int
    let timeSeconds: Int
    let hintsUsed: Int
    let results: [QuizAnswerResult]
}
