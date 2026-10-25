import SwiftUI
import AppIntents
import WidgetKit
import AVFoundation

@main
struct LumiFilmApp: App {
    init() {
        LumiFilmShortcutsProvider.updateAppShortcutParameters()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct FlashModelSpec: Identifiable, Hashable {
    let id: String
    let nameZh: String
    let nameEn: String
    let nameJa: String
    let shortName: String
    let baseGN: Double
    let ratedZoom: Int
    let minPowerDenom: Int
    let recycleSec: Double
}

final class ExposureStore: ObservableObject {
    static let shared = ExposureStore()

    @AppStorage("lf_lang") var lang: String = "zh"
    @AppStorage("lf_flash_id") var flashId: String = "godox-v350"
    @AppStorage("lf_is_custom_gn") var isCustomGN: Bool = false
    @AppStorage("lf_custom_gn_val") var customGNVal: Double = 36.0
    @AppStorage("lf_film_name") var filmName: String = "Kodak Portra 400"
    @AppStorage("lf_iso") var iso: Int = 400
    @AppStorage("lf_zoom_mm") var zoomMM: Int = 50
    @AppStorage("lf_max_sync") var maxSyncDenom: Int = 125
    @AppStorage("lf_distance_m") var distanceM: Double = 2.0
    @AppStorage("lf_aperture") var aperture: Double = 4.0
    @AppStorage("lf_power_stops") var powerStopOffset: Double = -2.0
    @AppStorage("lf_shutter_denom") var shutterDenom: Int = 125
    @AppStorage("lf_mod_loss") var modifierLossEV: Double = 0.0
    @AppStorage("lf_bounce_loss") var bounceLossEV: Double = 0.0

    let catalog: [FlashModelSpec] = [
        FlashModelSpec(id: "godox-v350", nameZh: "神牛 Godox V350 (主力推荐)", nameEn: "Godox V350 (Primary)", nameJa: "Godox V350 (推奨)", shortName: "Godox V350", baseGN: 36, ratedZoom: 105, minPowerDenom: 128, recycleSec: 1.7),
        FlashModelSpec(id: "godox-tt350", nameZh: "神牛 Godox TT350 (AA版)", nameEn: "Godox TT350", nameJa: "Godox TT350", shortName: "Godox TT350", baseGN: 36, ratedZoom: 105, minPowerDenom: 128, recycleSec: 2.2),
        FlashModelSpec(id: "godox-lux-jr", nameZh: "神牛 Godox Lux Junior", nameEn: "Godox Lux Junior", nameJa: "Godox Lux Junior", shortName: "Lux Junior", baseGN: 12, ratedZoom: 28, minPowerDenom: 64, recycleSec: 3.0),
        FlashModelSpec(id: "godox-v1pro", nameZh: "神牛 Godox V1Pro", nameEn: "Godox V1Pro", nameJa: "Godox V1Pro", shortName: "Godox V1Pro", baseGN: 42, ratedZoom: 105, minPowerDenom: 256, recycleSec: 1.3),
        FlashModelSpec(id: "godox-v860iii", nameZh: "神牛 Godox V860III", nameEn: "Godox V860III", nameJa: "Godox V860III", shortName: "Godox V860III", baseGN: 60, ratedZoom: 200, minPowerDenom: 256, recycleSec: 1.5),
        FlashModelSpec(id: "profoto-a10", nameZh: "Profoto A10", nameEn: "Profoto A10", nameJa: "Profoto A10", shortName: "Profoto A10", baseGN: 42, ratedZoom: 105, minPowerDenom: 256, recycleSec: 1.0)
    ]

    var activeFlashSpec: FlashModelSpec {
        catalog.first(where: { $0.id == flashId }) ?? catalog[0]
    }

    var activeGN: Double {
        isCustomGN ? customGNVal : activeFlashSpec.baseGN
    }

    var displayFlashTitle: String {
        if isCustomGN {
            if lang == "en" { return "User Custom" }
            if lang == "ja" { return "ユーザーカスタム" }
            return "用户自定义"
        }
        return activeFlashSpec.shortName
    }

    func calculateRecommendedPower(distance: Double, fStop: Double) -> (powerText: String, stopOffset: Double) {
        let spec = activeFlashSpec
        let minStops = -log2(Double(spec.minPowerDenom))
        let zoomFactor = isCustomGN ? 1.0 : pow(Double(zoomMM) / Double(spec.ratedZoom), 0.38)
        let gn100 = activeGN * zoomFactor
        let isoFactor = sqrt(Double(iso) / 100.0)
        let totalLoss = modifierLossEV + bounceLossEV
        let lossFactor = pow(2.0, -totalLoss / 2.0)
        let fullEffGN = max(gn100 * isoFactor * lossFactor, 0.1)

        let reqGN = fStop * distance
        let reqRatio = pow(reqGN / fullEffGN, 2.0)
        let rawStops = log2(max(reqRatio, 1e-6))
        let snapped = (rawStops * 3.0).rounded() / 3.0
        let clamped = min(max(snapped, minStops), 0.0)

        return (formatPower(clamped, minDenom: spec.minPowerDenom), clamped)
    }

    func formatPower(_ stopOffset: Double, minDenom: Int) -> String {
        let minStops = -log2(Double(minDenom))
        let clamped = min(max(stopOffset, minStops), 0.0)
        let roundedThirds = (clamped * 3.0).rounded() / 3.0
        let whole = floor(roundedThirds + 1e-6)
        let rem = roundedThirds - whole
        let denom = Int(pow(2.0, -whole).rounded())
        let base = "1/\(denom)"
        if rem > 0.5 { return "\(base) +0.7" }
        if rem > 0.16 { return "\(base) +0.3" }
        return base
    }
}

struct CalculateFlashPowerIntent: AppIntent {
    static var title: LocalizedStringResource = "计算闪光灯输出功率 (LumiFilm)"
    static var description = IntentDescription("输入拍摄距离与光圈，立即计算并语音播报闪光灯手动输出功率比，可直接绑定 iPhone 动作按钮或锁屏快捷键。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "拍摄距离 (米 / Meters)", default: 2.0)
    var distanceMeters: Double

    @Parameter(title: "光圈大小 (f-stop)", default: 4.0)
    var apertureFStop: Double

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let store = ExposureStore.shared
        store.distanceM = distanceMeters
        store.aperture = apertureFStop
        let result = store.calculateRecommendedPower(distance: distanceMeters, fStop: apertureFStop)
        store.powerStopOffset = result.stopOffset
        WidgetCenter.shared.reloadAllTimelines()

        let dialogText = "距离 \(String(format: "%.1f", distanceMeters)) 米，光圈 f/\(String(format: "%.1f", apertureFStop))，请将【\(store.displayFlashTitle)】调至 \(result.powerText) 功率。"
        return .result(dialog: IntentDialog(stringLiteral: dialogText)) {
            VStack(alignment: .leading, spacing: 6) {
                Text("⚡ LumiFilm · \(store.displayFlashTitle) (GN\(Int(store.activeGN)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("推荐闪光功率：\(result.powerText)")
                    .font(.title3.bold())
                Text("距离 \(String(format: "%.1f", distanceMeters))m · f/\(String(format: "%.1f", apertureFStop)) · ISO \(store.iso) · 1/\(store.shutterDenom)s")
                    .font(.caption2)
            }
            .padding()
        }
    }
}

struct LumiFilmShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CalculateFlashPowerIntent(),
            phrases: [
                "用 \(.applicationName) 算闪光灯功率",
                "Ask \(.applicationName) for flash power",
                "\(.applicationName) 测光速算"
            ],
            shortTitle: "闪光灯测光速算",
            systemImageName: "bolt.circle.fill"
        )
    }
}
