import Foundation

/// 表記ゆれを吸収するための文字列正規化ユーティリティ
///
/// 正規化ルール:
/// 1. NFKC 正規化（全角英数→半角、半角カナ→全角など互換分解後の再結合）
/// 2. 小文字化（ASCII 英字のみ影響）
/// 3. カタカナ→ひらがな変換
/// 4. 前後空白除去
///
/// これらを組み合わせることで、ユーザー入力と正解の細かな表記差を許容する。
enum StringNormalizer {

    // MARK: - Constants

    /// カタカナブロックの先頭コードポイント（ァ）
    private static let katakanaStart: UInt32 = 0x30A1
    /// カタカナブロックの末尾コードポイント（ヶ）
    private static let katakanaEnd: UInt32 = 0x30F6
    /// カタカナ→ひらがなへのコードポイント差分
    private static let katakanaToHiraganaOffset: UInt32 = 0x60

    // MARK: - Public API

    /// 正規化: NFKC正規化 + 小文字化 + カタカナ→ひらがな + 前後空白除去
    static func normalize(_ text: String) -> String {
        // NFKC正規化（全角英数→半角、半角カナ→全角）
        let nfkc = text.precomposedStringWithCompatibilityMapping
        // 小文字化
        let lowered = nfkc.lowercased()
        // カタカナ→ひらがな
        let hiragana = convertKatakanaToHiragana(lowered)
        // 前後空白除去
        return hiragana.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 表記ゆれを無視した比較
    /// - Parameters:
    ///   - lhs: 比較対象 1
    ///   - rhs: 比較対象 2
    /// - Returns: 正規化後に一致する場合 true
    static func isEqualIgnoringVariations(_ lhs: String, _ rhs: String) -> Bool {
        return normalize(lhs) == normalize(rhs)
    }

    // MARK: - Private Helpers

    /// カタカナ（ァ-ヶ）をひらがなに変換する
    ///
    /// Unicode 上ではカタカナとひらがなのブロックが 0x60 離れているため、
    /// コードポイント単位で単純にオフセットを引くことで変換できる。
    /// - Parameter text: 変換対象のテキスト
    /// - Returns: カタカナ部分をひらがなに置換した文字列
    private static func convertKatakanaToHiragana(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)

        for scalar in text.unicodeScalars {
            let value = scalar.value
            if (katakanaStart...katakanaEnd).contains(value),
               let converted = Unicode.Scalar(value - katakanaToHiraganaOffset) {
                result.unicodeScalars.append(converted)
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }
}
