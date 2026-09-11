import ActivityKit

struct MusicActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isPlaying: Bool
        var progress: Double
    }
    var songName: String
    var artist: String
}
