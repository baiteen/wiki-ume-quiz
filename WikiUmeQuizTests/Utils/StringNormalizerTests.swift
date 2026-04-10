import XCTest
@testable import WikiUmeQuiz

final class StringNormalizerTests: XCTestCase {
    func test_normalize_fullwidthNumberToHalfwidth() {
        XCTAssertEqual(StringNormalizer.normalize("１２３"), "123")
        XCTAssertEqual(StringNormalizer.normalize("１９５８年"), "1958年")
    }

    func test_normalize_katakanaToHiragana() {
        XCTAssertEqual(StringNormalizer.normalize("タワー"), "たわー")
        XCTAssertEqual(StringNormalizer.normalize("トウキョウ"), "とうきょう")
    }

    func test_normalize_trimsWhitespace() {
        XCTAssertEqual(StringNormalizer.normalize("  test  "), "test")
    }

    func test_normalize_lowercases() {
        XCTAssertEqual(StringNormalizer.normalize("Tokyo"), "tokyo")
    }

    func test_isEqualIgnoringVariations_tolerantComparison() {
        XCTAssertTrue(StringNormalizer.isEqualIgnoringVariations("タワー", "たわー"))
        XCTAssertTrue(StringNormalizer.isEqualIgnoringVariations("１９５８", "1958"))
        XCTAssertTrue(StringNormalizer.isEqualIgnoringVariations(" 東京 ", "東京"))
        XCTAssertFalse(StringNormalizer.isEqualIgnoringVariations("タワー", "タイマー"))
    }
}
