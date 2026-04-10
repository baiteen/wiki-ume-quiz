# ウィキうめクイズ

Wikipediaの記事から自動生成される穴埋めクイズアプリ（iOS）。

好きなWikipediaページを選んで難易度を選んでスタート。Wikipediaが存在する限りクイズは無限に増え続ける。

## ドキュメント

- [設計書](specs/wiki-quiz-app.md) — 全体仕様、画面構成、技術スタック、マネタイズ
- [PL実装指示書](specs/wiki-ume-quiz-pl-instructions.md) — PL向けの実装ガイド（v1.0スコープ、ファイル構成、API仕様）

## プロトタイプ

[prototype-python/](prototype-python/) — Wikipedia API + 穴埋めロジックのPython実装。穴埋め生成がAIなしで成立することを実証済み。

### 動かし方

```bash
cd prototype-python
pip install -r requirements.txt
python3 main.py
```

「東京タワー」などの記事名を入力してクイズを開始できる。

`quiz_generator_v2.py` は janome を使った形態素解析版。複合固有名詞（「東京タワー」「日本電波塔株式会社」等）も穴埋め候補にできる。

## ステータス

- [x] 設計書
- [x] Pythonプロトタイプ（穴埋めロジック検証）
- [x] 形態素解析版（v2）
- [ ] iOS実装（PL着手予定）
- [ ] App Storeリリース
