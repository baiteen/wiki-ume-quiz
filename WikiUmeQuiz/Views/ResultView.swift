import SwiftUI
import SwiftData

/// クイズ終了後のリザルト画面
///
/// 正解数・正解率・タイム・ヒント使用回数・スコアの統計表示と
/// 解答一覧、「もう一回」「別の記事」ボタンを提供する。
/// スコア計算は `ScoreCalculator` に委譲し、このビューは表示責務のみを持つ。
///
/// Phase 6: 画面表示時に `PlayHistoryRepository` 経由で
/// プレイ履歴を SwiftData に自動保存する。再表示時の二重保存を避けるため
/// `@State saved` フラグでガードする。
struct ResultView: View {

    // MARK: - Layout constants

    /// セクション間の縦方向スペース
    private static let sectionSpacing: CGFloat = 24
    /// StatItem 行内の水平スペース
    private static let statRowSpacing: CGFloat = 32
    /// ボタン間の縦方向スペース
    private static let buttonSpacing: CGFloat = 12
    /// カード等の角丸半径
    private static let cornerRadius: CGFloat = 12
    /// ボタンの角丸半径
    private static let buttonCornerRadius: CGFloat = 10
    /// スコア表示のフォントサイズ
    private static let scoreFontSize: CGFloat = 48

    /// Wikipedia カラーを模したテーマ色（Phase 全体で揃えたい場合は将来共通化）
    private static let wikipediaBlue = Color(red: 0.2, green: 0.4, blue: 0.8)

    // MARK: - Inputs

    let articleTitle: String
    let difficulty: QuizDifficulty
    let correctCount: Int
    let totalCount: Int
    let timeSeconds: Int
    let hintsUsed: Int
    let results: [QuizAnswerResult]

    /// 「もう一回」ボタン押下時のコールバック
    var onRetry: () -> Void = {}
    /// 「別の記事」ボタン押下時のコールバック（ホームへ戻す想定）
    var onBackHome: () -> Void = {}

    // MARK: - SwiftData

    /// プレイ履歴保存用の SwiftData コンテキスト
    @Environment(\.modelContext) private var modelContext

    /// 二重保存防止フラグ（再描画・再表示時の多重 insert を避ける）
    @State private var hasSavedHistory: Bool = false

    // MARK: - Derived values

    /// 計算済みスコア（`ScoreCalculator` に委譲）
    private var score: Int {
        ScoreCalculator.calculate(
            correctCount: correctCount,
            difficulty: difficulty,
            timeSeconds: timeSeconds
        )
    }

    /// 正解率（%）
    private var accuracy: Int {
        ScoreCalculator.accuracyPercentage(correct: correctCount, total: totalCount)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: Self.sectionSpacing) {
                header
                statsSection
                resultsDetailSection
                buttonsSection
            }
            .padding()
        }
        .navigationTitle("リザルト")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            savePlayHistoryIfNeeded()
        }
    }

    // MARK: - Persistence

    /// 画面表示時に 1 度だけプレイ履歴を保存する
    ///
    /// 同じ `ResultView` が複数回 `onAppear` を受け取っても
    /// `hasSavedHistory` フラグにより多重保存されないようにしている。
    /// 同一記事の再プレイは別インスタンスで表示されるため、別レコードとして保存される（仕様）。
    private func savePlayHistoryIfNeeded() {
        guard !hasSavedHistory else { return }
        hasSavedHistory = true

        let repository = PlayHistoryRepository(context: modelContext)
        repository.save(
            articleTitle: articleTitle,
            difficulty: difficulty,
            score: score,
            correctCount: correctCount,
            totalCount: totalCount,
            timeSeconds: timeSeconds,
            hintsUsed: hintsUsed
        )
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 8) {
            Text(articleTitle)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("難易度: \(difficulty.displayName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: Self.statRowSpacing) {
                StatItem(title: "正解", value: "\(correctCount)/\(totalCount)")
                StatItem(title: "正解率", value: "\(accuracy)%")
            }
            HStack(spacing: Self.statRowSpacing) {
                StatItem(
                    title: "タイム",
                    value: ScoreCalculator.formatTime(seconds: timeSeconds)
                )
                StatItem(title: "ヒント", value: "\(hintsUsed)回")
            }
            scoreCard
        }
    }

    private var scoreCard: some View {
        VStack(spacing: 4) {
            Text("スコア")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(score)")
                .font(.system(size: Self.scoreFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(Self.wikipediaBlue)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(Self.cornerRadius)
    }

    private var resultsDetailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("解答一覧")
                .font(.headline)
            ForEach(results) { result in
                AnswerRow(result: result)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var buttonsSection: some View {
        VStack(spacing: Self.buttonSpacing) {
            Button(action: onRetry) {
                Text("もう一回")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Self.wikipediaBlue)
                    .foregroundColor(.white)
                    .cornerRadius(Self.buttonCornerRadius)
            }
            Button(action: onBackHome) {
                Text("別の記事")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(Self.buttonCornerRadius)
            }
        }
    }
}

// MARK: - Subcomponents

/// 統計 1 項目を表示する汎用ビュー（再利用のため切り出し）
private struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity)
    }
}

/// 解答一覧 1 行
///
/// 正答/誤答に応じてアイコン色を切り替え、誤答時はユーザー解答を表示する。
private struct AnswerRow: View {
    let result: QuizAnswerResult

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.isCorrect ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text("問\(result.questionNumber): \(result.correctAnswer)")
                    .font(.subheadline)
                if !result.isCorrect {
                    let display = result.userAnswer.isEmpty ? "(未回答)" : result.userAnswer
                    Text("あなたの解答: \(display)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ResultView(
            articleTitle: "東京タワー",
            difficulty: .normal,
            correctCount: 8,
            totalCount: 10,
            timeSeconds: 125,
            hintsUsed: 2,
            results: [
                QuizAnswerResult(
                    questionNumber: 1,
                    correctAnswer: "タワー",
                    userAnswer: "タワー",
                    isCorrect: true
                ),
                QuizAnswerResult(
                    questionNumber: 2,
                    correctAnswer: "1958",
                    userAnswer: "1958",
                    isCorrect: true
                ),
                QuizAnswerResult(
                    questionNumber: 3,
                    correctAnswer: "333",
                    userAnswer: "200",
                    isCorrect: false
                ),
                QuizAnswerResult(
                    questionNumber: 4,
                    correctAnswer: "東京都",
                    userAnswer: "",
                    isCorrect: false
                ),
            ]
        )
    }
    .modelContainer(for: PlayHistory.self, inMemory: true)
}
