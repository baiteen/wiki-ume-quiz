# PL指示書: Wikipedia CC BY-SA 出典表示の実装

## 背景
Wikipedia の本文を穴埋めクイズとして使うには、CC BY-SA 3.0 (日本語版) / 4.0 (英語版) ライセンスに従った出典表示が必須。未対応のまま App Store に申請するとリジェクトのリスクがある。

## やること

### 1. Quiz モデルに出典情報を追加
`Models/Quiz.swift` に以下のプロパティを追加する（まだなければ）:

```swift
/// Wikipedia記事のタイトル（URLエンコード前）
let articleTitle: String

/// Wikipedia記事のURL
var articleURL: URL? {
    let encoded = articleTitle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? articleTitle
    return URL(string: "https://ja.wikipedia.org/wiki/\(encoded)")
}

/// ライセンス文（固定）
let licenseText = "出典: Wikipedia (CC BY-SA 3.0)"
```

### 2. QuizView に出典表示を追加
B案の1問1画面集中型UIの**下部**に、小さく出典リンクを表示する。

```swift
// QuizView.swift 末尾（VStackの最後）
HStack(spacing: 4) {
    Text("出典:")
        .font(.caption2)
        .foregroundStyle(.secondary)
    Link(viewModel.quiz.articleTitle, destination: viewModel.quiz.articleURL ?? URL(string: "https://ja.wikipedia.org")!)
        .font(.caption2)
    Text("(CC BY-SA 3.0)")
        .font(.caption2)
        .foregroundStyle(.secondary)
}
.padding(.bottom, 8)
.accessibilityElement(children: .combine)
.accessibilityLabel("出典は \(viewModel.quiz.articleTitle)、ライセンスは CC BY-SA 3.0")
```

### 3. ResultView に出典表示
リザルト画面にも同じ出典表示を入れる（プレイした記事の出典なので必須）。

### 4. 「このアプリについて」画面を新規追加
`Views/AboutView.swift` を作成し、ホーム画面のメニューからアクセスできるようにする。

**内容:**
```markdown
## ウィキうめクイズについて

本アプリは Wikipedia の記事を題材としたクイズゲームです。

### Wikipedia について
本アプリのクイズ問題は、Wikipedia の記事を抜粋・改変して生成しています。Wikipedia のコンテンツは クリエイティブ・コモンズ 表示-継承 ライセンス (CC BY-SA) に基づき提供されており、本アプリも同ライセンスの条件に従って再利用しています。

- Wikipedia 日本語版: CC BY-SA 3.0
- Wikipedia 英語版: CC BY-SA 4.0

本アプリは Wikipedia およびウィキメディア財団とは一切の提携・後援・承認関係にありません。

### 利用規約
[docs/legal/terms.md へのリンク or アプリ内表示]

### プライバシーポリシー
[docs/legal/privacy.md へのリンク or アプリ内表示]

### Wikipedia への寄付のお願い
本アプリを楽しんでいただけた方は、ぜひ Wikipedia への寄付もご検討ください。
https://donate.wikimedia.org/
```

### 5. HomeView にメニュー導線を追加
ナビゲーションバー右上に歯車アイコン or 「設定」ボタンを追加し、そこから AboutView に遷移。

### 6. テスト
- Quiz モデルの articleURL 生成テスト（URLエンコード含む）
- AboutView の表示テスト
- 既存テストが全てpassすること

## 参考
- docs/legal/wikipedia-attribution.md（本文面のソース）
- reports/research/2026-04-11-legal-compliance.md（CC BY-SA 対応の根拠）

## 備考
- 「Wikipedia」「ウィキペディア」の文字列をアプリ名やアイコンに使わない（商標回避）
- 「ウィキ」までは使ってOK（「ウィキうめクイズ」は問題なし）
