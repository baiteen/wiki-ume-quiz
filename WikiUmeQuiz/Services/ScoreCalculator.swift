import Foundation

/// スコア計算・表示整形を担う純粋関数のコレクション
///
/// すべて static な純粋関数で構成し、状態は持たない。
/// ロジックを画面から分離することで、TDD によるユニットテストを容易にする。
enum ScoreCalculator {

    // MARK: - Constants

    /// 時間ボーナスの上限秒数（この時間未満ならボーナスを加算）
    static let timeBonusThresholdSeconds: Int = 300

    /// ボーナスが効いている状態での最小倍率
    private static let minimumBonusMultiplier: Double = 1.0

    /// 1 分の秒数（mm:ss 整形用）
    private static let secondsPerMinute: Int = 60

    /// 正解率の最大値（%）
    private static let maxAccuracyPercent: Double = 100.0

    // MARK: - Score

    /// スコアを計算する
    ///
    /// 計算式:
    /// ```
    /// score = correctCount × difficulty.scoreMultiplier × max(1, timeBonus)
    /// timeBonus = seconds < 300 ? (300 - seconds)/300 + 1 : 1.0
    /// ```
    /// 最終結果は `Int` 変換（切り捨て）で返す。
    ///
    /// - Parameters:
    ///   - correctCount: 正解数（0 以上）
    ///   - difficulty: 難易度（倍率に使用）
    ///   - timeSeconds: クリアタイム（秒、0 以上）
    /// - Returns: 切り捨てされた整数スコア
    static func calculate(
        correctCount: Int,
        difficulty: QuizDifficulty,
        timeSeconds: Int
    ) -> Int {
        let multiplier = Double(difficulty.scoreMultiplier)
        let timeBonus = computeTimeBonus(timeSeconds: timeSeconds)
        let effectiveBonus = max(minimumBonusMultiplier, timeBonus)
        let rawScore = Double(correctCount) * multiplier * effectiveBonus
        // 仕様: 最終スコアは切り捨て (Int 変換)
        return Int(rawScore)
    }

    /// 時間ボーナス倍率を計算する
    ///
    /// 300 秒未満なら `(300 - seconds)/300 + 1`、以降は 1.0。
    /// 関数を分離することで `calculate` 本体の可読性を高める（DRY/SRP）。
    private static func computeTimeBonus(timeSeconds: Int) -> Double {
        guard timeSeconds < timeBonusThresholdSeconds else {
            return minimumBonusMultiplier
        }
        let remaining = Double(timeBonusThresholdSeconds - timeSeconds)
        return remaining / Double(timeBonusThresholdSeconds) + 1.0
    }

    // MARK: - Accuracy

    /// 正解率（%）を整数で返す
    ///
    /// `total` が 0 のときはゼロ除算を避けて 0 を返す。
    /// 小数部は `Int` 変換で切り捨てる。
    static func accuracyPercentage(correct: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        let ratio = Double(correct) / Double(total) * maxAccuracyPercent
        return Int(ratio)
    }

    // MARK: - Time formatting

    /// 秒を `mm:ss` 形式の文字列に整形する
    ///
    /// 60 分以上の場合は分が 2 桁を超えて表示される（例: `61:01`）。
    static func formatTime(seconds: Int) -> String {
        let minutes = seconds / secondsPerMinute
        let remainingSeconds = seconds % secondsPerMinute
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
