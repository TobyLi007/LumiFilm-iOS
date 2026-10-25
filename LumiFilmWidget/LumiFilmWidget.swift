import WidgetKit
import SwiftUI

struct LumiFilmWidgetEntry: TimelineEntry {
    let date: Date
    let flashTitle: String
    let gn: Int
    let iso: Int
    let distanceM: Double
    let aperture: Double
    let recommendedPower: String
    let shutterDenom: Int
}

struct LumiFilmWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LumiFilmWidgetEntry {
        LumiFilmWidgetEntry(date: Date(), flashTitle: "Godox V350", gn: 36, iso: 400, distanceM: 2.0, aperture: 4.0, recommendedPower: "1/4", shutterDenom: 125)
    }
    func getSnapshot(in context: Context, completion: @escaping (LumiFilmWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LumiFilmWidgetEntry>) -> Void) {
        let entry = placeholder(in: context)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }
}

struct LumiFilmWidgetEntryView: View {
    var entry: LumiFilmWidgetProvider.Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("🎞️ \(entry.flashTitle)").font(.caption2.bold())
                Spacer()
                Text("ISO \(entry.iso)").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text("⚡ \(entry.recommendedPower)")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(.orange)
            Text(String(format: "%.1fm · f/%.1f · 1/%ds", entry.distanceM, entry.aperture, entry.shutterDenom))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

@main
struct LumiFilmWidget: Widget {
    let kind: String = "LumiFilmWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LumiFilmWidgetProvider()) { entry in
            LumiFilmWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("LumiFilm 闪光测光速查")
        .description("在 iOS 首屏桌面与锁屏实时显示当前胶卷 ISO、拍摄距离与推荐闪光灯功率比。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
