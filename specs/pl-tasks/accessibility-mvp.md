# PL指示書: アクセシビリティ MVP 10項目

## 背景
アクセシビリティ調査で **致命的な問題**が発見された: QuizView が VoiceOver で完全にプレイ不能。`[1:____]` プレースホルダがそのまま読まれるため、視覚障害者は絶対に遊べない。

その他、Dynamic Type 対応、タップ領域、カラーコントラストに複数の不適合箇所がある。現状の WCAG 2.2 AA 準拠率は約63%、本指示書のMVP10項目対応で約90%に上がる見込み。

## 優先度: 高（リリース前に必須）

## MVP 10項目

### 1. QuizView の穴埋めに accessibilityLabel を付与（最優先）
`[1:____]` をそのまま VoiceOver で読ませない。装飾済みの AttributedString の各 run に対して適切なラベルを付ける。

**実装方針:**
- 現問題: "1番目の穴埋め、まだ未回答"
- 正解済み: "1番目の穴埋め、正解は◯◯"
- 不正解: "1番目の穴埋め、不正解。正解は◯◯、あなたの答えは△△"
- 未来問題: "2番目以降の穴埋め、未回答"

`accessibilityLabel(_:)` modifier を各 Text に適用。`AttributedString` を使う場合は `attribute(.accessibilityLabel, value: ...)` で上書き。

### 2. Dynamic Type 対応（フォントサイズを relative に）
`QuizView.swift` の 17pt hardcode と `ResultView.swift` の 48pt hardcode を撤去し、Text のスタイルは `.font(.title)` など Dynamic Type に連動する型で指定する。

**修正対象:**
```swift
// Before
.font(.system(size: 17))
.font(.system(size: 48))

// After
.font(.title2)            // QuizView 本文
.font(.largeTitle)        // ResultView スコア表示
```

**確認方法:** Xcode の Environment Overrides で Dynamic Type を Accessibility Extra Extra Large に設定し、レイアウトが崩れないか目視確認。

### 3. タップ領域 44pt 以上確保
ヒントボタン（現状 caption font）、スキップボタン、難易度選択ボタンが 44pt 未満。`.frame(minWidth: 44, minHeight: 44)` を追加する。または `.contentShape(Rectangle())` + `.frame(minHeight: 44)`。

### 4. カラーコントラスト AA 準拠
未回答の穴埋めに使っている `Color.gray`（コントラスト比3.4:1）を AA 基準の4.5:1以上にする。

**候補:**
- Light: `Color(hex: 0x595959)` (7.0:1)
- Dark: `Color(hex: 0xA0A0A0)` (7.5:1)

ダークモード対応で `Color("BlankTextColor")` として Assets.xcassets に登録する。

### 5. ボタンの accessibility trait
`.buttonStyle` を使っている場所は自動でOKだが、`Image` や `Text` をタップで使っている箇所に `.accessibilityAddTraits(.isButton)` を付与。

### 6. 画像の代替テキスト
すべての `Image(systemName:)` に `.accessibilityLabel("説明")` を付ける（装飾画像は `.accessibilityHidden(true)`）。

### 7. NavigationTitle に意味のある文字列
各画面の `.navigationTitle("...")` に具体的なタイトルを設定（空や記号だけにしない）。

### 8. Reduce Motion 対応
`@Environment(\.accessibilityReduceMotion) var reduceMotion` を取得し、true のときはアニメーションを無効化。

**対象:** クイズ画面の穴埋め遷移アニメーション、リザルト画面のスコアカウントアップ

### 9. VoiceOver でのフォーカス順
`.accessibilityElement(children: .combine)` または `.contain` を適切に設定し、論理順にフォーカスが移動するようにする。

### 10. Accessibility Inspector 全体パス
Xcode の Accessibility Inspector (Run → Open Developer Tool) で Audit を実行し、警告ゼロを目指す。

## テスト手順

1. **VoiceOver 実機テスト**
   - iPhone で Settings → Accessibility → VoiceOver を ON
   - ウィキうめクイズを起動し、クイズを最後までプレイできるか確認
   - すべての問題が正しく読み上げられ、回答できること

2. **Dynamic Type テスト**
   - Xcode Environment Overrides で Accessibility Extra Extra Large に設定
   - 全画面でレイアウト崩れなし

3. **コントラスト検証**
   - Accessibility Inspector → Audit
   - Contrast 関連の警告が出ないこと

4. **既存のXCTestが全pass**

## 参考
- reports/research/2026-04-10-accessibility.md（詳細レポート、疑似diff付き）
- Apple公式: Accessibility for SwiftUI
- WCAG 2.2 AA準拠率63%→90% が目標

## 備考
MVP 10項目の想定工数: 約2.75人日
