import Foundation
import SwiftData

@Model
final class PlayHistory {
    var articleTitle: String
    var difficulty: String
    var score: Int
    var correctCount: Int
    var totalCount: Int
    var timeSeconds: Int
    var hintsUsed: Int
    var playedAt: Date

    init(articleTitle: String, difficulty: String, score: Int, correctCount: Int, totalCount: Int, timeSeconds: Int, hintsUsed: Int, playedAt: Date) {
        self.articleTitle = articleTitle
        self.difficulty = difficulty
        self.score = score
        self.correctCount = correctCount
        self.totalCount = totalCount
        self.timeSeconds = timeSeconds
        self.hintsUsed = hintsUsed
        self.playedAt = playedAt
    }
}
