import Foundation

/// 穴埋め候補のタイプ
enum BlankType: String, Codable {
    /// カタカナ語（2文字以上）
    case katakana
    /// 数字（3桁以上）
    case number
    /// Wikipedia 記事内リンクテキスト
    case link
    /// 括弧内テキスト（Phase 2 では未使用だが将来のため定義）
    case paren
}

/// 穴埋め 1 問分のデータ
struct QuizQuestion: Identifiable, Equatable {
    let id: UUID
    /// 出題番号（1始まり）
    let number: Int
    /// 正解文字列（原文そのまま）
    let answer: String
    /// 候補のタイプ
    let type: BlankType

    init(id: UUID = UUID(), number: Int, answer: String, type: BlankType) {
        self.id = id
        self.number = number
        self.answer = answer
        self.type = type
    }
}

/// クイズ難易度
///
/// 難易度に応じて抽出候補のうち何割を穴埋めにするかが決まる。
/// スコア計算時は `scoreMultiplier` を使用する。
enum QuizDifficulty: String, Codable, CaseIterable {
    /// かんたん: 候補の 10%
    case easy
    /// ふつう: 候補の 25%
    case normal
    /// むずかしい: 候補の 50%
    case hard

    /// 候補のうち穴埋めにする割合（0.0〜1.0）
    var rate: Double {
        switch self {
        case .easy: return 0.10
        case .normal: return 0.25
        case .hard: return 0.50
        }
    }

    /// UI 表示用の名称
    var displayName: String {
        switch self {
        case .easy: return "かんたん"
        case .normal: return "ふつう"
        case .hard: return "むずかしい"
        }
    }

    /// スコア計算時の倍率（難易度ボーナス）
    var scoreMultiplier: Int {
        switch self {
        case .easy: return 1
        case .normal: return 2
        case .hard: return 3
        }
    }
}

/// 生成されたクイズ全体
struct Quiz {
    /// `[1:____]` 等のプレースホルダを含む表示用テキスト
    let displayText: String
    /// 問題一覧（番号順）
    let blanks: [QuizQuestion]
    /// 難易度
    let difficulty: QuizDifficulty
}
