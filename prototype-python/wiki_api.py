"""Wikipedia API連携モジュール"""

import requests
from bs4 import BeautifulSoup

HEADERS = {
    "User-Agent": "WikiQuizProto/0.1 (https://github.com/example; contact@example.com)",
}


def search_articles(query: str, limit: int = 10) -> list[str]:
    """記事を検索してタイトル一覧を返す"""
    url = "https://ja.wikipedia.org/w/api.php"
    params = {
        "action": "opensearch",
        "search": query,
        "limit": limit,
        "namespace": 0,
        "format": "json",
    }
    resp = requests.get(url, params=params, timeout=10, headers=HEADERS)
    resp.raise_for_status()
    data = resp.json()
    # opensearch returns [query, [titles], [descriptions], [urls]]
    return data[1] if len(data) > 1 else []


def fetch_html(title: str) -> str:
    """記事のHTMLを取得する"""
    url = f"https://ja.wikipedia.org/api/rest_v1/page/html/{requests.utils.quote(title)}"
    resp = requests.get(url, timeout=15, headers={**HEADERS, "Accept": "text/html"})
    resp.raise_for_status()
    return resp.text


def extract_text_and_links(html: str) -> tuple[str, list[str]]:
    """HTMLからプレーンテキストとリンクテキスト一覧を抽出する"""
    soup = BeautifulSoup(html, "html.parser")

    # 不要要素を除去
    for tag in soup.select("table, style, script, sup, .mw-editsection, .reference, .reflist, .navbox, .metadata, .infobox"):
        tag.decompose()

    # リンクテキストを収集（内部リンクのみ）
    link_texts = []
    for a in soup.select("a[href^='./']"):
        text = a.get_text(strip=True)
        if len(text) >= 2:
            link_texts.append(text)

    # プレーンテキスト抽出
    # セクションごとにまとめる
    paragraphs = []
    for p in soup.select("p, li"):
        text = p.get_text(separator="", strip=True)
        if len(text) > 10:
            paragraphs.append(text)

    plain_text = "\n".join(paragraphs)
    return plain_text, link_texts


def get_article(title: str) -> tuple[str, list[str]]:
    """記事タイトルからテキストとリンク語一覧を取得する（便利関数）"""
    html = fetch_html(title)
    return extract_text_and_links(html)


if __name__ == "__main__":
    # テスト
    results = search_articles("東京タワー")
    print("検索結果:", results)
    if results:
        text, links = get_article(results[0])
        print(f"\nテキスト冒頭500文字:\n{text[:500]}")
        print(f"\nリンク語（先頭20件）: {links[:20]}")
