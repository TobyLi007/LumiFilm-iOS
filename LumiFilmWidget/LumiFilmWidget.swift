import WidgetKit; import SwiftUI; import AppIntents; import Foundation; import Darwin
enum WidgetTheme: Int { case sakuraMist = 0
case threadsMinimal = 1; case leicaBrushedBrass = 2; var nameText: String { switch self { case .sakuraMist: return "雾粉微光"
case .threadsMinimal: return "曜石纯黑"; case .leicaBrushedBrass: return "黑漆露铜" }}; var accent: Color { switch self { case .sakuraMist: return Color(red: 0.94, green: 0.79, blue: 0.82)
case .threadsMinimal: return Color(red: 0.96, green: 0.96, blue: 0.98); case .leicaBrushedBrass: return Color(red: 0.90, green: 0.68, blue: 0.32) }}; var secondaryAccent: Color { switch self { case .sakuraMist: return Color(red: 0.86, green: 0.82, blue: 0.78)
case .threadsMinimal: return Color(red: 0.58, green: 0.62, blue: 0.70); case .leicaBrushedBrass: return Color(red: 0.78, green: 0.48, blue: 0.22) }}; var backgroundGradient: [Color] { switch self { case .sakuraMist: return [Color(red: 0.17, green: 0.16, blue: 0.20), Color(red: 0.24, green: 0.20, blue: 0.23), Color(red: 0.22, green: 0.19, blue: 0.21), Color(red: 0.14, green: 0.14, blue: 0.17)]
case .threadsMinimal: return [Color(red: 0.03, green: 0.03, blue: 0.04), Color(red: 0.09, green: 0.09, blue: 0.11), Color(red: 0.04, green: 0.04, blue: 0.05)]
case .leicaBrushedBrass: return [Color(red: 0.09, green: 0.08, blue: 0.07), Color(red: 0.19, green: 0.14, blue: 0.09), Color(red: 0.28, green: 0.20, blue: 0.11), Color(red: 0.08, green: 0.07, blue: 0.06)] }}
var lcdBg: Color { switch self { case .sakuraMist: return Color(red: 0.12, green: 0.11, blue: 0.15).opacity(0.88); case .threadsMinimal: return Color(red: 0.02, green: 0.02, blue: 0.03).opacity(0.90)
case .leicaBrushedBrass: return Color(red: 0.06, green: 0.05, blue: 0.04).opacity(0.90) }}; var cardBg: Color { switch self { case .sakuraMist: return Color(red: 0.25, green: 0.21, blue: 0.26).opacity(0.85)
case .threadsMinimal: return Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.88); case .leicaBrushedBrass: return Color(red: 0.18, green: 0.14, blue: 0.10).opacity(0.88) }}}
struct FlashCalculator { static let apertureSteps: [Double] = [1.0, 1.2, 1.4, 1.8, 2.0, 2.8, 3.5, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0]
static let shutterSteps: [Int] = [-15, -8, -4, -2, 1, 2, 4, 8, 15, 30, 50, 60, 90, 100, 125, 200, 250, 500, 1000, 2000, 4000]
static func formatShutter(_ s: Int) -> String { s < 0 ? "\(-s)\"" : (s == 1 ? "1\"" : "1/\(s)s") }
static let distanceSteps: [Double] = [0.5, 0.7, 1.0, 1.2, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 7.0, 10.0, 15.0]
static let isoSteps: [Double] = [50, 64, 100, 125, 160, 200, 250, 320, 400, 500, 800, 1600, 3200]
static let evCompSteps: [Double] = [-2.0, -1.7, -1.3, -1.0, -0.7, -0.3, 0.0, 0.3, 0.7, 1.0, 1.3, 1.7, 2.0]
static func closeUpBellowsLoss(distance: Double, formatRaw: Int) -> Double { switch formatRaw { case 1: return distance < 1.2 ? (0.50 * (1.2 - distance)) : 0.0
case 2: return distance < 1.2 ? (0.60 * (1.2 - distance)) : 0.0; case 3, 4: return distance < 1.3 ? (0.75 * (1.3 - distance)) : 0.0
default: return distance < 1.0 ? (0.35 * (1.0 - distance)) : 0.0 }}
static func powerComponents(gnAt100: Double, iso: Double, distance: Double, aperture: Double, shutter: Int, maxSync: Int, lossEV: Double, formatRaw: Int = 0, syncModeRaw: Int = 0) -> (mainFraction: String, trimBadge: String?, statusNote: String, isWarning: Bool) { let isoFactor = sqrt(max(iso, 25.0) / 100.0); let closeUpLoss = closeUpBellowsLoss(distance: distance, formatRaw: formatRaw); let effMaxSync = syncModeRaw == 1 ? max(maxSync, 500) : maxSync; let isOverSync = shutter > effMaxSync; let hssStops = (syncModeRaw == 2 && isOverSync) ? log2(Double(shutter) / Double(max(effMaxSync, 30))) : 0.0; let hssLoss = hssStops > 0 ? (1.5 + 1.0 * hssStops) : 0.0; let effectiveGN = gnAt100 * isoFactor * pow(2.0, -(lossEV + closeUpLoss + hssLoss) / 2.0); let fullPowerAperture = effectiveGN / max(distance, 0.3); let ratio = aperture / max(fullPowerAperture, 0.1); let power = ratio * ratio
if syncModeRaw == 0 && isOverSync { return ("帘幕黑边!", "≤1/\(effMaxSync)s", "🚨 机械幕帘遮挡! 请降至 ≤1/\(effMaxSync)s 或换LS镜间镜头", true) }
if power > 1.05 { return ("OVER", ">1/1", "欠曝·请开大光圈或靠近", true) }
if power < (1.0 / 256.0) { return ("LOW", "<1/128", "过曝·请收小光圈或后退", true) }
let stops = round(log2(1.0 / max(power, 0.001)) * 3.0) / 3.0; let whole = max(0, min(7, Int(round(stops)))); let trimEV = Double(whole) - stops; let denom = 1 << whole; let fracStr = denom == 1 ? "1/1" : "1/\(denom)"; let syncTag = syncModeRaw == 1 ? (isOverSync ? "超出镜间上限" : "LS镜间全同步") : (isOverSync ? "HSS高速同步" : "安全同步"); if abs(trimEV) < 0.14 { return (fracStr, nil, "整档输出 · \(syncTag)", isOverSync) }
return (fracStr, String(format: "%+.1fEV", trimEV), "1/3档微调 · \(syncTag)", isOverSync) }
static func formatFStop(_ val: Double) -> String { if abs(val - round(val)) < 0.05 { return String(format: "f/%.0f", round(val)) }
return String(format: "f/%.1f", val) }}
struct WidgetSharedStore { static let udpPort: UInt16 = 49188
static let localBlobKey = "lf_widget_cached_v93"
static let discoveredGroups: [String] = { var groups: [String] = ["group.com.lumifilm.flashmeter"]
if let bid = Bundle.main.bundleIdentifier { var base = bid
if base.hasSuffix(".widget") { base = String(base.dropLast(7)) }
if base.hasSuffix(".LumiFilmWidget") { base = String(base.dropLast(15)) }
let g = "group.\(base)"; if !groups.contains(g) { groups.insert(g, at: 0) }}
let urls = [Bundle.main.bundleURL.appendingPathComponent("embedded.mobileprovision"), Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("embedded.mobileprovision")]
for u in urls { if let data = try? Data(contentsOf: u) { let text = String(decoding: data, as: UTF8.self)
if let regex = try? NSRegularExpression(pattern: "group\\.[A-Za-z0-9._-]+") { let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
for m in matches { if let r = Range(m.range, in: text) { let g = String(text[r])
if !groups.contains(g) { groups.insert(g, at: 0) }}}}}}
return groups
}()
private static func sendLoopbackUDP(_ message: String) -> Data? { let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
guard fd >= 0 else { return nil }
defer { close(fd) }
var tv = timeval(tv_sec: 0, tv_usec: 75_000)
setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
var addr = sockaddr_in(); addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); addr.sin_family = sa_family_t(AF_INET); addr.sin_port = udpPort.bigEndian; addr.sin_addr.s_addr = inet_addr("127.0.0.1")
let bytes = Array(message.utf8); let sent = withUnsafePointer(to: &addr) { ptr -> Int in ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in sendto(fd, bytes, bytes.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size)) }}
guard sent > 0 else { return nil }
var buf = [UInt8](repeating: 0, count: 2048); let n = recv(fd, &buf, buf.count, 0)
guard n > 0 else { return nil }
return Data(buf[0..<n]) }
static func loadSharedDict() -> [String: Double] { var best: [String: Double] = [:]
var bestTS: Double = -1.0
func check(_ d: [String: Double]?) { guard let d = d, !d.isEmpty else { return }
let ts = d["lf_sync_ts"] ?? 0.0; if ts >= bestTS { bestTS = ts
best = d }}
if let udpData = sendLoopbackUDP("GET"), let udpDict = try? JSONDecoder().decode([String: Double].self, from: udpData) { check(udpDict)
UserDefaults.standard.set(udpData, forKey: localBlobKey) }
for gid in discoveredGroups { if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: gid)?.appendingPathComponent("lumifilm_v93.json"), let d = try? Data(contentsOf: url), let dec = try? JSONDecoder().decode([String: Double].self, from: d) { check(dec) }
if let suite = UserDefaults(suiteName: gid), let d = suite.data(forKey: localBlobKey), let dec = try? JSONDecoder().decode([String: Double].self, from: d) { check(dec) }}
if let localData = UserDefaults.standard.data(forKey: localBlobKey), let localDict = try? JSONDecoder().decode([String: Double].self, from: localData) { check(localDict) }
return best }
static func saveSharedDict(_ dict: [String: Double]) { var mutable = dict
mutable["lf_sync_ts"] = Date().timeIntervalSince1970
guard let data = try? JSONEncoder().encode(mutable), let jsonStr = String(data: data, encoding: .utf8) else { return }
UserDefaults.standard.set(data, forKey: localBlobKey)
for gid in discoveredGroups { UserDefaults(suiteName: gid)?.set(data, forKey: localBlobKey)
if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: gid)?.appendingPathComponent("lumifilm_v93.json") { try? data.write(to: url, options: .atomic) }}
_ = sendLoopbackUDP("SET:" + jsonStr) }
static func double(forKey key: String, default defVal: Double) -> Double { let dict = loadSharedDict(); return dict[key] ?? defVal }
static func setDouble(_ val: Double, forKey key: String) { var dict = loadSharedDict()
if dict.isEmpty { dict = ["lf_iso": 400.0, "lf_gn": 36.0, "lf_distance": 2.0, "lf_aperture": 4.0, "lf_shutter": 125.0, "lf_sync_speed": 125.0, "lf_theme": 2.0, "lf_max_aperture": 1.4, "lf_exp_comp_ev": 0.0, "lf_aux_loss": 0.0] }
dict[key] = val
saveSharedDict(dict) }}
@available(iOS 17.0, *)
struct LumiFilmWidgetAdjustIntent: AppIntent { static var title: LocalizedStringResource = "Adjust Flash Parameter"
@Parameter(title: "Command") var command: String
init() { self.command = "ap+" }
init(command: String) { self.command = command }
func perform() async throws -> some IntentResult { switch command { case "ap-", "ap+": let delta = command == "ap+" ? 1 : -1
let cur = WidgetSharedStore.double(forKey: "lf_aperture", default: 4.0); let maxOpen = WidgetSharedStore.double(forKey: "lf_max_aperture", default: 1.4); let steps = FlashCalculator.apertureSteps.filter { $0 >= maxOpen - 0.01 }
if let idx = steps.enumerated().min(by: { abs($0.element - cur) < abs($1.element - cur) })?.offset { let nextIdx = max(0, min(steps.count - 1, idx + delta))
WidgetSharedStore.setDouble(steps[nextIdx], forKey: "lf_aperture") }
case "sh-", "sh+": let delta = command == "sh+" ? 1 : -1; let cur = Int(round(WidgetSharedStore.double(forKey: "lf_shutter", default: 125.0))); let steps = FlashCalculator.shutterSteps
if let idx = steps.enumerated().min(by: { abs($0.element - cur) < abs($1.element - cur) })?.offset { let nextIdx = max(0, min(steps.count - 1, idx + delta))
WidgetSharedStore.setDouble(Double(steps[nextIdx]), forKey: "lf_shutter") }
case "dist-", "dist+": let delta = command == "dist+" ? 1 : -1; let cur = WidgetSharedStore.double(forKey: "lf_distance", default: 2.0); let steps = FlashCalculator.distanceSteps
if let idx = steps.enumerated().min(by: { abs($0.element - cur) < abs($1.element - cur) })?.offset { let nextIdx = max(0, min(steps.count - 1, idx + delta))
WidgetSharedStore.setDouble(steps[nextIdx], forKey: "lf_distance") }
case "ev-", "ev+": let delta = command == "ev+" ? 1 : -1; let cur = WidgetSharedStore.double(forKey: "lf_exp_comp_ev", default: 0.0); let steps = FlashCalculator.evCompSteps
if let idx = steps.enumerated().min(by: { abs($0.element - cur) < abs($1.element - cur) })?.offset { let nextIdx = max(0, min(steps.count - 1, idx + delta))
WidgetSharedStore.setDouble(steps[nextIdx], forKey: "lf_exp_comp_ev") }
case "iso-", "iso+": let delta = command == "iso+" ? 1 : -1; let cur = WidgetSharedStore.double(forKey: "lf_iso", default: 400.0); let steps = FlashCalculator.isoSteps
if let idx = steps.enumerated().min(by: { abs($0.element - cur) < abs($1.element - cur) })?.offset { let nextIdx = max(0, min(steps.count - 1, idx + delta))
WidgetSharedStore.setDouble(steps[nextIdx], forKey: "lf_iso") }
case "theme": let cur = Int(round(WidgetSharedStore.double(forKey: "lf_theme", default: 2.0)))
WidgetSharedStore.setDouble(Double((cur + 1) % 3), forKey: "lf_theme")
default: break }
WidgetCenter.shared.reloadAllTimelines()
return .result() }}
struct LumiFilmEntry: TimelineEntry { let date: Date; let iso: Double; let gn: Double; let distance: Double; let aperture: Double; let shutterDenom: Int; let maxSyncSpeed: Int; let evComp: Double; let themeRaw: Int; let mainPower: String; let trimBadge: String?; let noteText: String; let isWarning: Bool
var theme: WidgetTheme { WidgetTheme(rawValue: themeRaw) ?? .leicaBrushedBrass }; var powerFullText: String { if let trim = trimBadge { return "\(mainPower) \(trim)" }; return mainPower }
private var querySuffix: String { String(format: "ap=%.1f&dist=%.1f&ev=%.1f&iso=%.0f&gn=%.0f&shutter=%d&theme=%d", aperture, distance, evComp, iso, gn, shutterDenom, themeRaw) }
var voiceDeepLinkURL: URL { URL(string: "lumifilm://voice?\(querySuffix)") ?? URL(string: "lumifilm://voice")! }; var speakDeepLinkURL: URL { URL(string: "lumifilm://speak?\(querySuffix)") ?? URL(string: "lumifilm://speak")! }
var onboardingDeepLinkURL: URL { URL(string: "lumifilm://onboarding?\(querySuffix)") ?? URL(string: "lumifilm://onboarding")! }; var meterDeepLinkURL: URL { URL(string: "lumifilm://meter?\(querySuffix)") ?? URL(string: "lumifilm://meter")! }}
struct LumiFilmProvider: TimelineProvider { func placeholder(in context: Context) -> LumiFilmEntry { LumiFilmEntry(date: Date(), iso: 400, gn: 36, distance: 2.0, aperture: 4.0, shutterDenom: 125, maxSyncSpeed: 125, evComp: 0.0, themeRaw: 2, mainPower: "1/16", trimBadge: "+0.3EV", noteText: "1/3档微调 · 安全同步", isWarning: false) }
func getSnapshot(in context: Context, completion: @escaping (LumiFilmEntry) -> Void) { completion(loadEntry()) }
func getTimeline(in context: Context, completion: @escaping (Timeline<LumiFilmEntry>) -> Void) { let entry = loadEntry()
completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))) }
private func loadEntry() -> LumiFilmEntry { let dict = WidgetSharedStore.loadSharedDict(); let iso = dict["lf_iso"] ?? 400.0; let gn = dict["lf_gn"] ?? 36.0; let dist = dict["lf_distance"] ?? 2.0; let ap = dict["lf_aperture"] ?? 4.0; let shutter = max(1, Int(round(dict["lf_shutter"] ?? 125.0))); let maxSync = max(30, Int(round(dict["lf_sync_speed"] ?? 125.0))); let evComp = dict["lf_exp_comp_ev"] ?? 0.0; let themeRaw = Int(round(dict["lf_theme"] ?? 2.0)); let auxLoss = dict["lf_aux_loss"] ?? 0.0; let fmtRaw = Int(round(dict["lf_film_format"] ?? 0.0)); let syncModeRaw = Int(round(dict["lf_sync_mode"] ?? 0.0)); let totalLoss = auxLoss + evComp; let res = FlashCalculator.powerComponents(gnAt100: gn, iso: iso, distance: dist, aperture: ap, shutter: shutter, maxSync: maxSync, lossEV: totalLoss, formatRaw: fmtRaw, syncModeRaw: syncModeRaw)
return LumiFilmEntry(date: Date(), iso: iso, gn: gn, distance: dist, aperture: ap, shutterDenom: shutter, maxSyncSpeed: maxSync, evComp: evComp, themeRaw: themeRaw, mainPower: res.0, trimBadge: res.1, noteText: res.2, isWarning: res.3) }}
struct LumiFilmWidgetEntryView: View { var entry: LumiFilmProvider.Entry
@Environment(\.widgetFamily) private var family
private var t: WidgetTheme { entry.theme }
var body: some View { Group { switch family { case .systemMedium: mediumWidgetView; case .systemLarge: largeWidgetView; case .accessoryRectangular: lockScreenRectangularView
default: smallWidgetView }} .widgetURL(entry.meterDeepLinkURL).containerBackground(for: .widget) { LinearGradient(colors: t.backgroundGradient, startPoint: .topLeading, endPoint: .bottomTrailing) }}
private func powerBadgeRow(mainSize: CGFloat, badgeSize: CGFloat) -> some View { HStack(alignment: .center, spacing: 5) { Text(entry.mainPower).font(.system(size: mainSize, weight: .black, design: .rounded)).foregroundStyle(entry.isWarning ? Color.orange : Color.white).minimumScaleFactor(0.65).lineLimit(1)
if let trim = entry.trimBadge { Text(trim).font(.system(size: badgeSize, weight: .heavy, design: .monospaced)).foregroundStyle(Color.black).padding(.horizontal, 6).padding(.vertical, 2).background(t.accent, in: Capsule()) } else { Text("整档").font(.system(size: badgeSize - 0.5, weight: .bold, design: .rounded)).foregroundStyle(t.accent).padding(.horizontal, 5.5).padding(.vertical, 2).background(t.accent.opacity(0.18), in: Capsule()) }}}
private func cameraVoiceKeyButton(height: CGFloat, title: String) -> some View { Link(destination: entry.voiceDeepLinkURL) { HStack(spacing: 5) { Circle().fill(Color.black.opacity(0.28)).frame(width: height - 10, height: height - 10).overlay(
Image(systemName: "mic.fill").font(.system(size: height * 0.36, weight: .black)).foregroundStyle(Color.black) )
Text(title).font(.system(size: height * 0.36, weight: .black, design: .rounded)).foregroundStyle(Color.black).lineLimit(1) } .frame(maxWidth: .infinity).frame(height: height).background(t.accent, in: Capsule()).overlay(Capsule().stroke(Color.white.opacity(0.55), lineWidth: 1)) }}
private var smallWidgetView: some View { VStack(alignment: .leading, spacing: 6) { VStack(alignment: .leading, spacing: 4) { HStack(spacing: 4) { Image(systemName: "bolt.circle.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(t.accent)
Text("输出功率").font(.system(size: 9.5, weight: .bold, design: .monospaced)).foregroundStyle(t.accent)
Spacer(minLength: 0)
Text(t.nameText).font(.system(size: 8.5, weight: .bold)).foregroundStyle(t.accent.opacity(0.85)) }
powerBadgeRow(mainSize: 28, badgeSize: 9.5)
HStack(spacing: 5) { Text("ISO \(Int(entry.iso))")
Text("·")
Text("1/\(entry.shutterDenom)s")
Text("·")
Text(String(format: "%.1fm", entry.distance)) } .font(.system(size: 9.5, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.75)
Text("光圈 \(FlashCalculator.formatFStop(entry.aperture)) · GN\(Int(entry.gn))").font(.system(size: 8.5, weight: .semibold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.58)).lineLimit(1) } .padding(.horizontal, 9).padding(.vertical, 7).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).background(t.lcdBg, in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(t.accent.opacity(0.45), lineWidth: 1))
cameraVoiceKeyButton(height: 30, title: "语音输入") } .foregroundStyle(Color.white) }
private var mediumWidgetView: some View { HStack(spacing: 10) { VStack(alignment: .leading, spacing: 6) { VStack(alignment: .leading, spacing: 3) { HStack(spacing: 4) { Image(systemName: "bolt.circle.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(t.accent)
Text("闪光输出功率").font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(t.accent)
Spacer(minLength: 0)
Text(t.nameText).font(.system(size: 8.5, weight: .bold)).foregroundStyle(t.accent.opacity(0.85)) }
powerBadgeRow(mainSize: 34, badgeSize: 10.5)
Text(entry.noteText).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.65)).lineLimit(1) } .padding(.horizontal, 10).padding(.vertical, 8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).background(t.lcdBg, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(t.accent.opacity(0.45), lineWidth: 1))
cameraVoiceKeyButton(height: 32, title: "语音输入") } .frame(maxWidth: .infinity)
VStack(spacing: 6) { HStack(spacing: 6) { readOnlyInfoCell(label: "感光度 ISO", value: "ISO \(Int(entry.iso))", highlight: t.accent)
readOnlyInfoCell(label: "快门速度", value: "1/\(entry.shutterDenom)s", highlight: Color.white) }
HStack(spacing: 6) { readOnlyInfoCell(label: "拍摄距离", value: String(format: "%.1f m", entry.distance), highlight: t.secondaryAccent)
readOnlyInfoCell(label: "当前光圈", value: FlashCalculator.formatFStop(entry.aperture), highlight: t.accent) }
HStack(spacing: 4) { Text("GN \(Int(entry.gn))")
Text("·")
Text(abs(entry.evComp) < 0.05 ? "补偿 0.0EV" : String(format: "补偿 %+.1fEV", entry.evComp)) } .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.62)).frame(maxWidth: .infinity).padding(.vertical, 4).background(t.cardBg, in: RoundedRectangle(cornerRadius: 8)) } .frame(width: 152) } .foregroundStyle(Color.white) }
private func readOnlyInfoCell(label: String, value: String, highlight: Color) -> some View { VStack(alignment: .leading, spacing: 2) { Text(label).font(.system(size: 8.5, weight: .bold)).foregroundStyle(Color.white.opacity(0.55)).lineLimit(1)
Text(value).font(.system(size: 12.5, weight: .black, design: .monospaced)).foregroundStyle(highlight).lineLimit(1).minimumScaleFactor(0.75) } .padding(.horizontal, 8).padding(.vertical, 6).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).background(t.cardBg, in: RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).stroke(t.accent.opacity(0.28), lineWidth: 0.8)) }
private var largeWidgetView: some View { VStack(spacing: 7) { VStack(alignment: .leading, spacing: 4) { HStack(spacing: 5) { Image(systemName: "camera.aperture").font(.system(size: 12, weight: .bold)).foregroundStyle(t.accent)
Text("LUMIFILM 机顶测光屏 · 输出功率").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(t.accent)
Spacer(minLength: 0)
if #available(iOSApplicationExtension 17.0, *) { Button(intent: LumiFilmWidgetAdjustIntent(command: "theme")) { HStack(spacing: 3) { Circle().fill(t.accent).frame(width: 5, height: 5)
Text(t.nameText).font(.system(size: 9, weight: .bold)).foregroundStyle(Color.white.opacity(0.9)) } .padding(.horizontal, 7).padding(.vertical, 2.5).background(t.cardBg, in: Capsule()).overlay(Capsule().stroke(t.accent.opacity(0.45), lineWidth: 0.8)) } .buttonStyle(.plain) }}
HStack(alignment: .center) { powerBadgeRow(mainSize: 36, badgeSize: 11.5)
Spacer(minLength: 6)
VStack(alignment: .trailing, spacing: 2) { Text(entry.noteText).font(.system(size: 9.5, weight: .bold, design: .monospaced)).foregroundStyle(entry.isWarning ? Color.orange : t.accent)
Text("X-Sync ≤1/\(entry.maxSyncSpeed)s · GN\(Int(entry.gn))").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.6)) }}
Text("当前参数: \(FlashCalculator.formatFStop(entry.aperture)) · 1/\(entry.shutterDenom)s · \(String(format: "%.1fm", entry.distance)) · ISO \(Int(entry.iso))").font(.system(size: 9.5, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.85)).lineLimit(1) } .padding(.horizontal, 11).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading).background(t.lcdBg, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(t.accent.opacity(0.5), lineWidth: 1))
if #available(iOSApplicationExtension 17.0, *) { HStack(spacing: 7) { largeStepperCard(
title: "光圈 APERTURE", value: FlashCalculator.formatFStop(entry.aperture), color: t.accent, decCmd: "ap-", incCmd: "ap+" )
largeStepperCard(
title: "快门速度 SHUTTER", value: "1/\(entry.shutterDenom)s", color: entry.shutterDenom > entry.maxSyncSpeed ? Color.orange : Color.white, decCmd: "sh-", incCmd: "sh+" ) }
HStack(spacing: 7) { largeStepperCard(
title: "拍摄距离 DISTANCE", value: String(format: "%.1f m", entry.distance), color: t.secondaryAccent, decCmd: "dist-", incCmd: "dist+" )
largeStepperCard(
title: "曝光补偿 EV COMP", value: abs(entry.evComp) < 0.05 ? "0.0 EV" : String(format: "%+.1f EV", entry.evComp), color: Color.green, decCmd: "ev-", incCmd: "ev+" ) }
HStack(spacing: 8) { Text("感光度 ISO").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.75))
Spacer(minLength: 4)
Button(intent: LumiFilmWidgetAdjustIntent(command: "iso-")) { Text("−").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(Color.white).frame(width: 30, height: 25).background(t.lcdBg, in: RoundedRectangle(cornerRadius: 7)) } .buttonStyle(.plain)
Text("ISO \(Int(entry.iso))").font(.system(size: 12.5, weight: .black, design: .monospaced)).foregroundStyle(t.accent).frame(minWidth: 66)
Button(intent: LumiFilmWidgetAdjustIntent(command: "iso+")) { Text("+").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(Color.white).frame(width: 30, height: 25).background(t.lcdBg, in: RoundedRectangle(cornerRadius: 7)) } .buttonStyle(.plain) } .padding(.horizontal, 10).padding(.vertical, 5).background(t.cardBg, in: RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).stroke(t.accent.opacity(0.32), lineWidth: 0.8)) }
HStack(spacing: 6) { cameraVoiceKeyButton(height: 31, title: "语音输入")
Link(destination: entry.speakDeepLinkURL) { HStack(spacing: 4) { Image(systemName: "speaker.wave.2.fill").font(.system(size: 10.5, weight: .bold)).foregroundStyle(t.accent)
Text("播报功率").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.white) } .frame(maxWidth: .infinity).frame(height: 31).background(t.cardBg, in: Capsule()).overlay(Capsule().stroke(t.accent.opacity(0.45), lineWidth: 0.9)) }
Link(destination: entry.onboardingDeepLinkURL) { HStack(spacing: 4) { Image(systemName: "slider.horizontal.3").font(.system(size: 10.5, weight: .bold)).foregroundStyle(t.accent)
Text("首次指引").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.white) } .frame(maxWidth: .infinity).frame(height: 31).background(t.cardBg, in: Capsule()).overlay(Capsule().stroke(t.accent.opacity(0.45), lineWidth: 0.9)) }}} .foregroundStyle(Color.white) }
@available(iOSApplicationExtension 17.0, *)
private func largeStepperCard(title: String, value: String, color: Color, decCmd: String, incCmd: String) -> some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 8.5, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.6)).lineLimit(1)
HStack(spacing: 0) { Button(intent: LumiFilmWidgetAdjustIntent(command: decCmd)) { Text("−").font(.system(size: 15, weight: .black, design: .monospaced)).foregroundStyle(Color.white).frame(width: 30, height: 28).background(t.lcdBg, in: RoundedRectangle(cornerRadius: 8)) } .buttonStyle(.plain)
Spacer(minLength: 2)
Text(value).font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.75)
Spacer(minLength: 2)
Button(intent: LumiFilmWidgetAdjustIntent(command: incCmd)) { Text("+").font(.system(size: 15, weight: .black, design: .monospaced)).foregroundStyle(Color.white).frame(width: 30, height: 28).background(t.lcdBg, in: RoundedRectangle(cornerRadius: 8)) } .buttonStyle(.plain) }} .padding(.horizontal, 8).padding(.vertical, 6).frame(maxWidth: .infinity).background(t.cardBg, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(t.accent.opacity(0.35), lineWidth: 0.9)) }
private var lockScreenRectangularView: some View { VStack(alignment: .leading, spacing: 2) { HStack(spacing: 4) { Image(systemName: "bolt.fill")
Text("FLASH: \(entry.powerFullText)").font(.system(size: 13, weight: .black, design: .rounded)) }
Text(String(format: "f/%.1f · 1/%ds · %.1fm · ISO %.0f", entry.aperture, entry.shutterDenom, entry.distance, entry.iso)).font(.system(size: 10, weight: .semibold, design: .monospaced)).opacity(0.85) }}}
@main
struct LumiFilmWidget: Widget { let kind: String = "LumiFilmCameraWidgetV9"
var body: some WidgetConfiguration { StaticConfiguration(kind: kind, provider: LumiFilmProvider()) { entry in LumiFilmWidgetEntryView(entry: entry) }.configurationDisplayName("LumiFilm 闪光测光组件").description("主题与主App实时互通。小号/中号只读显示输出功率、ISO、快门、距离与语音输入键；大号(4x4)支持桌面直接调参。").supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular]) }}
