import Foundation

/// Wikipedia プレーンテキストから穴埋めクイズを生成するサービス
///
/// 以下の 3 種類を候補として抽出し、難易度に応じた割合でランダムに選択する:
/// - カタカナ語（2 文字以上）
/// - 数字（3 桁以上。年号・統計値を狙う）
/// - Wikipedia 記事内リンクテキスト
///
/// 重複範囲（例: "東京タワー" と "タワー"）が発生した場合は
/// より長い候補を優先することで、意味のある単位で穴埋めする。
enum QuizGenerator {

    // MARK: - Constants

    /// 1 回のクイズで生成する穴埋め数の上限
    static let maxBlanks = 20
    /// 候補とみなす最小文字数（カタカナ・リンク共通）
    static let minWordLength = 2
    /// 数字候補とみなす最小桁数（年号・統計値を狙うため）
    static let minNumberLength = 3
    /// 表示テキスト長の上限。長すぎる場合は最後の空所周辺でトリムする
    static let maxDisplayTextLength = 2000
    /// 表示テキストをトリムする際、最後の空所から後ろに残す文字数
    private static let trailingTextAfterLastBlank = 200

    // MARK: - Candidate

    /// 穴埋め候補の中間表現
    ///
    /// `startIndex`/`endIndex` は Swift の `Character` 単位の
    /// 半開区間 `[start, end)` を表す（NSString の UTF-16 単位ではない）。
    struct Candidate: Equatable {
        let word: String
        let type: BlankType
        let startIndex: Int
        let endIndex: Int
    }

    // MARK: - Public API

    /// 穴埋めクイズを生成する
    /// - Parameters:
    ///   - text: Wikipedia 記事のプレーンテキスト
    ///   - linkTexts: 記事内のリンクテキスト一覧
    ///   - difficulty: 難易度
    /// - Returns: 生成されたクイズ
    static func generate(text: String, linkTexts: [String], difficulty: QuizDifficulty) -> Quiz {
        guard !text.isEmpty else {
            return Quiz(displayText: text, blanks: [], difficulty: difficulty)
        }

        let candidates = extractCandidates(text: text, linkTexts: linkTexts)
        guard !candidates.isEmpty else {
            return Quiz(displayText: text, blanks: [], difficulty: difficulty)
        }

        // 難易度に応じて穴埋め数を決定（最低 1 問、上限 maxBlanks）
        let targetCount = max(1, Int(Double(candidates.count) * difficulty.rate))
        let numBlanks = min(targetCount, maxBlanks)

        // ランダムに選択し、原文の出現順にソートして番号を振る
        let selected = candidates
            .shuffled()
            .prefix(numBlanks)
            .sorted { $0.startIndex < $1.startIndex }

        // displayText を組み立てる
        let textArray = Array(text)
        var displayParts: [String] = []
        var blanks: [QuizQuestion] = []
        var prevEnd = 0

        for (index, candidate) in selected.enumerated() {
            let number = index + 1
            let prefix = String(textArray[prevEnd..<candidate.startIndex])
            displayParts.append(prefix)
            displayParts.append("[\(number):____]")
            blanks.append(QuizQuestion(
                number: number,
                answer: candidate.word,
                type: candidate.type
            ))
            prevEnd = candidate.endIndex
        }
        displayParts.append(String(textArray[prevEnd..<textArray.count]))

        let displayText = trimIfTooLong(displayParts.joined(), blankCount: blanks.count)

        return Quiz(displayText: displayText, blanks: blanks, difficulty: difficulty)
    }

    /// 正解判定（表記ゆれ対応）
    ///
    /// `StringNormalizer.isEqualIgnoringVariations` により
    /// 全角/半角、カタカナ/ひらがな、前後空白、英字の大文字/小文字を吸収する。
    static func checkAnswer(userInput: String, question: QuizQuestion) -> Bool {
        return StringNormalizer.isEqualIgnoringVariations(userInput, question.answer)
    }

    // MARK: - Candidate extraction

    /// テキストから穴埋め候補を抽出する
    ///
    /// 以下の順で候補を集めた後、重複範囲を長い方優先で解決する:
    /// 1. カタカナ語（2 文字以上）
    /// 2. 数字（3 桁以上）
    /// 3. リンクテキスト（テキスト内の最初の出現位置）
    ///
    /// - Parameters:
    ///   - text: 対象テキスト
    ///   - linkTexts: リンクテキスト一覧
    /// - Returns: 非重複の候補一覧（出現順）
    static func extractCandidates(text: String, linkTexts: [String]) -> [Candidate] {
        var candidates: [Candidate] = []
        // 完全一致する範囲の重複登録を避けるためのキャッシュ
        var seenRanges = Set<Range>()

        // 1. カタカナ語（2 文字以上）
        for match in findMatches(pattern: "[ァ-ヶー]{2,}", in: text) {
            addCandidate(
                word: match.word,
                type: .katakana,
                start: match.start,
                end: match.end,
                into: &candidates,
                seen: &seenRanges
            )
        }

        // 2. 数字（3 桁以上。全角半角どちらも拾う）
        for match in findMatches(pattern: "[0-9０-９]+", in: text) {
            guard match.word.count >= minNumberLength else { continue }
            addCandidate(
                word: match.word,
                type: .number,
                start: match.start,
                end: match.end,
                into: &candidates,
                seen: &seenRanges
            )
        }

        // 3. リンクテキスト（単純な文字列検索で最初の出現位置を採用）
        let textArray = Array(text)
        for link in linkTexts {
            guard link.count >= minWordLength else { continue }
            let linkArray = Array(link)
            if let startIdx = findFirstOccurrence(of: linkArray, in: textArray) {
                let endIdx = startIdx + linkArray.count
                addCandidate(
                    word: link,
                    type: .link,
                    start: startIdx,
                    end: endIdx,
                    into: &candidates,
                    seen: &seenRanges
                )
            }
        }

        // 重複範囲を解決（長い方を優先）
        return resolveOverlaps(candidates.sorted { $0.startIndex < $1.startIndex })
    }

    // MARK: - Helpers

    /// 候補を長さ検証・重複除外したうえで追加する
    private static func addCandidate(
        word: String,
        type: BlankType,
        start: Int,
        end: Int,
        into candidates: inout [Candidate],
        seen: inout Set<Range>
    ) {
        guard word.count >= minWordLength else { return }
        let key = Range(start: start, end: end)
        guard !seen.contains(key) else { return }
        seen.insert(key)
        candidates.append(Candidate(word: word, type: type, startIndex: start, endIndex: end))
    }

    /// `Set` に格納するための単純な整数範囲キー
    private struct Range: Hashable {
        let start: Int
        let end: Int
    }

    /// 正規表現マッチの中間表現（文字単位の位置を含む）
    private struct RegexMatch {
        let word: String
        let start: Int
        let end: Int
    }

    /// 正規表現で本文中のマッチを Character 単位の位置付きで取得する
    ///
    /// `NSRegularExpression` は UTF-16 単位の `NSRange` を返すため、
    /// `String.Index` 経由で Swift の `Character` 距離に変換している。
    private static func findMatches(pattern: String, in text: String) -> [RegexMatch] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let results = regex.matches(in: text, range: range)

        return results.compactMap { match in
            guard match.range.location != NSNotFound else { return nil }
            let word = nsText.substring(with: match.range)
            guard let swiftRange = Swift.Range(match.range, in: text) else { return nil }
            let start = text.distance(from: text.startIndex, to: swiftRange.lowerBound)
            let end = text.distance(from: text.startIndex, to: swiftRange.upperBound)
            return RegexMatch(word: word, start: start, end: end)
        }
    }

    /// `haystack` の中で最初に `needle` が現れる Character 位置を返す
    private static func findFirstOccurrence(of needle: [Character], in haystack: [Character]) -> Int? {
        guard !needle.isEmpty, haystack.count >= needle.count else { return nil }
        let lastStart = haystack.count - needle.count
        for i in 0...lastStart {
            var matched = true
            for j in 0..<needle.count where haystack[i + j] != needle[j] {
                matched = false
                break
            }
            if matched {
                return i
            }
        }
        return nil
    }

    /// 重複する範囲を長い方優先で解決する
    ///
    /// 事前に `startIndex` 昇順でソートされている前提。
    /// 直前の採用済み候補と範囲が重なる場合、
    /// より長い方（= より意味のある単位）で上書きする。
    private static func resolveOverlaps(_ sorted: [Candidate]) -> [Candidate] {
        var result: [Candidate] = []
        var lastEnd = -1

        for candidate in sorted {
            if candidate.startIndex >= lastEnd {
                result.append(candidate)
                lastEnd = candidate.endIndex
                continue
            }

            // 重複: 現在の候補が既存より長ければ置き換え
            if let last = result.last,
               (candidate.endIndex - candidate.startIndex) > (last.endIndex - last.startIndex) {
                result[result.count - 1] = candidate
                lastEnd = candidate.endIndex
            }
        }

        return result
    }

    /// displayText が長すぎる場合、最後の空所周辺でトリムする
    private static func trimIfTooLong(_ displayText: String, blankCount: Int) -> String {
        guard displayText.count > maxDisplayTextLength, blankCount > 0 else {
            return displayText
        }
        let lastBlankMarker = "[\(blankCount):____]"
        guard let range = displayText.range(of: lastBlankMarker, options: .backwards) else {
            return displayText
        }
        let remaining = displayText.distance(from: range.upperBound, to: displayText.endIndex)
        let tailCount = min(trailingTextAfterLastBlank, remaining)
        let endIndex = displayText.index(range.upperBound, offsetBy: tailCount)
        return String(displayText[..<endIndex]) + "..."
    }
}
