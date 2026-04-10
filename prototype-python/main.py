"""ウィキうめクイズ - CLIデモ"""

import sys
from wiki_api import search_articles, get_article
from quiz_generator import generate_quiz, check_answer, DIFFICULTY


def select_article() -> str:
    """記事を検索して選択"""
    while True:
        query = input("\n記事名を入力（例: 東京タワー）: ").strip()
        if not query:
            continue

        print(f"「{query}」を検索中...")
        results = search_articles(query)

        if not results:
            print("記事が見つかりませんでした。別のキーワードを試してください。")
            continue

        if len(results) == 1:
            print(f"→ {results[0]}")
            return results[0]

        print("\n候補:")
        for i, title in enumerate(results, 1):
            print(f"  {i}. {title}")

        while True:
            choice = input(f"番号を選択 (1-{len(results)}): ").strip()
            if choice.isdigit() and 1 <= int(choice) <= len(results):
                return results[int(choice) - 1]
            print("正しい番号を入力してください。")


def select_difficulty() -> str:
    """難易度を選択"""
    levels = list(DIFFICULTY.keys())
    print("\n難易度を選択:")
    for i, level in enumerate(levels, 1):
        rate = int(DIFFICULTY[level] * 100)
        print(f"  {i}. {level}（候補の{rate}%を穴埋め）")

    while True:
        choice = input("番号を選択 (1-3): ").strip()
        if choice.isdigit() and 1 <= int(choice) <= 3:
            return levels[int(choice) - 1]
        print("1, 2, 3 のいずれかを入力してください。")


def play_quiz(quiz: dict) -> None:
    """クイズを出題して回答を受け付ける"""
    blanks = quiz["blanks"]
    if not blanks:
        print("穴埋め候補が見つかりませんでした。別の記事を試してください。")
        return

    print("\n" + "=" * 60)
    print(f"  ウィキうめクイズ（{quiz['difficulty']}）- 全{len(blanks)}問")
    print("=" * 60)
    print()
    print(quiz["display_text"])
    print()
    print("-" * 60)
    print("各 [番号:____] に入る語を答えてください。")
    print("（スキップするにはEnterを押す）")
    print("-" * 60)

    correct_count = 0
    results = []

    for blank in blanks:
        num = blank["number"]
        answer = blank["answer"]
        hint_type = {
            "katakana": "カタカナ語",
            "number": "数字",
            "paren": "括弧内",
            "link": "関連語",
        }.get(blank["type"], "")

        user_input = input(f"\n  問{num} [{hint_type}]: ").strip()

        if not user_input:
            print(f"  → スキップ。正解は「{answer}」")
            results.append(False)
        elif check_answer(user_input, answer):
            print(f"  → 正解！")
            correct_count += 1
            results.append(True)
        else:
            print(f"  → 不正解。正解は「{answer}」")
            results.append(False)

    # スコア表示
    print()
    print("=" * 60)
    total = len(blanks)
    pct = int(correct_count / total * 100) if total > 0 else 0
    print(f"  結果: {correct_count}/{total} 問正解（{pct}%）")

    if pct == 100:
        print("  完璧！すばらしい！")
    elif pct >= 70:
        print("  よくできました！")
    elif pct >= 40:
        print("  まずまずですね。")
    else:
        print("  次はがんばりましょう！")
    print("=" * 60)


def main():
    print("=" * 60)
    print("  ウィキうめクイズ - Wikipedia穴埋めクイズ")
    print("=" * 60)

    while True:
        try:
            # 記事選択
            title = select_article()

            # 記事取得
            print(f"\n「{title}」の記事を取得中...")
            try:
                text, links = get_article(title)
            except Exception as e:
                print(f"記事の取得に失敗しました: {e}")
                continue

            if len(text) < 50:
                print("記事が短すぎます。別の記事を試してください。")
                continue

            # 難易度選択
            difficulty = select_difficulty()

            # クイズ生成・出題
            quiz = generate_quiz(text, links, difficulty)
            play_quiz(quiz)

            # 続けるか
            again = input("\n続けますか？ (y/n): ").strip().lower()
            if again != "y":
                print("\nまた遊んでね！")
                break

        except KeyboardInterrupt:
            print("\n\nまた遊んでね！")
            break
        except EOFError:
            break


if __name__ == "__main__":
    main()
