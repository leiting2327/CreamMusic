import SwiftUI
import ActivityKit

// 灵动岛视图（iOS 16.1+）
@available(iOS 16.1, *)
struct MusicActivityLiveView: View {
    let context: ActivityViewContext<MusicActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：封面 + 歌曲信息
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [.orange.opacity(0.8), .pink.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "music.note")
                    .foregroundColor(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.songName)
                    .font(.caption2).bold()
                    .lineLimit(1)
                Text(context.attributes.artist)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 右侧：播放状态
            Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 12)
    }
}

// 锁屏/通知栏扩展视图
@available(iOS 16.1, *)
struct MusicActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MusicActivityAttributes.self) { context in
            MusicActivityLiveView(context: context)
                .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "music.note")
                        Text(context.attributes.songName).font(.caption).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                }
                DynamicIslandExpandedRegion(.center) {
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(.linear)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.artist).font(.caption2).foregroundColor(.secondary)
                }
            } compactLeading: {
                Image(systemName: "music.note").foregroundColor(.orange)
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill").foregroundColor(.orange)
            } minimal: {
                Image(systemName: "music.note").foregroundColor(.orange)
            }
        }
    }
}
