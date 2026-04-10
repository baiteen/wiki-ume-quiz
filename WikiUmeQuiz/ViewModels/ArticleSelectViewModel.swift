import Foundation
import Observation

/// 記事選択画面の ViewModel
///
/// 責務:
/// - 指定タイトルの Wikipedia 記事を取得し、本文・リンクを保持する
/// - 冒頭数行のプレビューテキストを生成する
/// - 難易度を受け取ってクイズを生成する（`QuizGenerator.generate` へ委譲）
///
/// 画面遷移（`navigationDestination`）は View 側の責務なので、
/// ここではクイズオブジェクトを返すだけに留める。
@MainActor
@Observable
final class ArticleSelectViewModel {

    // MARK: - Constants

    /// プレビューとして表示する最大行数
    private static let previewLineCount = 3
    /// プレビュー文字数の上限。超えた場合は末尾を省略する
    private static let previewCharacterLimit = 200

    // MARK: - Input

    /// 対象の記事タイトル
    let articleTitle: String

    // MARK: - Dependencies

    private let wikipediaService: WikipediaServiceProtocol

    // MARK: - State

    /// 記事取得中フラグ
    private(set) var isLoading: Bool = false

    /// 冒頭 3 行程度のプレビューテキスト
    private(set) var previewText: String = ""

    /// 取得した記事本文（クイズ生成に使用）
    private(set) var fullText: String = ""

    /// 取得した記事内リンクテキスト一覧
    private(set) var linkTexts: [String] = []

    /// エラーメッセージ（nil のとき UI に表示しない）
    private(set) var errorMessage: String?

    // MARK: - Init

    init(articleTitle: String, wikipediaService: WikipediaServiceProtocol) {
        self.articleTitle = articleTitle
        self.wikipediaService = wikipediaService
    }

    // MARK: - Actions

    /// 指定タイトルの記事を取得してプレビューを生成する
    ///
    /// 成功時は `fullText` / `linkTexts` / `previewText` を更新。
    /// 失敗時は `errorMessage` をセットする。
    func loadArticle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await wikipediaService.fetchArticle(title: articleTitle)
            self.fullText = result.text
            self.linkTexts = result.links
            self.previewText = Self.makePreview(from: result.text)
        } catch let error as WikipediaServiceError {
            self.errorMessage = error.errorDescription ?? "記事の取得に失敗しました"
        } catch {
            self.errorMessage = "記事の取得に失敗しました"
        }
    }

    /// 取得済みの記事から指定難易度のクイズを生成する
    ///
    /// - Parameter difficulty: 難易度
    /// - Returns: 生成されたクイズ。まだ記事を取得していない場合は `nil`。
    func startQuiz(difficulty: QuizDifficulty) -> Quiz? {
        guard !fullText.isEmpty else { return nil }
        return QuizGenerator.generate(
            text: fullText,
            linkTexts: linkTexts,
            difficulty: difficulty
        )
    }

    // MARK: - Preview

    /// 冒頭 3 行（最大 200 文字）のプレビューを生成する
    ///
    /// 200 文字を超える場合は末尾に `...` を付与する。
    private static func makePreview(from text: String) -> String {
        let lines = text.components(separatedBy: "\n").prefix(previewLineCount)
        let combined = lines.joined(separator: "\n")
        if combined.count > previewCharacterLimit {
            return String(combined.prefix(previewCharacterLimit)) + "..."
        }
        return combined
    }
}
