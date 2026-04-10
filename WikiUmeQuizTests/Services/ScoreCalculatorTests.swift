import XCTest
@testable import WikiUmeQuiz

/// `ScoreCalculator` のテスト
///
/// スコア計算・正解率・時間フォーマットの境界値を含む網羅的な
/// テストを実装する。計算式は PL 指示書の仕様に従う。
///
/// - スコア = 正解数 × 難易度倍率 × max(1, 時間ボーナス)
/// - 時間ボーナス = 300 秒未満なら (300 - 経過秒数) / 300 + 1、以降は 1.0
/// - 最終スコアは Int 変換（切り捨て）
final class ScoreCalculatorTests: XCTestCase {

    // MARK: - calculate(correctCount:difficulty:timeSeconds:)

    func test_score_easy_allCorrect_fastTime() {
        // かんたん(1) × 10 正解 × (300-60)/300+1 = 1.8 → 18
        let score = ScoreCalculator.calculate(
            correctCount: 10,
            difficulty: .easy,
            timeSeconds: 60
        )
        XCTAssertEqual(score, 18)
    }

    func test_score_normal_mostCorrect_midTime() {
        // ふつう(2) × 8 正解 × (300-60)/300+1 = 1.8 → 28.8 → 28
        let score = ScoreCalculator.calculate(
            correctCount: 8,
            difficulty: .normal,
            timeSeconds: 60
        )
        XCTAssertEqual(score, 28)
    }

    func test_score_hard_fastTime() {
        // むずかしい(3) × 5 正解 × (300-30)/300+1 = 1.9 → 28.5 → 28
        let score = ScoreCalculator.calculate(
            correctCount: 5,
            difficulty: .hard,
            timeSeconds: 30
        )
        XCTAssertEqual(score, 28)
    }

    func test_score_overTimeLimit_noBonus() {
        // 300 秒超過 → ボーナス 1.0
        // ふつう(2) × 3 正解 × 1.0 = 6
        let score = ScoreCalculator.calculate(
            correctCount: 3,
            difficulty: .normal,
            timeSeconds: 400
        )
        XCTAssertEqual(score, 6)
    }

    func test_score_exactTimeLimit_bonusOne() {
        // 300 秒ちょうど → ボーナス 1.0
        // ふつう(2) × 5 正解 × 1.0 = 10
        let score = ScoreCalculator.calculate(
            correctCount: 5,
            difficulty: .normal,
            timeSeconds: 300
        )
        XCTAssertEqual(score, 10)
    }

    func test_score_zeroCorrect_isZero() {
        let score = ScoreCalculator.calculate(
            correctCount: 0,
            difficulty: .hard,
            timeSeconds: 60
        )
        XCTAssertEqual(score, 0)
    }

    func test_score_zeroTime_maxBonus() {
        // 0 秒 → (300-0)/300+1 = 2.0
        // かんたん(1) × 5 正解 × 2.0 = 10
        let score = ScoreCalculator.calculate(
            correctCount: 5,
            difficulty: .easy,
            timeSeconds: 0
        )
        XCTAssertEqual(score, 10)
    }

    // MARK: - accuracyPercentage(correct:total:)

    func test_accuracyPercentage_exact() {
        XCTAssertEqual(ScoreCalculator.accuracyPercentage(correct: 8, total: 10), 80)
        XCTAssertEqual(ScoreCalculator.accuracyPercentage(correct: 1, total: 3), 33)
        XCTAssertEqual(ScoreCalculator.accuracyPercentage(correct: 0, total: 10), 0)
        XCTAssertEqual(ScoreCalculator.accuracyPercentage(correct: 10, total: 10), 100)
        // ゼロ除算ガード
        XCTAssertEqual(ScoreCalculator.accuracyPercentage(correct: 5, total: 0), 0)
    }

    // MARK: - formatTime(seconds:)

    func test_timeText_formatsMMSS() {
        XCTAssertEqual(ScoreCalculator.formatTime(seconds: 0), "00:00")
        XCTAssertEqual(ScoreCalculator.formatTime(seconds: 65), "01:05")
        XCTAssertEqual(ScoreCalculator.formatTime(seconds: 3661), "61:01")
    }
}
