# ウィキうめクイズ — PL実装指示書

## 概要
Wikipedia記事から穴埋めクイズを自動生成するiOSアプリ。
ユーザーが好きなWikipediaページを選び、難易度を選んでスタート。正解率やタイムを記録。

**リポジトリ**: https://github.com/baiteen/wiki-ume-quiz
**設計書**: specs/wiki-quiz-app.md
**プロトタイプ（Python版）**: projects/wiki-quiz-proto/（穴埋めロジックの参考実装）
**Firebase連携ガイド**: reports/research/2026-04-09-firebase-swift-guide.md

---

## MVP（v1.0）スコープ

以下の機能だけ実装する。ランキング・認証・課金・広告はv1.1以降。

### 実装する画面

#### 1. ホーム画面
- 検索バー（Wikipedia記事検索）
- 最近プレイした記事リスト（ローカル保存）
- カテゴリボタン（歴史、科学、地理、スポーツ、エンタメ）→ タップでおすすめ記事一覧

#### 2. 記事選択画面
- 記事タイトルと冒頭3行のプレビュー
- 難易度選択ボタン3つ:
  - かんたん（穴埋め候補の10%）
  - ふつう（穴埋め候補の25%）
  - むずかしい（穴埋め候補の50%）
- 「スタート」ボタン

#### 3. クイズ画面
- 記事本文を表示。穴埋め箇所は `[___]` で表示（タップ可能）
- 穴埋め箇所をタップ → テキストフィールドにフォーカス → 入力 → 確定
- 正解: 緑で表示
- 不正解: 赤で表示、正解を薄いグレーで表示
- 画面上部: タイマー（mm:ss）、進捗（3/20問）
- ヒントボタン: 1文字目を表示（使用回数カウント）
- ギブアップボタン: 残りの答えを全表示してリザルトへ

#### 4. リザルト画面
- 正解数 / 全問数
- 正解率（%）
- クリアタイム
- ヒント使用回数
- スコア = 正解数 × 難易度倍率(かんたん:1, ふつう:2, むずかしい:3) × max(1, 時間ボーナス)
  - 時間ボーナス = 300秒以内なら (300 - 経過秒数) / 300 + 1
- 「もう一回」ボタン（同じ記事・同じ難易度）
- 「別の記事」ボタン（ホームに戻る）

---

## 技術仕様

### アーキテクチャ
- Swift / SwiftUI
- MVVM
- iOS 16.0+
- ローカルDB: SwiftData

### Wikipedia API

**記事検索:**
```
GET https://ja.wikipedia.org/w/api.php?action=opensearch&search={query}&limit=10&format=json
```
レスポンス: `[query, [titles], [descriptions], [urls]]`

**記事本文取得:**
```
GET https://ja.wikipedia.org/w/api.php?action=parse&page={title}&prop=text&format=json
```
レスポンス: `{ parse: { text: { "*": "<html>" } } }`

**重要:** User-Agentヘッダー必須。例: `WikiUmeQuiz/1.0 (contact@example.com)`

### 穴埋めロジック

Pythonプロトタイプ（projects/wiki-quiz-proto/quiz_generator.py）をSwiftに移植する。

**手順:**
1. APIから記事HTMLを取得
2. HTMLをパースしてプレーンテキスト化（リンク情報は保持）
3. 穴埋め候補を抽出:
   - カタカナ語: 正規表現 `[ァ-ヶー]{2,}` にマッチする語
   - 数字: 正規表現 `[0-9０-９]+` にマッチする語（年号、人数等）
   - リンク語: HTMLの `<a>` タグ内テキスト
4. 難易度に応じて候補からランダム選択
5. 最大20問に制限（多すぎると疲れる）

**正解判定（表記ゆれ対応）:**
- 全角数字↔半角数字を正規化して比較
- カタカナ↔ひらがなを正規化して比較
- 前後の空白をtrim

### データモデル（SwiftData）

```swift
@Model
class PlayHistory {
    var articleTitle: String
    var difficulty: String  // "easy", "normal", "hard"
    var score: Int
    var correctCount: Int
    var totalCount: Int
    var timeSeconds: Int
    var hintsUsed: Int
    var playedAt: Date
}
```

### ファイル構成（推奨）

```
WikiUmeQuiz/
├── App/
│   └── WikiUmeQuizApp.swift
├── Models/
│   ├── PlayHistory.swift
│   ├── QuizQuestion.swift
│   └── WikiArticle.swift
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── QuizViewModel.swift
│   └── ResultViewModel.swift
├── Views/
│   ├── HomeView.swift
│   ├── ArticleSelectView.swift
│   ├── QuizView.swift
│   └── ResultView.swift
├── Services/
│   ├── WikipediaService.swift
│   └── QuizGenerator.swift
├── Utils/
│   └── StringNormalizer.swift  // 表記ゆれ正規化
└── Resources/
    └── Assets.xcassets
```

---

## UI/デザイン方針

- カラー: 白ベース、アクセントカラーはWikipediaの青（#3366CC）
- 穴埋め箇所: 下線付き、タップ前は薄いグレー背景
- フォント: 本文は読みやすいサイズ（16pt）、タイマーはモノスペース
- アニメーション: 正解/不正解時に軽いフィードバック（色変化 + 軽い振動）

---

## 実装順序

| Phase | 内容 | 依存 |
|-------|------|------|
| 1 | WikipediaService（API通信＋HTML→テキスト変換） | なし |
| 2 | QuizGenerator（穴埋めロジック） | Phase 1 |
| 3 | QuizView + QuizViewModel（クイズ画面） | Phase 2 |
| 4 | ResultView（リザルト画面） | Phase 3 |
| 5 | HomeView + 検索機能 | Phase 1 |
| 6 | SwiftData（プレイ履歴保存） | Phase 4 |
| 7 | 全体結合＋テスト | 全部 |

---

## やらないこと（v1.0）

- Firebase連携（認証・ランキング・人気ページ）→ v1.1
- 英語Wikipedia対応 → v1.1
- バッジ・実績 → v1.2
- シェア機能 → v1.2
- 課金・広告 → v1.2
- えげつない難易度 → v1.2
- Android版 → v1.0リリース後
