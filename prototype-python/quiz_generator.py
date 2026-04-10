"""穴埋めクイズ生成モジュール"""

import random
import re
import unicodedata


# 難易度設定（候補の何%を穴埋めにするか）
DIFFICULTY = {
    "かんたん": 0.10,
    "ふつう": 0.25,
    "むずかしい": 0.50,
}

# カタカナ語パターン（2文字以上）
RE_KATAKANA = re.compile(r"[ァ-ヶー]{2,}")
# 数字パターン（年号・数値）
RE_NUMBER = re.compile(r"\d+(?:\.\d+)?")
# 括弧内テキスト
RE_PAREN = re.compile(r"[（(]([^）)]+)[）)]")


def _normalize(text: str) -> str:
    """正規化: 全角半角統一 + カタカナ→ひらがな変換して比較用文字列を作る"""
    # NFKC正規化（全角英数→半角、半角カナ→全角など）
    text = unicodedata.normalize("NFKC", text)
    # 小文字化
    text = text.lower()
    # カタカナ→ひらがな
    result = []
    for ch in text:
        cp = ord(ch)
        if 0x30A1 <= cp <= 0x30F6:  # ァ-ヶ
            result.append(chr(cp - 0x60))
        else:
            result.append(ch)
    return "".join(result)


def check_answer(user_input: str, correct: str) -> bool:
    """正解判定（正規化して比較）"""
    return _normalize(user_input.strip()) == _normalize(correct.strip())


def extract_candidates(text: str, link_texts: list[str]) -> list[dict]:
    """テキストから穴埋め候補を抽出する

    Returns:
        list of {"word": str, "type": str, "start": int, "end": int}
    """
    candidates = []
    seen_positions = set()  # 重複排除用

    def _add(match_or_word, ctype, start=None, end=None):
        if hasattr(match_or_word, "start"):
            word = match_or_word.group()
            s, e = match_or_word.start(), match_or_word.end()
        else:
            word = match_or_word
            s, e = start, end
        if s is None:
            return
        # 重複チェック（同じ位置に複数候補が被らないように）
        pos_key = (s, e)
        if pos_key in seen_positions:
            return
        # 短すぎるものは除外
        if len(word) < 2:
            return
        seen_positions.add(pos_key)
        candidates.append({"word": word, "type": ctype, "start": s, "end": e})

    # カタカナ語
    for m in RE_KATAKANA.finditer(text):
        _add(m, "katakana")

    # 数字（3桁以上＝年号や統計値を優先）
    for m in RE_NUMBER.finditer(text):
        if len(m.group()) >= 3:
            _add(m, "number")

    # 括弧内テキスト
    for m in RE_PAREN.finditer(text):
        inner = m.group(1).strip()
        if 2 <= len(inner) <= 20:
            _add(inner, "paren", m.start(1), m.end(1))

    # リンクテキスト（テキスト中に出現する箇所を探す）
    for link in link_texts:
        # テキスト内で最初に見つかった位置
        idx = text.find(link)
        if idx >= 0:
            _add(link, "link", idx, idx + len(link))

    # 重複する範囲を持つ候補を除去（長い方を優先）
    candidates.sort(key=lambda c: c["start"])
    filtered = []
    last_end = -1
    for c in candidates:
        if c["start"] >= last_end:
            filtered.append(c)
            last_end = c["end"]
        else:
            # 重複: 長い方を採用
            if filtered and c["end"] - c["start"] > filtered[-1]["end"] - filtered[-1]["start"]:
                filtered[-1] = c
                last_end = c["end"]

    return filtered


def generate_quiz(text: str, link_texts: list[str], difficulty: str = "ふつう") -> dict:
    """穴埋めクイズを生成する

    Returns:
        {
            "display_text": str,  # 穴埋め表示用テキスト
            "blanks": [{"number": int, "answer": str, "type": str}],
            "difficulty": str,
        }
    """
    rate = DIFFICULTY.get(difficulty, 0.25)
    candidates = extract_candidates(text, link_texts)

    if not candidates:
        return {"display_text": text, "blanks": [], "difficulty": difficulty}

    # 難易度に応じて穴埋め数を決定
    num_blanks = max(1, int(len(candidates) * rate))
    num_blanks = min(num_blanks, 20)  # 最大20問

    # ランダムに選択
    selected = sorted(
        random.sample(candidates, min(num_blanks, len(candidates))),
        key=lambda c: c["start"],
    )

    # テキストを組み立て
    display_parts = []
    blanks = []
    prev_end = 0
    for i, c in enumerate(selected, 1):
        display_parts.append(text[prev_end : c["start"]])
        blank_label = f"[{i}:____]"
        display_parts.append(blank_label)
        blanks.append({"number": i, "answer": c["word"], "type": c["type"]})
        prev_end = c["end"]
    display_parts.append(text[prev_end:])

    display_text = "".join(display_parts)

    # 長すぎる場合は適度にトリミング
    if len(display_text) > 2000:
        # 最後の穴埋め箇所以降で切る
        last_blank_pos = display_text.rfind(f"[{len(blanks)}:____]")
        if last_blank_pos > 0:
            cut_pos = min(last_blank_pos + 200, len(display_text))
            display_text = display_text[:cut_pos] + "..."

    return {
        "display_text": display_text,
        "blanks": blanks,
        "difficulty": difficulty,
    }


if __name__ == "__main__":
    # テスト
    sample = "東京タワー（とうきょうタワー、英: Tokyo Tower）は、東京都港区芝公園にある総合電波塔。1958年（昭和33年）12月23日竣工。高さ333メートル。"
    links = ["東京都", "港区", "芝公園", "電波塔"]
    quiz = generate_quiz(sample, links, "ふつう")
    print(quiz["display_text"])
    print()
    for b in quiz["blanks"]:
        print(f"  問{b['number']}: {b['answer']} ({b['type']})")
