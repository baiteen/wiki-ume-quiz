"""穴埋めクイズ生成 v2 - janome形態素解析で固有名詞・名詞句を抽出"""
from janome.tokenizer import Tokenizer
import random
import re

_tokenizer = None

def _get_tokenizer():
    global _tokenizer
    if _tokenizer is None:
        _tokenizer = Tokenizer()
    return _tokenizer


def extract_blank_candidates(text):
    """テキストから穴埋め候補を抽出する。

    返り値: List[(start, end, surface, type)]
    type: "proper" (固有名詞), "number" (数), "noun" (一般名詞)
    """
    tokenizer = _get_tokenizer()
    candidates = []

    # janome は char offset を返さないので surface を順次走査して位置を求める
    pos = 0
    tokens = list(tokenizer.tokenize(text))

    # 名詞の連続を1つの複合名詞にまとめる
    i = 0
    while i < len(tokens):
        token = tokens[i]
        pos_features = token.part_of_speech.split(",")
        major = pos_features[0]
        sub1 = pos_features[1] if len(pos_features) > 1 else ""

        if major == "名詞":
            # 連続する名詞を結合（接尾辞は単独だと意味薄いので、前の名詞と必ず結合）
            j = i
            combined = ""
            kinds = []
            while j < len(tokens):
                t = tokens[j]
                pf = t.part_of_speech.split(",")
                if pf[0] != "名詞":
                    break
                # 助数詞・代名詞は止める
                if pf[1] in ("代名詞", "非自立"):
                    break
                combined += t.surface
                kinds.append(pf[1])
                j += 1

            # candidate type 判定
            if "数" in kinds:
                cand_type = "number"
            elif "固有名詞" in kinds:
                cand_type = "proper"
            else:
                cand_type = "noun"

            # ノイズ除去: 1文字の接尾辞だけ、ひらがなだけ、記号など
            if len(combined) >= 2 and not combined.isspace():
                # 完全にひらがなだけはスキップ
                if not all('\u3040' <= c <= '\u309f' for c in combined):
                    # 数字+助数詞のみは number 扱い
                    start = text.find(combined, pos)
                    if start >= 0:
                        end = start + len(combined)
                        candidates.append((start, end, combined, cand_type))
                        pos = end

            i = j
        else:
            # 非名詞は位置だけ進める
            start = text.find(token.surface, pos)
            if start >= 0:
                pos = start + len(token.surface)
            i += 1

    return candidates


def generate_quiz(text, difficulty="normal", max_questions=20):
    """テキストから穴埋めクイズを生成する。

    difficulty: "easy" / "normal" / "hard"
    return: List[dict] - 各dict: {position: (start, end), surface: str, type: str}
    """
    candidates = extract_blank_candidates(text)
    if not candidates:
        return []

    # 重複削除（同じ位置の重複）
    seen = set()
    unique = []
    for c in candidates:
        key = (c[0], c[1])
        if key not in seen:
            seen.add(key)
            unique.append(c)

    # 難易度別の選択割合
    ratio = {"easy": 0.10, "normal": 0.25, "hard": 0.50}.get(difficulty, 0.25)

    # 優先度: 固有名詞 > 数 > 一般名詞
    priority = {"proper": 0, "number": 1, "noun": 2}
    unique.sort(key=lambda c: (priority.get(c[3], 3), c[0]))

    n = max(1, min(max_questions, int(len(unique) * ratio)))
    selected = unique[:n]

    # 元の出現順に並べ直す
    selected.sort(key=lambda c: c[0])

    return [
        {"position": (c[0], c[1]), "surface": c[2], "type": c[3]}
        for c in selected
    ]


def render_with_blanks(text, questions):
    """questions の位置を [___] に置き換えたテキストを返す"""
    result = []
    last = 0
    for i, q in enumerate(questions):
        start, end = q["position"]
        result.append(text[last:start])
        result.append(f"[{i+1}:____]")
        last = end
    result.append(text[last:])
    return "".join(result)


if __name__ == "__main__":
    # 動作確認
    sample = (
        "東京タワーは1958年に日本電波塔株式会社が東京都港区に建設した総合電波塔である。"
        "正式名称は日本電波塔。設計は内藤多仲。高さは333メートルで、東京のシンボルとして知られている。"
    )

    print("=" * 60)
    print("候補一覧:")
    for c in extract_blank_candidates(sample):
        print(f"  {c[3]:8s} '{c[2]}'")

    print("=" * 60)
    for diff in ["easy", "normal", "hard"]:
        print(f"\n--- 難易度: {diff} ---")
        questions = generate_quiz(sample, difficulty=diff)
        print(f"問題数: {len(questions)}")
        print(render_with_blanks(sample, questions))
        print("正解:")
        for i, q in enumerate(questions, 1):
            print(f"  {i}. {q['surface']} ({q['type']})")
