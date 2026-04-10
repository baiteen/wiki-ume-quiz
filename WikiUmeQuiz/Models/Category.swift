import Foundation

/// ホーム画面で提示する記事カテゴリ
///
/// MVP では Wikipedia からの動的取得は行わず、カテゴリごとに固定の
/// おすすめ記事名リストを返す。Phase 6 以降で動的取得や SwiftData 連携を検討する。
enum Category: String, CaseIterable, Identifiable {
    case history = "歴史"
    case science = "科学"
    case geography = "地理"
    case sports = "スポーツ"
    case entertainment = "エンタメ"

    var id: String { rawValue }

    /// カテゴリごとの固定おすすめ記事タイトル
    ///
    /// Wikipedia 日本語版に存在する記事名に揃えている。
    var recommendedArticles: [String] {
        switch self {
        case .history:
            return ["織田信長", "坂本龍馬", "第二次世界大戦", "ルネサンス", "江戸時代"]
        case .science:
            return ["相対性理論", "光合成", "DNA", "ブラックホール", "元素の周期表"]
        case .geography:
            return ["富士山", "アマゾン川", "サハラ砂漠", "エベレスト", "太平洋"]
        case .sports:
            return ["オリンピック", "サッカー", "野球", "テニス", "マラソン"]
        case .entertainment:
            return ["東京タワー", "ジブリ", "ポケットモンスター", "ハリウッド", "ビートルズ"]
        }
    }

    /// カテゴリを象徴する SF Symbol 名
    var iconName: String {
        switch self {
        case .history: return "book.closed.fill"
        case .science: return "atom"
        case .geography: return "globe.asia.australia.fill"
        case .sports: return "sportscourt.fill"
        case .entertainment: return "star.fill"
        }
    }
}
