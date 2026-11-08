import SwiftUI
extension View { func fMono(_ s: CGFloat, _ w: Font.Weight = .bold) -> some View { self.font(.system(size: s, weight: w, design: .monospaced)) }
func fSys(_ s: CGFloat, _ w: Font.Weight = .bold) -> some View { self.font(.system(size: s, weight: w)) }}
import AVFoundation; import CoreMedia; import AudioToolbox; import UIKit; import WidgetKit; import Speech; import AppIntents; import CoreLocation; import Darwin
final class LocalLoopbackSyncBridge { static let shared = LocalLoopbackSyncBridge()
private let lock = NSLock()
private var currentPayload: Data = Data()
private var isRunning = false
private var bgTask: UIBackgroundTaskIdentifier = .invalid
let discoveredGroups: [String] = { var groups: [String] = ["group.com.lumifilm.flashmeter"]
if let bid = Bundle.main.bundleIdentifier { let g = "group.\(bid)"
if !groups.contains(g) { groups.insert(g, at: 0) }}
let u = Bundle.main.bundleURL.appendingPathComponent("embedded.mobileprovision")
if let data = try? Data(contentsOf: u) { let text = String(decoding: data, as: UTF8.self)
if let regex = try? NSRegularExpression(pattern: "group\\.[A-Za-z0-9._-]+") { for m in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) { if let r = Range(m.range, in: text) { let g = String(text[r])
if !groups.contains(g) { groups.insert(g, at: 0) }}}}}
return groups
}()
func startServerIfNeeded() { lock.lock()
if isRunning { lock.unlock(); return }
isRunning = true
lock.unlock()
DispatchQueue.global(qos: .userInteractive).async { [weak self] in
let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
guard fd >= 0 else { return }
var yes: Int32 = 1
setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
var addr = sockaddr_in()
addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
addr.sin_family = sa_family_t(AF_INET)
addr.sin_port = UInt16(49188).bigEndian
addr.sin_addr.s_addr = inet_addr("127.0.0.1")
let b = withUnsafePointer(to: &addr) { ptr -> Int32 in
ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
bind(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size)) }}
guard b == 0 else { close(fd); return }
var buf = [UInt8](repeating: 0, count: 2048)
while true { var cAddr = sockaddr_in()
var cLen = socklen_t(MemoryLayout<sockaddr_in>.size); let n = withUnsafeMutablePointer(to: &cAddr) { ptr -> Int in
ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
recvfrom(fd, &buf, buf.count, 0, sa, &cLen) }}
if n > 0, let self = self { let req = String(decoding: buf[0..<n], as: UTF8.self)
if req.hasPrefix("GET") { self.lock.lock()
let reply = self.currentPayload; self.lock.unlock()
if !reply.isEmpty { reply.withUnsafeBytes { rawBuf in
if let basePtr = rawBuf.baseAddress { _ = withUnsafePointer(to: &cAddr) { ptr in
ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
sendto(fd, basePtr, reply.count, 0, sa, cLen) }}}}}
} else if req.hasPrefix("SET:") { let jsonPart = String(req.dropFirst(4))
if let d = jsonPart.data(using: .utf8), let dict = try? JSONDecoder().decode([String: Double].self, from: d) { self.lock.lock()
self.currentPayload = d
self.lock.unlock()
let ack = Array("OK".utf8)
_ = withUnsafePointer(to: &cAddr) { ptr in
ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
sendto(fd, ack, ack.count, 0, sa, cLen) }}
DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name("LumiFilmWidgetRemoteSet"), object: nil, userInfo: dict) }}}}}}}
func publishState(_ dict: [String: Double]) { startServerIfNeeded()
guard let data = try? JSONEncoder().encode(dict) else { return }
lock.lock()
currentPayload = data
lock.unlock()
UserDefaults.standard.set(data, forKey: "lf_widget_cached_v93")
for gid in discoveredGroups { UserDefaults(suiteName: gid)?.set(data, forKey: "lf_widget_cached_v93")
if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: gid)?.appendingPathComponent("lumifilm_v93.json") { try? data.write(to: url, options: .atomic) }}
keepAliveBrieflyForWidgetReload()
WidgetCenter.shared.reloadAllTimelines()
DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { WidgetCenter.shared.reloadAllTimelines() }}
func keepAliveBrieflyForWidgetReload() { let app = UIApplication.shared
if bgTask != .invalid { app.endBackgroundTask(bgTask)
bgTask = .invalid }
bgTask = app.beginBackgroundTask(withName: "LumiFilmWidgetUDP") { [weak self] in
if let self = self, self.bgTask != .invalid { app.endBackgroundTask(self.bgTask)
self.bgTask = .invalid }}
DispatchQueue.main.asyncAfter(deadline: .now() + 25.0) { [weak self] in
guard let self = self, self.bgTask != .invalid else { return }
app.endBackgroundTask(self.bgTask)
self.bgTask = .invalid }}}
final class LocationAddressResolver: NSObject, ObservableObject, CLLocationManagerDelegate { static let shared = LocationAddressResolver()
private let manager = CLLocationManager()
private let geocoder = CLGeocoder()
@Published var isLocating: Bool = false
private var onResolved: ((String) -> Void)?
override init() { super.init()
manager.delegate = self
manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }
func fetchCurrentPlace(completion: @escaping (String) -> Void) { onResolved = completion
isLocating = true
let status = manager.authorizationStatus
if status == .notDetermined { manager.requestWhenInUseAuthorization() } else if status == .authorizedWhenInUse || status == .authorizedAlways { manager.requestLocation() } else { isLocating = false }}
func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
if isLocating && (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways) { manager.requestLocation() }}
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { guard let loc = locations.last else { isLocating = false; return }
geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
DispatchQueue.main.async { self?.isLocating = false
if let p = placemarks?.first { let parts = [p.locality, p.subLocality, p.thoroughfare ?? p.name].compactMap { $0 }; var unique: [String] = []
for item in parts { if !unique.contains(item) { unique.append(item) }}
let text = unique.joined(separator: " · ")
if !text.isEmpty { self?.onResolved?(text) }}}}}
func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { DispatchQueue.main.async { self.isLocating = false }}}
enum FilmFormatType: Int, CaseIterable, Identifiable { case f135 = 0
case f120_645 = 1; case f120_6x6 = 2; case f120_6x7 = 3; case f120_6x9 = 4; var id: Int { rawValue }; var maxFrames: Int { switch self { case .f135: return 36
case .f120_645: return 16; case .f120_6x6: return 12; case .f120_6x7: return 10; case .f120_6x9: return 8 }}
var shortTag: String { switch self { case .f135: return "135"; case .f120_645: return "120·645"; case .f120_6x6: return "120·6x6"; case .f120_6x7: return "120·6x7"; case .f120_6x9: return "120·6x9" }}
func pillTitle(for lang: AppLanguage) -> String { switch self { case .f135: return lang == .en ? "135 (36)" : "135 (36张)"
case .f120_645: return lang == .en ? "645 (16)" : "645 (16张)"; case .f120_6x6: return lang == .en ? "6x6 (12)" : "6x6 (12张)"
case .f120_6x7: return lang == .en ? "6x7 (10)" : "6x7 (10张)"; case .f120_6x9: return lang == .en ? "6x9 (8)" : "6x9 (8张)" }}
func bellowsHint(for lang: AppLanguage) -> String { switch self { case .f135: return lang == .en ? "135 Full-Frame (36 exp) · Std <1.0m Close-up" : "135 全画幅 (36张/卷) · 标准 <1.0m 近摄补偿"
case .f120_645: return lang == .en ? "120 645 (16 exp) · 80mm≈50mm · <1.2m Bellows Comp" : "120 645 (16张) · 80mm等效50mm · 自动 <1.2m 近摄皮腔补偿"
case .f120_6x6: return lang == .en ? "120 6x6 (12 exp) · 80mm≈44mm · <1.2m Bellows Comp" : "120 6x6 (12张) · 80mm等效44mm · 哈苏/禄来 <1.2m 皮腔补偿"
case .f120_6x7: return lang == .en ? "120 6x7 (10 exp) · 105mm≈50mm · <1.3m Bellows Comp" : "120 6x7 (10张) · 105mm等效50mm · 宾得67/RB67 <1.3m 皮腔补偿"
case .f120_6x9: return lang == .en ? "120 6x9 (8 exp) · 90mm≈39mm · <1.3m Bellows Comp" : "120 6x9 (8张) · 90mm等效39mm · 富士690 <1.3m 皮腔补偿" }}
func closeUpLoss(at distance: Double) -> Double { switch self { case .f135: return distance < 1.0 ? (0.35 * (1.0 - distance)) : 0.0
case .f120_645: return distance < 1.2 ? (0.50 * (1.2 - distance)) : 0.0; case .f120_6x6: return distance < 1.2 ? (0.60 * (1.2 - distance)) : 0.0
case .f120_6x7, .f120_6x9: return distance < 1.3 ? (0.75 * (1.3 - distance)) : 0.0 }}}
enum ShutterSyncMode: Int, CaseIterable, Identifiable { case focalPlaneMechanical = 0
case leafShutterLens = 1; case hssElectronic = 2; var id: Int { rawValue }
func shortBadge(for lang: AppLanguage, bodySync: Int) -> String { switch self { case .focalPlaneMechanical: return lang == .en ? "Focal ≤1/\(bodySync)s" : "机身幕帘 ≤1/\(bodySync)s"
case .leafShutterLens: return lang == .en ? "LS Leaf 1/500s" : "LS镜间 1/500s"; case .hssElectronic: return lang == .en ? "HSS Auto Loss" : "HSS 高速折损" }}
func title(for lang: AppLanguage) -> String { switch self { case .focalPlaneMechanical: return lang == .en ? "Focal-Plane Curtain (Blackout > X-Sync)" : "焦平面机身幕帘 (超速半幅黑边拦截)"
case .leafShutterLens: return lang == .en ? "Leaf Shutter / LS Lens (All-Speed ≤1/500s)" : "镜间快门机身 / LS镜头 (1/500s 全速同步)"
case .hssElectronic: return lang == .en ? "Electronic HSS (High-Speed Sync Loss)" : "现代电子 HSS 高速同步 (自动扣光损)" }}}
enum CameraShutterPreset: String, CaseIterable, Identifiable { case pentax67 = "pentax67"
case leicaM = "leica_m"; case classicSLR60 = "slr_60"; case verticalSLR125 = "slr_125"; case proSLR250 = "slr_250"
case mediumLeaf500 = "mf_leaf_500"; case mamiyaRB67 = "mamiya_rb_rz"; case compactLeaf135 = "compact_leaf"
var id: String { rawValue }; var defaultSync: Int { switch self { case .pentax67: return 30; case .leicaM: return 50
case .classicSLR60: return 60; case .verticalSLR125: return 125; case .proSLR250: return 250; case .mediumLeaf500: return 500
case .mamiyaRB67: return 400; case .compactLeaf135: return 500 }}; var defaultMode: ShutterSyncMode { switch self { case .mediumLeaf500, .mamiyaRB67, .compactLeaf135: return .leafShutterLens
default: return .focalPlaneMechanical }}
var suggestedFormat: FilmFormatType? { switch self { case .pentax67, .mamiyaRB67: return .f120_6x7
case .mediumLeaf500: return .f120_6x6; case .leicaM, .classicSLR60, .verticalSLR125, .proSLR250, .compactLeaf135: return .f135 }}
func title(for lang: AppLanguage) -> String { switch self { case .pentax67: return lang == .en ? "Pentax 67 / 67II (1/30s + LS 1/500s)" : "Pentax 67 / 67II (机身1/30s · 支持LS镜间镜头)"
case .leicaM: return lang == .en ? "Leica M2/M3/M4/M6/MP (1/50s Cloth)" : "Leica M2/M3/M4/M6/MP (1/50s 横走布帘)"
case .classicSLR60: return lang == .en ? "AE-1 / OM-1 / K1000 / M645 (1/60s)" : "AE-1 / OM-1 / K1000 / Mamiya 645 (1/60s)"
case .verticalSLR125: return lang == .en ? "Nikon F3 / FE / FM / Contax RTS (1/125s)" : "Nikon F3 / FM / FE / Contax S2 (≤1/125s)"
case .proSLR250: return lang == .en ? "Nikon FM2 / FE2 / FM3A / Contax G2 (1/250s)" : "Nikon FM2 / FE2 / FM3A / Contax G2 (≤1/250s)"
case .mediumLeaf500: return lang == .en ? "Hasselblad 500 / Rolleiflex / Mamiya 7 (1/500s)" : "哈苏500系 / 禄来双反 / Mamiya 7 / 富士690 (1/500s镜间)"
case .mamiyaRB67: return lang == .en ? "Mamiya RB67 / RZ67 Seiko Leaf (1/400s)" : "Mamiya RB67 / RZ67 (1/400s 镜间+皮腔对焦)"
case .compactLeaf135: return lang == .en ? "Contax T2/T3 / QL17 / Rollei 35 (1/500s Leaf)" : "Contax T2/T3 / 佳能QL17 / 禄来35 (1/500s镜间)" }}
func defectWarning(for lang: AppLanguage) -> String { switch self { case .pentax67: return lang == .en
? "⚠️ Hardware Trap: Pentax 67/67II huge horizontal cloth curtain only syncs at ≤1/30s! At 1/60s+ half the frame turns black. If mounting 90mm f/2.8 LS or 165mm f/4 LS Leaf-Shutter lenses, tap [LS Leaf 1/500s] in the top bar (set lens ring to 1/125–1/500s and body dial to 1/8s or X)."
: "⚠️ 机身缺陷必读：Pentax 67/67II 巨大横走布帘机身同步仅 ≤1/30s（1/60s 起必然半幅黑边）！若换装 90mm f/2.8 LS 或 165mm f/4 LS 镜间快门镜头，请点击顶部【LS镜间 1/500s】切换全速同步（镜头快门环设为 1/125~1/500s，机身转盘置于 1/8s 或 X 档）。"
case .leicaM: return lang == .en
? "⚠️ Hardware Trap: Leica M cloth focal-plane shutter syncs strictly at ⚡ 1/50s (between 1/30 & 1/60). Shooting at 1/60s clips the edge of the frame! M2/M3/M4 also have dual bulbs/⚡ PC sockets — plug electronic flash into ⚡ (X), NEVER the bulb socket."
: "⚠️ 机身缺陷必读：Leica M 横走布帘最高同步为 ⚡ 1/50s 专档！拨到 1/60s 会导致画面右侧边缘出现黑边遮挡。老款 M3/M2/M4 背部有两个 PC 孔，电子闪光灯必须插在闪电 ⚡ (X) 孔，误插灯泡孔会导致不闪或不同步。"
case .classicSLR60: return lang == .en
? "⚠️ Hardware Trap: 70s/80s horizontal cloth SLRs (Canon AE-1, Olympus OM-1, Pentax K1000, Minolta X-700) & Mamiya/Pentax 645 bodies max out at 1/60s! Exceeding 1/60s causes severe curtain shading (unless using a 645 LS leaf-shutter lens)."
: "⚠️ 机身缺陷必读：经典横走布帘单反（AE-1 / OM-1 / K1000 / X-700）及 Mamiya/Pentax 645 焦平面机身闪光同步上限仅 1/60s！户外逆光压光需配合低感胶卷、小光圈或 ND 滤镜（645 若换用 LS 镜间镜头可一键切至 1/500s）。"
case .verticalSLR125: return lang == .en
? "⚠️ Hardware Trap: Vertical metal focal-plane shutters (Nikon FM/FE 1/125s, Nikon F3 1/80s, Canon A-1) shade the top/bottom of the frame above their rated X-sync. On Nikon F3 you also need the AS-4/AS-17 coupler."
: "⚠️ 机身缺陷必读：纵走金属快门单反（Nikon FM/FE 1/125s、F3 仅 1/80s）超速会在画面上下产生黑边！注意 Nikon F3 机顶无标准热靴，需通过卷片轴转换座连接并控制在 ≤1/80s~1/125s。"
case .proSLR250: return lang == .en
? "⚠️ Hardware Trap: High-speed titanium honeycomb shutters (Nikon FM2/FE2/FM3A, Contax G2 1/200s) reach 1/200s–1/250s, but mechanical focal-plane shutters still CANNOT use digital HSS above 1/250s!"
: "⚠️ 机身缺陷必读：钛合金蜂巢/纵走高速快门（Nikon FM2/FE2/FM3A 1/250s、Contax G2 1/200s）虽支持较高同步，但仍不支持数码 HSS 频闪，快门超过 1/250s 同样会切出黑边。"
case .mediumLeaf500: return lang == .en
? "⚠️ Hardware Trap: Hasselblad C/CF & Rolleiflex leaf shutters sync up to 1/500s! CRITICAL: Keep the lens sync lever on [X] (NEVER [M] bulb delay, or the flash fires before the blades open -> blank frame), and NEVER switch V-lever to self-timer! At 1/500s wide open (f/2.8–f/4), leaf efficiency adds ~0.35 EV ambient loss."
: "⚠️ 镜间快门必读：哈苏 C/CF 镜头、禄来双反、Mamiya 7、富士 690 均采用镜间叶片快门，支持 1/500s 全速同步！切记将镜头同步拨杆锁在【X 档】（误拨 M 档会提前引闪导致全黑废片），且切勿误触 V 档自拍！1/500s 大光圈下叶片开合效率会自动计入约 -0.35 EV 环境光修正。"
case .mamiyaRB67: return lang == .en
? "⚠️ Hardware Trap: Mamiya RB67/RZ67 Seiko leaf shutters sync up to 1/400s across all speeds. Keep lens X/M selector on [X], and remember RB67 uses bellows rack focusing — LumiFilm automatically compensates close-up bellows light loss (<1.3m)."
: "⚠️ 机身缺陷必读：Mamiya RB67/RZ67 镜头内置精工镜间快门，支持 1/400s 全速同步（请确认镜头拨杆在 X 档）。此外 RB67/RZ67 采用皮腔伸展对焦，近摄时光损极大，LumiFilm 已在 <1.3m 自动叠加 6×7 皮腔补偿。"
case .compactLeaf135: return lang == .en
? "⚠️ Hardware Trap: 135 leaf-shutter rangefinders & compacts (Contax T2/T3, Canon QL17 GIII, Rollei 35) sync at all speeds up to 1/500s! Great for daylight fill-flash, though small built-in flashes (GN 9–14) only reach ~1.5–2.5m."
: "⚠️ 镜间旁轴必读：Contax T2/T3、佳能 QL17 GIII、禄来 35 等采用镜间叶片快门，支持 1/500s 全程闪光同步，非常适合白天逆光直闪压光！但需注意小体积机顶灯指数较小（GN 9~14），有效距离约 1.5~2.5m。" }}}
enum FilmBrandCategory: String, CaseIterable, Identifiable { case kodak = "kodak"
case fujifilm = "fujifilm"; case cinestill = "cinestill"; case ilford = "ilford"; case lomoOther = "lomo"; case customISO = "custom"; var id: String { rawValue }
func title(for lang: AppLanguage) -> String { switch self { case .kodak: return lang == .en ? "Kodak" : "Kodak 柯达"
case .fujifilm: return lang == .en ? "Fujifilm" : "Fujifilm 富士"; case .cinestill: return "CineStill"; case .ilford: return lang == .en ? "Ilford B&W" : "Ilford 伊尔福"
case .lomoOther: return lang == .en ? "Lomo / Harman" : "Lomo / 哈曼 / 福马"; case .customISO: return lang == .en ? "Manual ISO" : "手动 ISO" }}; var meshColors: (Color, Color) { switch self {
case .kodak: return (Color(red: 0.96, green: 0.62, blue: 0.20), Color(red: 0.86, green: 0.34, blue: 0.16)); case .fujifilm: return (Color(red: 0.10, green: 0.72, blue: 0.50), Color(red: 0.12, green: 0.56, blue: 0.68))
case .cinestill: return (Color(red: 0.94, green: 0.22, blue: 0.28), Color(red: 0.14, green: 0.60, blue: 0.94)); case .ilford: return (Color(red: 0.70, green: 0.75, blue: 0.84), Color(red: 0.40, green: 0.45, blue: 0.55))
case .lomoOther: return (Color(red: 0.68, green: 0.30, blue: 0.98), Color(red: 0.96, green: 0.44, blue: 0.18))
case .customISO: return (Color(red: 0.90, green: 0.68, blue: 0.30), Color(red: 0.35, green: 0.56, blue: 0.86)) }}
var logoCode: String { switch self { case .kodak: return "KODAK"; case .fujifilm: return "FUJI"; case .cinestill: return "CS"
case .ilford: return "ILFORD"; case .lomoOther: return "LOMO"; case .customISO: return "FILM" }}
static func detect(from name: String) -> FilmBrandCategory { let s = name.lowercased()
if s.contains("kodak") || s.contains("portra") || s.contains("gold") || s.contains("ektar") || s.contains("tri-x") || s.contains("t-max") || s.contains("vision") || s.contains("ultramax") || s.contains("colorplus") { return .kodak }
if s.contains("fuji") || s.contains("velvia") || s.contains("provia") || s.contains("acros") || s.contains("superia") || s.contains("natura") || s.contains("c200") || s.contains("400h") { return .fujifilm }
if s.contains("cinestill") || s.contains("800t") || s.contains("400d") || s.contains("50d") || s.contains("bwxx") { return .cinestill }
if s.contains("ilford") || s.contains("hp5") || s.contains("fp4") || s.contains("delta") || s.contains("pan f") { return .ilford }
if s.contains("lomo") || s.contains("harman") || s.contains("phoenix") || s.contains("foma") { return .lomoOther }
return .customISO }}
struct FilmBrandLogoBadge: View { let brand: FilmBrandCategory
var compact: Bool = false; var body: some View {
let pair = brand.meshColors; let fg: Color = (brand == .kodak || brand == .ilford) ? Color.black : Color.white; let bg1: Color = brand == .kodak ? Color(red: 1.0, green: 0.73, blue: 0.0) : (brand == .ilford ? Color.white : pair.0); let bg2: Color = brand == .kodak ? Color(red: 0.90, green: 0.12, blue: 0.20) : (brand == .ilford ? Color(white: 0.86) : pair.1)
return HStack(spacing: 2.5) { if brand == .kodak { Circle().fill(Color(red: 0.88, green: 0.08, blue: 0.15)).frame(width: 5, height: 5)
} else if brand == .fujifilm { Circle().fill(Color(red: 0.92, green: 0.05, blue: 0.12)).frame(width: 5, height: 5)
} else if brand == .cinestill { Image(systemName: "sparkles").font(.system(size: 7.5, weight: .black)).foregroundStyle(Color.yellow) }
Text(brand.logoCode).fMono(compact ? 8.5 : 9.5, .black).foregroundStyle(fg) }.padding(.horizontal, compact ? 5.5 : 7).padding(.vertical, compact ? 2.5 : 3.5).background(LinearGradient(colors: [bg1, bg == true ? bg1 : bg2], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 6)) }
private var bg: Bool { brand == .kodak || brand == .ilford }}
struct FilmStockModel: Identifiable, Equatable { let id: String; let brand: FilmBrandCategory; let name: String; let iso: Double; let tagZh: String; let tagEn: String
func subtitle(for lang: AppLanguage) -> String { lang == .en ? tagEn : tagZh }
static let catalog: [FilmStockModel] = [
FilmStockModel(id: "kodak_portra_400", brand: .kodak, name: "Kodak Portra 400", iso: 400, tagZh: "专业人像负片 · 极高宽容度", tagEn: "Pro Color Neg · Wide Latitude"),
FilmStockModel(id: "kodak_portra_160", brand: .kodak, name: "Kodak Portra 160", iso: 160, tagZh: "专业人像负片 · 细腻肤色", tagEn: "Pro Color Neg · Fine Skin Tone"),
FilmStockModel(id: "kodak_portra_800", brand: .kodak, name: "Kodak Portra 800", iso: 800, tagZh: "高感人像负片 · 弱光质感", tagEn: "High-Speed Pro Color Neg"),
FilmStockModel(id: "kodak_gold_200", brand: .kodak, name: "Kodak Gold 200", iso: 200, tagZh: "经典暖调日常彩色负片", tagEn: "Warm Classic Color Neg"),
FilmStockModel(id: "kodak_colorplus_200", brand: .kodak, name: "Kodak ColorPlus 200", iso: 200, tagZh: "复古暖黄街拍彩色负片", tagEn: "Vintage Warm Street Neg"),
FilmStockModel(id: "kodak_ultramax_400", brand: .kodak, name: "Kodak UltraMax 400", iso: 400, tagZh: "高饱和全能日常彩色负片", tagEn: "Vibrant All-Round Color Neg"),
FilmStockModel(id: "kodak_ektar_100", brand: .kodak, name: "Kodak Ektar 100", iso: 100, tagZh: "风光负片 · 超细颗粒高饱和", tagEn: "Ultra-Fine Vivid Color Neg"),
FilmStockModel(id: "kodak_proimage_100", brand: .kodak, name: "Kodak Pro Image 100", iso: 100, tagZh: "清透人像阳光彩色负片", tagEn: "Natural Portrait Color Neg"),
FilmStockModel(id: "kodak_vision3_50d", brand: .kodak, name: "Kodak Vision3 50D", iso: 50, tagZh: "5203 日光超细电影负片", tagEn: "5203 Daylight Cinema Neg"),
FilmStockModel(id: "kodak_vision3_250d", brand: .kodak, name: "Kodak Vision3 250D", iso: 250, tagZh: "5207 日光中感电影负片", tagEn: "5207 Daylight Cinema Neg"),
FilmStockModel(id: "kodak_vision3_500t", brand: .kodak, name: "Kodak Vision3 500T", iso: 500, tagZh: "5219 灯光夜景电影负片", tagEn: "5219 Tungsten Cinema Neg"),
FilmStockModel(id: "kodak_e100", brand: .kodak, name: "Kodak Ektachrome E100", iso: 100, tagZh: "专业彩色反转片 · 纯净正片", tagEn: "Color Slide Reversal Film"),
FilmStockModel(id: "kodak_trix_400", brand: .kodak, name: "Kodak Tri-X 400", iso: 400, tagZh: "传奇人文纪实黑白负片", tagEn: "Classic Documentary B&W"),
FilmStockModel(id: "kodak_tmax_400", brand: .kodak, name: "Kodak T-Max 400", iso: 400, tagZh: "扁平结晶高锐度黑白负片", tagEn: "T-Grain Fine B&W"),
FilmStockModel(id: "kodak_tmax_3200", brand: .kodak, name: "Kodak T-Max P3200", iso: 3200, tagZh: "暗夜舞台超高感黑白负片", tagEn: "Ultra High-Speed B&W"),
FilmStockModel(id: "fuji_c200", brand: .fujifilm, name: "Fujifilm C200", iso: 200, tagZh: "日系清新日常彩色负片", tagEn: "Classic Fresh Color Neg"),
FilmStockModel(id: "fuji_superia_400", brand: .fujifilm, name: "Fujifilm Superia X-TRA 400", iso: 400, tagZh: "富士经典青绿暗部彩色负片", tagEn: "Iconic Fuji 400 Color Neg"),
FilmStockModel(id: "fuji_pro_400h", brand: .fujifilm, name: "Fujifilm Pro 400H", iso: 400, tagZh: "第四感色层 · 青碧空气感人像", tagEn: "4th Layer Pastel Portrait"),
FilmStockModel(id: "fuji_fujicolor_100", brand: .fujifilm, name: "Fujifilm Fujicolor 100", iso: 100, tagZh: "日版阳光细腻低感彩色负片", tagEn: "Daylight Fine Color Neg"),
FilmStockModel(id: "fuji_natura_1600", brand: .fujifilm, name: "Fujifilm Natura 1600", iso: 1600, tagZh: "月光卷 · 室内弱光高感传奇", tagEn: "High-Speed Low-Light Neg"),
FilmStockModel(id: "fuji_velvia_50", brand: .fujifilm, name: "Fujichrome Velvia 50", iso: 50, tagZh: "RVP50 极致高饱和风光反转片", tagEn: "Vivid Landscape Slide Film"),
FilmStockModel(id: "fuji_provia_100f", brand: .fujifilm, name: "Fujichrome Provia 100F", iso: 100, tagZh: "RDPIII 忠实色彩专业反转片", tagEn: "Neutral Professional Slide"),
FilmStockModel(id: "fuji_acros_100", brand: .fujifilm, name: "Fujifilm Acros 100 II", iso: 100, tagZh: "超细腻黑白 · 优异长曝表现", tagEn: "Ultra-Fine Ortho-Panchro B&W"),
FilmStockModel(id: "cinestill_800t", brand: .cinestill, name: "CineStill 800T", iso: 800, tagZh: "去碳夜景电影卷 · 霓虹红晕", tagEn: "Tungsten Halation Night Film"),
FilmStockModel(id: "cinestill_400d", brand: .cinestill, name: "CineStill 400D", iso: 400, tagZh: "全能日光电影卷 · 柔和红晕", tagEn: "Dynamic Daylight Cinema Film"),
FilmStockModel(id: "cinestill_50d", brand: .cinestill, name: "CineStill 50D", iso: 50, tagZh: "超细日光电影卷 · 纯净高光", tagEn: "Fine Grain Daylight Cinema"),
FilmStockModel(id: "cinestill_bwxx", brand: .cinestill, name: "CineStill BwXX (Double-X)", iso: 250, tagZh: "5222 经典好莱坞黑白电影卷", tagEn: "Classic Cinema B&W 5222"),
FilmStockModel(id: "ilford_hp5_400", brand: .ilford, name: "Ilford HP5 Plus 400", iso: 400, tagZh: "经典人文黑白 · 迫冲潜力极佳", tagEn: "Versatile Street B&W"),
FilmStockModel(id: "ilford_fp4_125", brand: .ilford, name: "Ilford FP4 Plus 125", iso: 125, tagZh: "细腻中感黑白 · 丰富灰阶过渡", tagEn: "Fine Grain Medium Speed B&W"),
FilmStockModel(id: "ilford_panf_50", brand: .ilford, name: "Ilford Pan F Plus 50", iso: 50, tagZh: "极细颗粒高反差静物人像黑白", tagEn: "Ultra-Sharp High Contrast B&W"),
FilmStockModel(id: "ilford_delta_400", brand: .ilford, name: "Ilford Delta 400", iso: 400, tagZh: "核心壳层晶体现代高锐黑白", tagEn: "Core-Shell Modern B&W"),
FilmStockModel(id: "ilford_delta_3200", brand: .ilford, name: "Ilford Delta 3200", iso: 3200, tagZh: "弱光夜景浓郁颗粒超感黑白", tagEn: "Expressive Low-Light B&W"),
FilmStockModel(id: "harman_phoenix_200", brand: .lomoOther, name: "Harman Phoenix 200", iso: 200, tagZh: "高反差复古暖调特色彩色负片", tagEn: "Characterful Warm Color Neg"),
FilmStockModel(id: "lomo_color_400", brand: .lomoOther, name: "Lomography Color 400", iso: 400, tagZh: "浓郁街拍复古色彩负片", tagEn: "Punchy Vintage Color Neg"),
FilmStockModel(id: "lomo_color_800", brand: .lomoOther, name: "Lomography Color 800", iso: 800, tagZh: "高感夜拍低光彩色负片", tagEn: "High-Speed Night Color Neg"),
FilmStockModel(id: "fomapan_100", brand: .lomoOther, name: "Fomapan 100 Classic", iso: 100, tagZh: "捷克古典银盐黑白负片", tagEn: "Czech Classic Vintage B&W"),
FilmStockModel(id: "fomapan_400", brand: .lomoOther, name: "Fomapan 400 Action", iso: 400, tagZh: "捷克复古颗粒感黑白负片", tagEn: "Czech Classic Grain B&W") ] }
@available(iOS 17.0, *)
struct LumiFilmVoiceMeterIntent: AppIntent { static var title: LocalizedStringResource = "Voice Flash Meter (语音调参)"
static var description = IntentDescription("Wake up LumiFilm voice recognition via iPhone Action Button and auto-speak calculated flash power.")
static var openAppWhenRun: Bool = true
func perform() async throws -> some IntentResult { UserDefaults.standard.set(true, forKey: "lf_shortcut_trigger_voice")
DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name("LumiFilmActionVoiceTrigger"), object: nil) }
return .result() }}
@available(iOS 17.0, *)
struct LumiFilmSpeakPowerIntent: AppIntent { static var title: LocalizedStringResource = "Speak Flash Power (播报功率)"
static var description = IntentDescription("Open LumiFilm and speak the current flash power output once.")
static var openAppWhenRun: Bool = true
func perform() async throws -> some IntentResult { UserDefaults.standard.set(true, forKey: "lf_shortcut_trigger_speak")
DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name("LumiFilmActionSpeakTrigger"), object: nil) }
return .result() }}
@available(iOS 17.0, *)
struct LumiFilmShortcutsProvider: AppShortcutsProvider { static var appShortcuts: [AppShortcut] { AppShortcut(
intent: LumiFilmVoiceMeterIntent(), phrases: [
"Start \(.applicationName) voice meter", "Voice meter in \(.applicationName)"
], shortTitle: "Voice Meter", systemImageName: "mic.fill" )
AppShortcut(
intent: LumiFilmSpeakPowerIntent(), phrases: [
"Speak \(.applicationName) flash power", "Read flash power in \(.applicationName)"
], shortTitle: "Speak Power", systemImageName: "bolt.circle.fill" ) }}
@main
struct LumiFilmApp: App { var body: some Scene { WindowGroup { ContentView().preferredColorScheme(.dark) }}}
enum AppLanguage: Int, CaseIterable, Identifiable { case zh = 0
case en = 1; var id: Int { rawValue }; var displayName: String { switch self { case .zh: return "简体中文"; case .en: return "English" }}; var localeIdentifier: String { switch self { case .zh: return "zh-CN"
case .en: return "en-US" }}}
enum FlashBrandCategory: String, CaseIterable, Identifiable { case all = "all"
case godox = "godox"; case contax = "contax"; case canon = "canon"; case nikon = "nikon"; case leicaFuji = "leica_fuji"; case custom = "custom"; var id: String { rawValue }
func title(for lang: AppLanguage) -> String { switch self { case .all: return lang == .en ? "All" : "全部"
case .godox: return lang == .en ? "Godox" : "神牛 Godox"; case .contax: return "Contax"; case .canon: return lang == .en ? "Canon" : "佳能 Canon"; case .nikon: return lang == .en ? "Nikon" : "尼康 Nikon"
case .leicaFuji: return lang == .en ? "Leica / Fuji" : "徕卡 / 富士"; case .custom: return lang == .en ? "Custom GN" : "自定义 GN" }}}
enum FlashRoleMode: Int, CaseIterable, Identifiable { case keyAutoSum = 0; case fillNatural = 1; case catchlightSoft = 2; case pureFlash = 3
var id: Int { rawValue }
func shortTag(for lang: AppLanguage) -> String { switch self { case .keyAutoSum: return lang == .en ? "⚡ Key+Amb" : "⚡ 主光联动"
case .fillNatural: return lang == .en ? "🌤️ Fill -1.3" : "🌤️ 补光 -1.3"; case .catchlightSoft: return lang == .en ? "✨ Fill -2.0" : "✨ 眼神 -2.0"; case .pureFlash: return lang == .en ? "🌑 Pure GN" : "🌑 纯闪光" }}}
struct FlashUnitModel: Identifiable, Equatable {
let id: String; let brand: FlashBrandCategory; let nameZh: String; let nameEn: String; let shortBadge: String; let gnAtISO100: Double; let ratedZoomMM: Int; let minPowerDenominator: Int
init(
id: String, brand: FlashBrandCategory, nameZh: String, nameEn: String, shortBadge: String, gnAtISO100: Double, ratedZoomMM: Int = 50, minPowerDenominator: Int = 128
) { self.id = id
self.brand = brand
self.nameZh = nameZh
self.nameEn = nameEn
self.shortBadge = shortBadge
self.gnAtISO100 = gnAtISO100
self.ratedZoomMM = ratedZoomMM
self.minPowerDenominator = minPowerDenominator }
func displayName(for lang: AppLanguage) -> String { let base = (lang == .en) ? nameEn : nameZh
if id == "custom" { return base }
return "\(base) (GN\(Int(gnAtISO100)) · 1/\(minPowerDenominator))" }
static let catalog: [FlashUnitModel] = [
FlashUnitModel(id: "godox_lux_cadet", brand: .godox, nameZh: "神牛 Lux Cadet 复古小闪", nameEn: "Godox Lux Cadet", shortBadge: "Lux Cadet", gnAtISO100: 10, ratedZoomMM: 28, minPowerDenominator: 64),
FlashUnitModel(id: "godox_lux_jr", brand: .godox, nameZh: "神牛 Lux Junior 复古街拍灯", nameEn: "Godox Lux Junior", shortBadge: "Lux Jr", gnAtISO100: 12, ratedZoomMM: 28, minPowerDenominator: 64),
FlashUnitModel(id: "godox_lux_sr", brand: .godox, nameZh: "神牛 Lux Senior 复古折叠扇", nameEn: "Godox Lux Senior", shortBadge: "Lux Sr", gnAtISO100: 14, ratedZoomMM: 28, minPowerDenominator: 64),
FlashUnitModel(id: "godox_im30", brand: .godox, nameZh: "神牛 iM30 / iM20 迷你机顶灯", nameEn: "Godox iM30 Mini", shortBadge: "Godox iM30", gnAtISO100: 15, ratedZoomMM: 28, minPowerDenominator: 64),
FlashUnitModel(id: "godox_lux_master", brand: .godox, nameZh: "神牛 Lux Master 复古手柄灯", nameEn: "Godox Lux Master", shortBadge: "Lux Master", gnAtISO100: 25, ratedZoomMM: 28, minPowerDenominator: 256),
FlashUnitModel(id: "godox_v350", brand: .godox, nameZh: "神牛 V350 / TT350 便携主力灯", nameEn: "Godox V350 / TT350", shortBadge: "Godox V350", gnAtISO100: 36, ratedZoomMM: 105, minPowerDenominator: 128),
FlashUnitModel(id: "godox_v1", brand: .godox, nameZh: "神牛 V1 / V1Pro 圆头旗舰灯", nameEn: "Godox V1 / V1Pro", shortBadge: "Godox V1", gnAtISO100: 42, ratedZoomMM: 105, minPowerDenominator: 256),
FlashUnitModel(id: "godox_ad100", brand: .godox, nameZh: "神牛 AD100Pro 口袋外拍灯", nameEn: "Godox AD100Pro", shortBadge: "AD100Pro", gnAtISO100: 44, ratedZoomMM: 85, minPowerDenominator: 256),
FlashUnitModel(id: "godox_ad200", brand: .godox, nameZh: "神牛 AD200Pro II 外拍灯", nameEn: "Godox AD200Pro II", shortBadge: "AD200Pro", gnAtISO100: 52, ratedZoomMM: 35, minPowerDenominator: 256),
FlashUnitModel(id: "godox_v860iii", brand: .godox, nameZh: "神牛 V860III / TT685II / TT600", nameEn: "Godox V860III / TT685II", shortBadge: "Godox V860", gnAtISO100: 60, ratedZoomMM: 105, minPowerDenominator: 128),
FlashUnitModel(id: "contax_tla140", brand: .contax, nameZh: "Contax TLA 140 (G1/G2 便携灯)", nameEn: "Contax TLA 140", shortBadge: "TLA 140", gnAtISO100: 14, ratedZoomMM: 28, minPowerDenominator: 16),
FlashUnitModel(id: "contax_tla200", brand: .contax, nameZh: "Contax TLA 200 (G2 经典饼干灯)", nameEn: "Contax TLA 200", shortBadge: "TLA 200", gnAtISO100: 20, ratedZoomMM: 28, minPowerDenominator: 16),
FlashUnitModel(id: "contax_tla280", brand: .contax, nameZh: "Contax TLA 280 胶片闪光灯", nameEn: "Contax TLA 280", shortBadge: "TLA 280", gnAtISO100: 28, ratedZoomMM: 50, minPowerDenominator: 64),
FlashUnitModel(id: "contax_tla360", brand: .contax, nameZh: "Contax TLA 360 专业胶片灯", nameEn: "Contax TLA 360", shortBadge: "TLA 360", gnAtISO100: 36, ratedZoomMM: 85, minPowerDenominator: 64),
FlashUnitModel(id: "canon_270ex2", brand: .canon, nameZh: "佳能 Speedlite 270EX II / EL-100", nameEn: "Canon 270EX II / EL-100", shortBadge: "Canon 270EX", gnAtISO100: 27, ratedZoomMM: 50, minPowerDenominator: 64),
FlashUnitModel(id: "canon_380ex", brand: .canon, nameZh: "佳能 Speedlite 380EX / 420EX", nameEn: "Canon 380EX / 420EX", shortBadge: "Canon 380EX", gnAtISO100: 38, ratedZoomMM: 105, minPowerDenominator: 64),
FlashUnitModel(id: "canon_430ex3", brand: .canon, nameZh: "佳能 Speedlite 430EX III-RT", nameEn: "Canon 430EX III-RT", shortBadge: "Canon 430EX", gnAtISO100: 43, ratedZoomMM: 105, minPowerDenominator: 128),
FlashUnitModel(id: "canon_580ex2", brand: .canon, nameZh: "佳能 Speedlite 580EX II", nameEn: "Canon 580EX II", shortBadge: "Canon 580EX", gnAtISO100: 58, ratedZoomMM: 105, minPowerDenominator: 128),
FlashUnitModel(id: "canon_600ex2", brand: .canon, nameZh: "佳能 Speedlite 600EX II / EL-5 / EL-1", nameEn: "Canon 600EX II / EL-5", shortBadge: "Canon 600EX", gnAtISO100: 60, ratedZoomMM: 105, minPowerDenominator: 256),
FlashUnitModel(id: "nikon_sb30", brand: .nikon, nameZh: "尼康 SB-30 / SB-400 超薄机顶灯", nameEn: "Nikon SB-30 / SB-400", shortBadge: "Nikon SB-30", gnAtISO100: 18, ratedZoomMM: 28, minPowerDenominator: 32),
FlashUnitModel(id: "nikon_sb20", brand: .nikon, nameZh: "尼康 SB-20 / SB-22s / SB-700", nameEn: "Nikon SB-20 / SB-700", shortBadge: "Nikon SB-700", gnAtISO100: 28, ratedZoomMM: 85, minPowerDenominator: 128),
FlashUnitModel(id: "nikon_sb28", brand: .nikon, nameZh: "尼康 SB-24 / SB-26 / SB-28 经典胶片灯", nameEn: "Nikon SB-24 / SB-26 / SB-28", shortBadge: "Nikon SB-28", gnAtISO100: 36, ratedZoomMM: 85, minPowerDenominator: 64),
FlashUnitModel(id: "nikon_sb800", brand: .nikon, nameZh: "尼康 SB-800 / SB-900 / SB-910", nameEn: "Nikon SB-800 / SB-910", shortBadge: "Nikon SB-800", gnAtISO100: 38, ratedZoomMM: 105, minPowerDenominator: 128),
FlashUnitModel(id: "nikon_sb5000", brand: .nikon, nameZh: "尼康 SB-5000 旗舰闪光灯", nameEn: "Nikon SB-5000", shortBadge: "Nikon SB5000", gnAtISO100: 55, ratedZoomMM: 105, minPowerDenominator: 256),
FlashUnitModel(id: "fuji_efx20", brand: .leicaFuji, nameZh: "富士 EF-X20 / 徕卡 SF 20 金属饼干灯", nameEn: "Fuji EF-X20 / Leica SF 20", shortBadge: "EF-X20/SF20", gnAtISO100: 20, ratedZoomMM: 28, minPowerDenominator: 64),
FlashUnitModel(id: "leica_sf24d", brand: .leicaFuji, nameZh: "徕卡 Leica SF 24D / SF 26", nameEn: "Leica SF 24D / SF 26", shortBadge: "Leica SF24D", gnAtISO100: 24, ratedZoomMM: 35, minPowerDenominator: 64),
FlashUnitModel(id: "metz_32ct3", brand: .leicaFuji, nameZh: "美兹 Metz 32 CT-3 / 32 MZ-3", nameEn: "Metz 32 CT-3", shortBadge: "Metz 32", gnAtISO100: 32, ratedZoomMM: 50, minPowerDenominator: 64),
FlashUnitModel(id: "leica_sf40", brand: .leicaFuji, nameZh: "徕卡 Leica SF 40 / Profoto A10", nameEn: "Leica SF 40 / Profoto A10", shortBadge: "SF40 / A10", gnAtISO100: 40, ratedZoomMM: 105, minPowerDenominator: 256),
FlashUnitModel(id: "metz_45cl4", brand: .leicaFuji, nameZh: "美兹 Metz 45 CL-4 手柄灯", nameEn: "Metz 45 CL-4 Hammerhead", shortBadge: "Metz 45", gnAtISO100: 45, ratedZoomMM: 35, minPowerDenominator: 64),
FlashUnitModel(id: "leica_sf60", brand: .leicaFuji, nameZh: "徕卡 Leica SF 60 / 富士 EF-60", nameEn: "Leica SF 60 / Fuji EF-60", shortBadge: "Leica SF60", gnAtISO100: 60, ratedZoomMM: 105, minPowerDenominator: 256),
FlashUnitModel(id: "custom", brand: .custom, nameZh: "用户自定义闪光灯 GN", nameEn: "User Custom Flash GN", shortBadge: "Custom", gnAtISO100: 36, ratedZoomMM: 50, minPowerDenominator: 128) ] }
final class CameraAmbientEVReader: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate { static let shared = CameraAmbientEVReader()
@Published var liveEV100: Double = 9.0
@Published var liveDistanceMeters: Double = 2.0
@Published var hasLiDARDepth: Bool = false
@Published var distanceSensorLabel: String = "AF Focus"
@Published var cameraISO: Float = 200
@Published var cameraShutterDenom: Int = 125
@Published var cameraAperture: Float = 1.8
@Published var cameraTargetOffset: Float = 0.0
@Published var calibrationTrimEV: Double = 0.0
@Published var isRunning: Bool = false
@Published var continuousSyncToMeter: Bool = true
@Published var useUltraWideLens: Bool = false
@Published var statusText: String = ""
let session = AVCaptureSession()
private var device: AVCaptureDevice?
private let videoOutput = AVCaptureVideoDataOutput()
private let depthOutput = AVCaptureDepthDataOutput()
private let videoQueue = DispatchQueue(label: "com.lumifilm.camera.ev.queue", qos: .userInteractive)
private var isConfigured: Bool = false
private var smoothedEV: Double = 9.0
private var smoothedDist: Double = 2.0
private var lastUIUpdateTime: TimeInterval = 0
private var lastDepthTime: TimeInterval = 0
var onLiveEVUpdated: ((Double) -> Void)?
func startReading(lang: AppLanguage, onEVUpdate: ((Double) -> Void)? = nil) { if let cb = onEVUpdate { self.onLiveEVUpdated = cb }
AVCaptureDevice.requestAccess(for: .video) { granted in
DispatchQueue.main.async { if granted { self.setupAndStartSession(lang: lang) } else { self.statusText = lang == .en ? "Please allow Camera access in iOS Settings." : "请在 iOS 设置中允许相机权限以实时测光与测距" }}}}
func toggleLensFieldOfView(lang: AppLanguage) { useUltraWideLens.toggle()
configureCameraInput(useUltraWide: useUltraWideLens, lang: lang) }
private func selectBestCameraDevice(useUltraWide: Bool) -> (AVCaptureDevice?, Bool, String) { if !useUltraWide { if let lidarCam = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back) {
return (lidarCam, true, "LiDAR 激光雷达") }
if let dualWide = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) { return (dualWide, true, "Dual 景深双摄") }
if let dualCam = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) { return (dualCam, true, "Dual 景深双摄") }}
let fallbackType: AVCaptureDevice.DeviceType = useUltraWide ? .builtInUltraWideCamera : .builtInWideAngleCamera; let cam = AVCaptureDevice.default(fallbackType, for: .video, position: .back) ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
return (cam, false, "AF 对焦传感器") }
private func configureCameraInput(useUltraWide: Bool, lang: AppLanguage) { let (camOpt, supportsDepth, sensorTag) = selectBestCameraDevice(useUltraWide: useUltraWide)
guard let cam = camOpt else { statusText = lang == .en ? "Rear camera unavailable" : "未检测到后置摄像头"
return }
self.device = cam
DispatchQueue.main.async { self.hasLiDARDepth = supportsDepth
self.distanceSensorLabel = sensorTag }
session.beginConfiguration()
if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo } else { session.sessionPreset = .high }
for existingInput in session.inputs { session.removeInput(existingInput) }
if let input = try? AVCaptureDeviceInput(device: cam), session.canAddInput(input) { session.addInput(input) }
if !isConfigured { videoOutput.alwaysDiscardsLateVideoFrames = true
videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
depthOutput.isFilteringEnabled = true
depthOutput.setDelegate(self, callbackQueue: videoQueue)
if session.canAddOutput(depthOutput) { session.addOutput(depthOutput) }
isConfigured = true }
if let depthConn = depthOutput.connection(with: .depthData) { depthConn.isEnabled = supportsDepth }
session.commitConfiguration()
recenterExposurePoint() }
private func setupAndStartSession(lang: AppLanguage) { if !isConfigured { configureCameraInput(useUltraWide: useUltraWideLens, lang: lang) }
recenterExposurePoint()
statusText = lang == .en ? "Center reticle measures EV100 & subject distance" : "中心准星实时测量环境光 EV 与主体物理距离"
if !session.isRunning { videoQueue.async { self.session.startRunning()
DispatchQueue.main.async { self.isRunning = true }}
} else { isRunning = true }}
func stopReading() { if session.isRunning { videoQueue.async { self.session.stopRunning()
DispatchQueue.main.async { self.isRunning = false }}} else { isRunning = false }}
func recenterExposurePoint() { guard let cam = device else { return }
do { try cam.lockForConfiguration()
if cam.isExposureModeSupported(.continuousAutoExposure) { cam.exposureMode = .continuousAutoExposure }
if cam.isExposurePointOfInterestSupported { cam.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5) }
if cam.isFocusModeSupported(.continuousAutoFocus) { cam.focusMode = .continuousAutoFocus }
if cam.isFocusPointOfInterestSupported { cam.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5) }
cam.unlockForConfiguration()
} catch {}}
func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
let converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32); let buf = converted.depthDataMap
CVPixelBufferLockBaseAddress(buf, .readOnly)
defer { CVPixelBufferUnlockBaseAddress(buf, .readOnly) }
let w = CVPixelBufferGetWidth(buf); let h = CVPixelBufferGetHeight(buf); let rowBytes = CVPixelBufferGetBytesPerRow(buf)
guard let base = CVPixelBufferGetBaseAddress(buf), w > 4, h > 4 else { return }
var validSamples: [Float] = []; let cxMin = max(0, w * 45 / 100); let cxMax = min(w - 1, w * 55 / 100); let cyMin = max(0, h * 45 / 100); let cyMax = min(h - 1, h * 55 / 100)
for y in stride(from: cyMin, through: cyMax, by: 2) { let rowPtr = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float32.self)
for x in stride(from: cxMin, through: cxMax, by: 2) { let d = rowPtr[x]
if d.isFinite && d >= 0.25 && d <= 15.0 { validSamples.append(d) }}}
guard !validSamples.isEmpty else { return }
validSamples.sort()
let medianMeters = Double(validSamples[validSamples.count / 2])
smoothedDist = smoothedDist * 0.65 + medianMeters * 0.35
let roundedDist = max(0.4, min(15.0, (smoothedDist * 10.0).rounded() / 10.0))
lastDepthTime = Date().timeIntervalSinceReferenceDate
DispatchQueue.main.async { self.hasLiDARDepth = true
self.liveDistanceMeters = roundedDist }}
func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) { guard let cam = device else { return }
let now = Date().timeIntervalSinceReferenceDate
guard now - lastUIUpdateTime >= 0.10 else { return }
lastUIUpdateTime = now
let ap = Double(max(cam.lensAperture, 1.2)); let dur = max(CMTimeGetSeconds(cam.exposureDuration), 0.00005); let isoVal = Double(max(cam.iso, 20.0)); let targetOffset = Double(cam.exposureTargetOffset); let rawEV100 = log2((ap * ap) / dur) - log2(isoVal / 100.0) - targetOffset + calibrationTrimEV; let clampedEV = max(-2.0, min(18.0, rawEV100))
smoothedEV = (smoothedEV * 0.72) + (clampedEV * 0.28)
let roundedEV = (smoothedEV * 10.0).rounded() / 10.0; let denom = max(1, Int((1.0 / dur).rounded())); var fallbackDist: Double? = nil
if now - lastDepthTime > 0.6 { let lp = Double(max(0.02, min(0.98, cam.lensPosition))); let est = 0.35 / pow(1.0 - lp, 0.82); let clampedD = max(0.5, min(12.0, (est * 10.0).rounded() / 10.0))
smoothedDist = smoothedDist * 0.78 + clampedD * 0.22
fallbackDist = (smoothedDist * 10.0).rounded() / 10.0 }
DispatchQueue.main.async { self.liveEV100 = roundedEV
self.cameraISO = Float(isoVal)
self.cameraShutterDenom = denom
self.cameraAperture = Float(ap)
self.cameraTargetOffset = Float(targetOffset)
if let fd = fallbackDist { self.liveDistanceMeters = fd }
if self.continuousSyncToMeter { self.onLiveEVUpdated?(roundedEV) }}}}
struct CameraPreviewLayerView: UIViewRepresentable { let session: AVCaptureSession
final class PreviewUIView: UIView { override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }}
func makeUIView(context: Context) -> PreviewUIView { let view = PreviewUIView()
view.backgroundColor = UIColor.black
view.previewLayer.session = session
view.previewLayer.videoGravity = .resizeAspectFill
return view }
func updateUIView(_ uiView: PreviewUIView, context: Context) { if uiView.previewLayer.session !== session { uiView.previewLayer.session = session }}}
struct PresetOption: Identifiable, Equatable { let id: String; let titleZh: String; let titleEn: String; let value: Double
init(_ id: String, zh: String, en: String, value: Double) { self.id = id
self.titleZh = zh
self.titleEn = en
self.value = value }
func title(for lang: AppLanguage) -> String { lang == .en ? titleEn : titleZh }}
enum AppTheme: Int, CaseIterable, Identifiable { case instagramGlow = 0
case threadsMinimal = 1; case leicaBrushedBrass = 2; var id: Int { rawValue }
func name(for lang: AppLanguage) -> String { switch self { case .instagramGlow: return lang == .en ? "Sakura Mist" : "雾粉微光 (淡雅)"
case .threadsMinimal: return "Threads Obsidian"; case .leicaBrushedBrass: return lang == .en ? "Film Brass" : "Film Brass (露铜)" }}
func subtitle(for lang: AppLanguage) -> String { switch self { case .instagramGlow: return lang == .en ? "Soft Morandi Sakura & Warm Pearl" : "莫兰迪清新淡粉与温润香槟"
case .threadsMinimal: return lang == .en ? "Obsidian High-Contrast Frosted Glass" : "极简纯黑高对比毛玻璃"; case .leicaBrushedBrass: return lang == .en ? "Vintage Black Paint & Patina Brass" : "复古胶片相机黑漆露铜" }}; var icon: String {
switch self { case .instagramGlow: return "sparkles.rectangle.stack.fill"
case .threadsMinimal: return "at.circle.fill"; case .leicaBrushedBrass: return "camera.aperture" }}; var backgroundGradient: [Color] { switch self { case .instagramGlow: return [
Color(red: 0.17, green: 0.16, blue: 0.20), Color(red: 0.24, green: 0.20, blue: 0.23), Color(red: 0.22, green: 0.19, blue: 0.21), Color(red: 0.14, green: 0.14, blue: 0.17) ]
case .threadsMinimal: return [
Color(red: 0.03, green: 0.03, blue: 0.04), Color(red: 0.09, green: 0.09, blue: 0.11), Color(red: 0.04, green: 0.04, blue: 0.05) ]
case .leicaBrushedBrass: return [
Color(red: 0.09, green: 0.08, blue: 0.07), Color(red: 0.19, green: 0.14, blue: 0.09), Color(red: 0.28, green: 0.20, blue: 0.11), Color(red: 0.08, green: 0.07, blue: 0.06) ] }}
var accent: Color { switch self { case .instagramGlow: return Color(red: 0.94, green: 0.79, blue: 0.82); case .threadsMinimal: return Color(red: 0.96, green: 0.96, blue: 0.98)
case .leicaBrushedBrass: return Color(red: 0.90, green: 0.68, blue: 0.32) }}; var secondaryAccent: Color { switch self { case .instagramGlow: return Color(red: 0.86, green: 0.82, blue: 0.78)
case .threadsMinimal: return Color(red: 0.58, green: 0.62, blue: 0.70); case .leicaBrushedBrass: return Color(red: 0.78, green: 0.48, blue: 0.22) }}; var dialRingColors: [Color] {
switch self { case .instagramGlow: return [
Color(red: 0.94, green: 0.79, blue: 0.82), Color(red: 0.86, green: 0.82, blue: 0.78), Color(red: 0.70, green: 0.64, blue: 0.68), Color(red: 0.94, green: 0.79, blue: 0.82) ]
case .threadsMinimal: return [
Color(white: 0.85), Color(white: 0.28), Color(white: 0.65), Color(white: 0.85) ]
case .leicaBrushedBrass: return [
Color(red: 0.92, green: 0.73, blue: 0.40), Color(red: 0.55, green: 0.38, blue: 0.18), Color(red: 0.85, green: 0.62, blue: 0.28), Color(red: 0.38, green: 0.26, blue: 0.12), Color(red: 0.92, green: 0.73, blue: 0.40) ] }}}
enum DialParameter: Int, CaseIterable, Identifiable { case aperture = 0
case distance = 1; case shutter = 2; case flashPower = 3; var id: Int { rawValue }
func title(for lang: AppLanguage) -> String { switch self { case .aperture: return lang == .en ? "f-Stop" : "光圈 f/"
case .distance: return lang == .en ? "Dist m" : "距离 m"; case .shutter: return lang == .en ? "Shutter" : "快门 1/s"; case .flashPower: return lang == .en ? "Power" : "输出功率" }}; var icon: String {
switch self { case .aperture: return "camera.aperture"
case .distance: return "ruler.fill"; case .shutter: return "timer"; case .flashPower: return "bolt.badge.lock.fill" }}}
enum VoicePersona: Int, CaseIterable, Identifiable { case magneticMale = 0
case gentleFemale = 1; var id: Int { rawValue }
func title(for lang: AppLanguage) -> String { switch self { case .magneticMale: return lang == .en ? "Magnetic Male (Default)" : "磁性男声 (默认)"
case .gentleFemale: return lang == .en ? "Gentle Female" : "温柔女声" }}; var icon: String { switch self { case .magneticMale: return "waveform.badge.mic"
case .gentleFemale: return "person.wave.2.fill" }}; var pitch: Float { switch self { case .magneticMale: return 0.92; case .gentleFemale: return 1.08 }}; var rate: Float { switch self { case .magneticMale: return 0.48
case .gentleFemale: return 0.49 }}}
struct FilmFrameRecord: Codable, Identifiable, Equatable { var id: UUID = UUID()
var frameNumber: Int; var filmStockName: String; var aperture: Double; var shutterDenom: Int; var distance: Double
var powerLabel: String; var iso: Double; var evComp: Double; var filterName: String; var locationText: String; var sceneNote: String; var timestamp: String }
final class FeedbackEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate { static let shared = FeedbackEngine()
private let synthesizer = AVSpeechSynthesizer()
private let impactLight = UIImpactFeedbackGenerator(style: .light)
private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
private let selectionGen = UISelectionFeedbackGenerator()
private let notifyGen = UINotificationFeedbackGenerator()
@Published var isSpeaking: Bool = false
@Published var isListening: Bool = false
@Published var recognizedTranscript: String = ""
@Published var voiceStatusHint: String = ""
@Published var activeVoiceQualityLabel: String = "Enhanced Voice"
private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
private var recognitionTask: SFSpeechRecognitionTask?
private let audioEngine = AVAudioEngine()
private var onCommandRecognized: ((String) -> Void)?
private var onAutoStopAfterActionTrigger: (() -> Void)?
private var silenceTimerWorkItem: DispatchWorkItem?
private var currentLanguage: AppLanguage = .zh
override init() { super.init()
synthesizer.delegate = self
impactLight.prepare()
impactMedium.prepare()
impactRigid.prepare()
selectionGen.prepare()
refreshVoiceQualityStatus(persona: .magneticMale, lang: .zh) }
func dialTick(soundEnabled: Bool, hapticEnabled: Bool, magneticSnap: Bool = false) { if hapticEnabled { if magneticSnap { impactRigid.impactOccurred(intensity: 1.0) } else { impactLight.impactOccurred(intensity: 0.75) }}
if soundEnabled { AudioServicesPlaySystemSound(magneticSnap ? 1156 : 1157) }}
func buttonTap(soundEnabled: Bool, hapticEnabled: Bool) { if hapticEnabled { impactMedium.impactOccurred() }
if soundEnabled { AudioServicesPlaySystemSound(1104) }}
func tabSwitchHaptic(soundEnabled: Bool, hapticEnabled: Bool) { if hapticEnabled { selectionGen.selectionChanged()
impactRigid.impactOccurred(intensity: 0.92)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.045) { self.impactLight.impactOccurred(intensity: 0.55) }}
if soundEnabled { AudioServicesPlaySystemSound(1104) }}
func lockToggleFeedback(soundEnabled: Bool, hapticEnabled: Bool) { if hapticEnabled { notifyGen.notificationOccurred(.success) }
if soundEnabled { AudioServicesPlaySystemSound(1113) }}
func zeroEVSnapFeedback(soundEnabled: Bool, hapticEnabled: Bool) { if hapticEnabled { impactHeavy.impactOccurred(intensity: 1.0)
notifyGen.notificationOccurred(.success) }
if soundEnabled { AudioServicesPlaySystemSound(1156) }}
private func voiceMatchesPersona(_ voice: AVSpeechSynthesisVoice, persona: VoicePersona) -> Bool { let targetGender: AVSpeechSynthesisVoiceGender = (persona == .magneticMale) ? .male : .female
if voice.gender == targetGender { return true }
let lowerName = voice.name.lowercased(); let lowerId = voice.identifier.lowercased(); let keywords: [String] = (persona == .magneticMale)
? ["yunxi", "kangkang", "li-mu", "limu", "yushu", "male", "daniel", "aaron", "arthur", "gordon"]
: ["xiaoxiao", "tingting", "ting-ting", "meijia", "mei-jia", "sin-ji", "sinji", "shasha", "lili", "female", "siri", "samantha", "ava", "allison"]
for kw in keywords { if lowerName.contains(kw) || lowerId.contains(kw) { return true }}
return false }
private func selectBestHumanVoice(for persona: VoicePersona, lang: AppLanguage) -> (AVSpeechSynthesisVoice?, String) { let allVoices = AVSpeechSynthesisVoice.speechVoices(); let prefix = (lang == .en) ? "en" : "zh"
let langVoices = allVoices.filter { $0.language.lowercased().hasPrefix(prefix) }; let sortedVoices = langVoices.sorted { a, b in
if a.quality.rawValue != b.quality.rawValue { return a.quality.rawValue > b.quality.rawValue }
let aPref = (lang == .en ? a.language.lowercased().contains("us") : a.language.lowercased().contains("cn")) ? 1 : 0; let bPref = (lang == .en ? b.language.lowercased().contains("us") : b.language.lowercased().contains("cn")) ? 1 : 0
return aPref > bPref }
for v in sortedVoices { if v.quality.rawValue >= AVSpeechSynthesisVoiceQuality.enhanced.rawValue && voiceMatchesPersona(v, persona: persona) {
let badge = v.quality == .premium ? "Premium (\(v.name))" : "Enhanced (\(v.name))"; return (v, badge) }}
for v in sortedVoices { if voiceMatchesPersona(v, persona: persona) { return (v, v.name) }}
if let bestAvailable = sortedVoices.first { return (bestAvailable, bestAvailable.name) }
return (AVSpeechSynthesisVoice(language: lang.localeIdentifier), lang == .en ? "System English" : "系统语音") }
func refreshVoiceQualityStatus(persona: VoicePersona = .magneticMale, lang: AppLanguage = .zh) { self.currentLanguage = lang
let (_, label) = selectBestHumanVoice(for: persona, lang: lang)
activeVoiceQualityLabel = label }
func toggleSpeakExposure(_ text: String, soundEnabled: Bool, persona: VoicePersona, lang: AppLanguage) { guard soundEnabled else { return }
if synthesizer.isSpeaking || isSpeaking { synthesizer.stopSpeaking(at: .immediate)
isSpeaking = false
return }
if isListening { stopListening() }
let session = AVAudioSession.sharedInstance()
try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
try? session.setActive(true)
let utterance = AVSpeechUtterance(string: text); let (selectedVoice, badgeLabel) = selectBestHumanVoice(for: persona, lang: lang)
activeVoiceQualityLabel = badgeLabel
utterance.voice = selectedVoice
let isHighQuality = (selectedVoice?.quality.rawValue ?? 1) >= AVSpeechSynthesisVoiceQuality.enhanced.rawValue
if isHighQuality { switch persona { case .magneticMale: utterance.pitchMultiplier = 0.95
utterance.rate = 0.49
case .gentleFemale: utterance.pitchMultiplier = 1.03
utterance.rate = 0.50 }} else { utterance.pitchMultiplier = persona.pitch
utterance.rate = persona.rate }
utterance.preUtteranceDelay = 0.03
utterance.postUtteranceDelay = 0.06
isSpeaking = true
synthesizer.speak(utterance) }
func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { DispatchQueue.main.async { FeedbackEngine.shared.isSpeaking = false }}
func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { DispatchQueue.main.async { FeedbackEngine.shared.isSpeaking = false }}
private func scheduleSilenceAutoStop(after seconds: Double) { silenceTimerWorkItem?.cancel()
let work = DispatchWorkItem { if FeedbackEngine.shared.isListening { FeedbackEngine.shared.stopListening() }}
silenceTimerWorkItem = work
DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work) }
func toggleVoiceListening(lang: AppLanguage, onRecognized: @escaping (String) -> Void) { self.currentLanguage = lang
if isListening { stopListening()
return }
if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate)
isSpeaking = false }
self.onCommandRecognized = onRecognized
SFSpeechRecognizer.requestAuthorization { authStatus in
DispatchQueue.main.async { switch authStatus { case .authorized: AVAudioApplication.requestRecordPermission { granted in
DispatchQueue.main.async { if granted { FeedbackEngine.shared.startRecordingSession(lang: lang) } else { FeedbackEngine.shared.voiceStatusHint = lang == .en
? "Please allow Microphone access in Settings"
: "请在系统设置中允许麦克风权限" }}}
default: FeedbackEngine.shared.voiceStatusHint = lang == .en
? "Please allow Speech Recognition in Settings"
: "请在系统设置中允许语音识别权限" }}}}
private func startRecordingSession(lang: AppLanguage) { recognitionTask?.cancel()
recognitionTask = nil
silenceTimerWorkItem?.cancel()
let audioSession = AVAudioSession.sharedInstance()
do { try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
} catch { voiceStatusHint = lang == .en ? "Audio session error" : "音频通道启动失败"
return }
let req = SFSpeechAudioBufferRecognitionRequest()
req.shouldReportPartialResults = true
req.contextualStrings = [
"f3", "f/3", "f2.8", "f4", "f5.6", "f8", "f11", "f16", "f1.4", "f1.8", "f2", "光圈3", "光圈2.8", "光圈4", "光圈5.6", "光圈8", "快门200", "快门速度200分之一秒", "200分之一秒", "快门125", "快门60", "快门250", "快门500", "快门1000",
"距离0.7米", "距离1.2米", "距离1.5米", "距离2米", "距离2.5米", "距离3米", "纯闪光", "主光联动", "自然补光", "逆光补光", "眼神光",
"大太阳天", "大太阳", "晴天", "阴天", "多云", "树荫", "逆光", "明亮室内", "办公室", "室内", "咖啡馆", "酒吧", "昏暗", "夜景", "夜晚", "加一档", "减一档", "归零", "肥皂盒", "柔光箱", "跳闪", "天花板",
"shutter 200", "shutter 125", "aperture 2.8", "aperture 4", "2 meters", "pure flash", "fill flash", "sunny", "shade", "indoor", "night" ]
self.recognitionRequest = req
let inputNode = audioEngine.inputNode; let recordingFormat = inputNode.outputFormat(forBus: 0)
inputNode.removeTap(onBus: 0)
inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
req.append(buffer) }
audioEngine.prepare()
do { try audioEngine.start()
isListening = true
recognizedTranscript = ""
voiceStatusHint = lang == .en
? "Listening (auto-stops)... Say e.g. 'f3', 'shutter 200'"
: "正在聆听(静音自动停止)... 请说“f3”、“快门200”"
scheduleSilenceAutoStop(after: 4.2)
} catch { voiceStatusHint = lang == .en ? "Microphone failed to start" : "麦克风启动失败"
return }
let recognizer = SFSpeechRecognizer(locale: Locale(identifier: lang.localeIdentifier)) ?? SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
recognitionTask = recognizer?.recognitionTask(with: req) { result, error in
DispatchQueue.main.async { let engine = FeedbackEngine.shared
if let result = result { let text = result.bestTranscription.formattedString
engine.recognizedTranscript = text
engine.onCommandRecognized?(text)
engine.scheduleSilenceAutoStop(after: 1.6) }
if error != nil || (result?.isFinal ?? false) { if engine.isListening { engine.stopListening() }}}}}
func stopListening() { silenceTimerWorkItem?.cancel()
silenceTimerWorkItem = nil
if audioEngine.isRunning { audioEngine.stop()
audioEngine.inputNode.removeTap(onBus: 0) }
recognitionRequest?.endAudio()
recognitionTask?.cancel()
recognitionRequest = nil
recognitionTask = nil
isListening = false
if !recognizedTranscript.isEmpty { voiceStatusHint = currentLanguage == .en
? "Synced: \"\(recognizedTranscript)\""
: "已识别同步：“\(recognizedTranscript)”"
if let speakAfter = onAutoStopAfterActionTrigger { onAutoStopAfterActionTrigger = nil
DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { speakAfter() }}} else { onAutoStopAfterActionTrigger = nil
voiceStatusHint = "" }}
func startVoiceFromShortcut(lang: AppLanguage, onRecognized: @escaping (String) -> Void, onAutoStoppedSpeak: @escaping () -> Void) { self.currentLanguage = lang
if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate)
isSpeaking = false }
if isListening { stopListening() }
self.onCommandRecognized = onRecognized
self.onAutoStopAfterActionTrigger = onAutoStoppedSpeak
SFSpeechRecognizer.requestAuthorization { authStatus in
DispatchQueue.main.async { if authStatus == .authorized { AVAudioApplication.requestRecordPermission { granted in
DispatchQueue.main.async { if granted { FeedbackEngine.shared.startRecordingSession(lang: lang) }}}}}}}}
struct ContentView: View {
@AppStorage("lf_onboarded_v98") private var hasCompletedOnboarding: Bool = false; @AppStorage("lf_lang_v8") private var langRaw: Int = 0; @AppStorage("lf_iso") private var filmISO: Double = 400.0; @AppStorage("lf_gn") private var flashGN: Double = 36.0; @AppStorage("lf_flash_model_id") private var selectedFlashID: String = "godox_v350"; @AppStorage("lf_max_aperture") private var maxLensAperture: Double = 1.4; @AppStorage("lf_sync_speed") private var maxSyncSpeed: Int = 125; @AppStorage("lf_sync_mode") private var syncModeRaw: Int = 0; @AppStorage("lf_camera_preset_id") private var cameraPresetID: String = "pentax67"; @AppStorage("lf_aperture") private var aperture: Double = 5.6; @AppStorage("lf_distance") private var distance: Double = 2.0; @AppStorage("lf_shutter") private var shutterDenom: Int = 125; @AppStorage("lf_locked_power_idx") private var manualPowerIndex: Int = 2; @AppStorage("lf_theme") private var themeRaw: Int = 2; @AppStorage("lf_sound") private var soundEnabled: Bool = true; @AppStorage("lf_haptic") private var hapticEnabled: Bool = true; @AppStorage("lf_voice_persona_v7") private var voicePersonaRaw: Int = 0; @AppStorage("lf_modifier_loss") private var modifierLossEV: Double = 0.0; @AppStorage("lf_bounce_loss") private var bounceLossEV: Double = 0.0; @AppStorage("lf_ambient_ev100") private var ambientEV100: Double = 10.0; @AppStorage("lf_exp_comp_ev") private var exposureCompEV: Double = 0.0; @AppStorage("lf_push_pull_ev") private var pushPullEV: Double = 0.0; @AppStorage("lf_filter_loss_ev") private var filterLossEV: Double = 0.0; @AppStorage("lf_flash_role_mode") private var flashRoleRaw: Int = 0; @AppStorage("lf_flash_zoom_mm") private var flashZoomMM: Int = 0; @AppStorage("lf_roll_number") private var currentRollNumber: Int = 1; @AppStorage("lf_current_frame") private var currentFrameNumber: Double = 1.0; @AppStorage("lf_roll_log_v93_json") private var rollLogJSON: String = "[]"; @AppStorage("lf_film_stock_id") private var selectedFilmStockID: String = "kodak_portra_400"; @AppStorage("lf_film_format") private var filmFormatRaw: Int = 0; @AppStorage("lf_log_location") private var currentLocationNote: String = ""; @AppStorage("lf_log_scene_note") private var currentSceneNote: String = ""; @State private var selectedFilmBrand: FilmBrandCategory = .kodak
@StateObject private var locationResolver = LocationAddressResolver.shared
@AppStorage("lf_lock_power") private var lockPower: Bool = false; @AppStorage("lf_lock_aperture") private var lockAperture: Bool = false; @AppStorage("lf_lock_distance") private var lockDistance: Bool = false; @AppStorage("lf_lock_shutter") private var lockShutter: Bool = false
@StateObject private var feedback = FeedbackEngine.shared
@State private var selectedParameter: DialParameter = .aperture; @State private var lastEditedParameter: DialParameter = .aperture; @State private var showOnboardingSheet: Bool = false; @State private var showCameraEVMeterSheet: Bool = false; @State private var showGuideSheet: Bool = false; @State private var guideInitialSection: Int = 0; @State private var lastSnappedEVComp: Double = 0.0
@StateObject private var cameraEVReader = CameraAmbientEVReader.shared
@State private var selectedTab: Int = 0; @State private var logSavedToast: String? = nil; @State private var expandedSettingsSection: Int = -1
private let allApertureSteps: [Double] = [
1.0, 1.2, 1.4, 1.8, 2.0, 2.8, 3.5, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0 ]
private let shutterSteps: [Int] = [
1, 2, 4, 8, 15, 30, 50, 60, 90, 100, 125, 200, 250, 500, 1000, 2000, 4000 ]
private let isoSteps: [Double] = [
50, 64, 100, 125, 160, 200, 250, 320, 400, 500, 800, 1600, 3200 ]
private let evCompSteps: [Double] = [
-2.0, -1.7, -1.3, -1.0, -0.7, -0.3, 0.0, 0.3, 0.7, 1.0, 1.3, 1.7, 2.0 ]
private let maxAperturePresets: [Double] = [1.0, 1.2, 1.4, 1.8, 2.0, 2.8, 3.5, 4.0, 5.6]
private let syncPresets: [Int] = [30, 50, 60, 90, 100, 125, 200, 250, 400, 500]
private var syncModeEnum: ShutterSyncMode { ShutterSyncMode(rawValue: syncModeRaw) ?? .focalPlaneMechanical }
private var cameraPresetEnum: CameraShutterPreset { CameraShutterPreset(rawValue: cameraPresetID) ?? .pentax67 }
private var effectiveMaxSyncSpeed: Int { syncModeEnum == .leafShutterLens ? max(maxSyncSpeed, 500) : maxSyncSpeed }
private let allPowerDenominators: [Int] = [1, 2, 4, 8, 16, 32, 64, 128, 256]
private let flashZoomPresets: [Int] = [0, 24, 28, 35, 50, 85, 105]
private let distanceSteps: [Double] = [
0.5, 0.7, 1.0, 1.2, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 7.0, 10.0, 15.0 ]
private let ambientSceneOptions: [PresetOption] = [
PresetOption("ev5", zh: "🌃 暗夜街拍/霓虹 (EV 5)", en: "🌃 Night Street / Neon (EV 5)", value: 5.0), PresetOption("ev6", zh: "🕯️ 昏暗酒吧/烛光 (EV 6)", en: "🕯️ Dim Bar / Candlelight (EV 6)", value: 6.0),
PresetOption("ev7", zh: "☕ 室内客厅/咖啡馆 (EV 7)", en: "☕ Indoor Cafe / Living Room (EV 7)", value: 7.0), PresetOption("ev9", zh: "🏢 明亮室内/商场 (EV 9)", en: "🏢 Bright Indoor / Office (EV 9)", value: 9.0),
PresetOption("ev11", zh: "🌿 树荫下/逆光人像 (EV 11)", en: "🌿 Open Shade / Backlight (EV 11)", value: 11.0), PresetOption("ev12", zh: "☁️ 户外阴天柔和光 (EV 12)", en: "☁️ Overcast Daylight (EV 12)", value: 12.0),
PresetOption("ev14", zh: "🌤️ 户外晴间多云 (EV 14)", en: "🌤️ Hazy / Bright Sun (EV 14)", value: 14.0), PresetOption("ev15", zh: "☀️ 晴天直射阳光 (EV 15)", en: "☀️ Direct Sunlight (EV 15)", value: 15.0) ]
private var flashRole: FlashRoleMode { FlashRoleMode(rawValue: flashRoleRaw) ?? .keyAutoSum }
private var powerDenominators: [Int] { let limit = selectedFlashModel.minPowerDenominator
let filtered = allPowerDenominators.filter { $0 <= limit }; return filtered.isEmpty ? [1, 2, 4, 8, 16, 32, 64, 128] : filtered }
private var zoomAdjustedGNAtISO100: Double { guard flashZoomMM > 0 else { return flashGN }
let rated = Double(max(selectedFlashModel.ratedZoomMM, 24)); let target = Double(max(flashZoomMM, 20))
if abs(target - rated) < 1.0 { return flashGN }
return max(3.0, flashGN * pow(target / rated, 0.35)) }
private func flashZoomMenuLabel(for mm: Int) -> String { if mm == 0 { return lang == .en
? "Rated (\(selectedFlashModel.ratedZoomMM)mm · GN\(Int(flashGN)))"
: "标称焦距 (\(selectedFlashModel.ratedZoomMM)mm · GN\(Int(flashGN)))" }
let eff = Int(round(flashGN * pow(Double(mm) / Double(max(selectedFlashModel.ratedZoomMM, 24)), 0.35))); return lang == .en ? "\(mm)mm Lens (Eff. GN\(eff))" : "\(mm)mm 镜头 (折算 GN\(eff))" }
private var filmFormat: FilmFormatType { FilmFormatType(rawValue: filmFormatRaw) ?? .f135 }
private var selectedFilmStock: FilmStockModel? { FilmStockModel.catalog.first(where: { $0.id == selectedFilmStockID }) }
private var currentFilmBadgeName: String { if let stock = selectedFilmStock { return "\(stock.name) (ISO \(Int(filmISO)))" }
return "Custom ISO \(Int(filmISO))" }
private var lang: AppLanguage { AppLanguage(rawValue: langRaw) ?? .zh }
private var selectedFlashModel: FlashUnitModel { if let found = FlashUnitModel.catalog.first(where: { $0.id == selectedFlashID }) { return found }
return FlashUnitModel.catalog.last! }
private var topBarFlashSummary: String { if selectedFlashID == "custom" { return lang == .en ? "Custom GN\(Int(flashGN))" : "自定义 GN\(Int(flashGN))" }
return "\(selectedFlashModel.shortBadge) GN\(Int(flashGN))" }
private var apertureSteps: [Double] { let filtered = allApertureSteps.filter { $0 >= maxLensAperture - 0.01 }; return filtered.isEmpty ? [maxLensAperture] : filtered }
private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .leicaBrushedBrass }
private var voicePersona: VoicePersona { VoicePersona(rawValue: voicePersonaRaw) ?? .magneticMale }
private var rollFrames: [FilmFrameRecord] { guard let data = rollLogJSON.data(using: .utf8), let decoded = try? JSONDecoder().decode([FilmFrameRecord].self, from: data) else { return [] }
return decoded }
private func saveRollFrames(_ list: [FilmFrameRecord]) { if let data = try? JSONEncoder().encode(list), let str = String(data: data, encoding: .utf8) { rollLogJSON = str }}
private var filterShortName: String { if abs(filterLossEV - 0.0) < 0.05 { return lang == .en ? "No Filter" : "无滤镜" }
if abs(filterLossEV - 0.3) < 0.05 { return "Mist -0.3" }
if abs(filterLossEV - 1.0) < 0.05 { return "CPL -1.0" }
if abs(filterLossEV - 2.0) < 0.05 { return "ND4 -2.0" }
if abs(filterLossEV - 3.0) < 0.05 { return "ND8 -3.0" }
return String(format: "-%.1fEV", filterLossEV) }
private func formatFStop(_ val: Double) -> String { if abs(val - round(val)) < 0.05 { return "f/\(Int(round(val)))" }
return String(format: "f/%.1f", val) }
private func setExposureCompClean(_ rawVal: Double) { let clamped = max(-2.0, min(2.0, rawVal))
if let closest = evCompSteps.min(by: { abs($0 - clamped) < abs($1 - clamped) }) { exposureCompEV = abs(closest) < 0.05 ? 0.0 : closest } else { exposureCompEV = 0.0 }}
private func stepExposureComp(by delta: Int) { if let idx = evCompSteps.enumerated().min(by: { abs($0.element - exposureCompEV) < abs($1.element - exposureCompEV) })?.offset {
let nextIdx = max(0, min(evCompSteps.count - 1, idx + delta))
exposureCompEV = evCompSteps[nextIdx] }}
private func computeFullEffectiveGN(forShutter shutter: Int) -> Double {
let effectiveISO = max(filmISO * pow(2.0, pushPullEV), 25.0); let isoFactor = sqrt(effectiveISO / 100.0); let effSync = effectiveMaxSyncSpeed; let hssStops = (syncModeEnum == .hssElectronic && shutter > effSync) ? log2(Double(shutter) / Double(effSync)) : 0.0; let hssLoss = hssStops > 0 ? (1.5 + 1.0 * hssStops) : 0.0; let closeUpLoss = filmFormat.closeUpLoss(at: distance); let roleBiasEV: Double
switch flashRole { case .fillNatural: roleBiasEV = -1.3
case .catchlightSoft: roleBiasEV = -2.0
default: roleBiasEV = 0.0 }
let totalLoss = modifierLossEV + bounceLossEV + filterLossEV + exposureCompEV + hssLoss + closeUpLoss + roleBiasEV; return zoomAdjustedGNAtISO100 * isoFactor * pow(2.0, -totalLoss / 2.0) }
private var lockedPowerFraction: Double { let idx = max(0, min(powerDenominators.count - 1, manualPowerIndex))
return 1.0 / Double(powerDenominators[idx]) }
private var lockedPowerText: String { let idx = max(0, min(powerDenominators.count - 1, manualPowerIndex)); let d = powerDenominators[idx]
return d == 1 ? "1/1" : "1/\(d)" }
private var exposureResult: (powerTitle: String, subNote: String, statusColor: Color, warningBanner: String?, ambientDiffEV: Double) {
let effSync = effectiveMaxSyncSpeed; let effGN = computeFullEffectiveGN(forShutter: shutterDenom); let maxApertureAtFull = effGN / max(distance, 0.3); let requiredRatio = aperture / max(maxApertureAtFull, 0.05); let effectiveISO = max(filmISO * pow(2.0, pushPullEV), 25.0); let leafEfficiencyLoss = (syncModeEnum == .leafShutterLens && shutterDenom >= 250 && aperture <= 4.0) ? 0.35 : 0.0; let cameraEV100 = log2((aperture * aperture) * Double(shutterDenom)) - log2(effectiveISO / 100.0) + leafEfficiencyLoss; let effectiveSceneEV = ambientEV100 - filterLossEV - exposureCompEV; let ambientDiffEV = effectiveSceneEV - cameraEV100
if syncModeEnum == .focalPlaneMechanical && shutterDenom > effSync { let curtainWarn = lang == .en
? "🚨 CURTAIN BLACKOUT! 1/\(shutterDenom)s exceeds body X-Sync 1/\(effSync)s — half the frame will be black! Set shutter ≤ 1/\(effSync)s or tap [LS Leaf 1/500s] if using a leaf-shutter lens."
: "🚨 快门帘遮挡黑边警告！当前 1/\(shutterDenom)s 超出机身幕帘同步上限 1/\(effSync)s，胶片将出现半幅死黑！请将快门调慢至 ≤ 1/\(effSync)s，若使用 90/165mm LS 等镜间快门镜头请点顶部【LS镜间 1/500s】。"
return (lang == .en ? "BLACKOUT!" : "🚨 帘幕黑边!", lang == .en ? "Exceeds 1/\(effSync)s Curtain Sync · Drop Shutter" : "超出 1/\(effSync)s 幕帘同步 · 必出半幅黑边", Color.red, curtainWarn, ambientDiffEV) }
let ambientContributionFactor: Double
if flashRole == .keyAutoSum && ambientDiffEV > -2.6 { let ambientLinear = pow(2.0, ambientDiffEV)
ambientContributionFactor = max(0.22, 1.0 - min(0.78, ambientLinear * 0.75)) } else { ambientContributionFactor = 1.0 }
let requiredPower = (requiredRatio * requiredRatio) * ambientContributionFactor
if lockPower { let availGN = effGN * sqrt(lockedPowerFraction); let achievedAperture = availGN / max(distance, 0.3); let evError = 2.0 * log2(achievedAperture / max(aperture, 0.1))
var advice: String? = nil
if evError < -0.35 { let neededDist = max(0.5, round((availGN / aperture) * 2.0) / 2.0)
advice = lang == .en
? String(format: "⚠️ Locked %@ underexposed (%.1f EV)! Open to %@ or move to %.1fm.", lockedPowerText, abs(evError), formatFStop(max(maxLensAperture, achievedAperture)), neededDist)
: String(format: "⚠️ 锁死 %@ 欠曝 %.1fEV！建议增大功率、开大光圈至 %@ 或靠近至 %.1fm。", lockedPowerText, abs(evError), formatFStop(max(maxLensAperture, achievedAperture)), neededDist)
} else if evError > 0.45 { let neededDist = min(15.0, round((availGN / aperture) * 2.0) / 2.0)
advice = lang == .en
? String(format: "⚠️ Locked %@ overexposed (+%.1f EV)! Stop down to %@ or step back to %.1fm.", lockedPowerText, evError, formatFStop(min(22.0, achievedAperture)), neededDist)
: String(format: "⚠️ 锁死 %@ 过曝 +%.1fEV！建议降低功率、收小光圈至 %@ 或后退至 %.1fm。", lockedPowerText, evError, formatFStop(min(22.0, achievedAperture)), neededDist) }
let statusCol: Color = abs(evError) <= 0.35 ? Color.green : (evError < 0 ? Color.red : Color.orange); let sub = abs(evError) <= 0.35
? (lang == .en ? "Locked Power Spot On · 1/\(shutterDenom)s · \(formatFStop(aperture)) · \(String(format: "%.1fm", distance))" : "锁定功率匹配良好 · 1/\(shutterDenom)s · \(formatFStop(aperture)) · \(String(format: "%.1fm", distance))")
: String(format: "%@ %+.1f EV · %@ / %.1fm", lang == .en ? "Bias" : "偏差", evError, formatFStop(achievedAperture), availGN / aperture)
return ("\(lockedPowerText) LOCKED", sub, statusCol, advice, ambientDiffEV) }
if requiredPower > 1.05 { let deficitStops = log2(requiredPower); let maxSafeDist = max(0.5, round((effGN / aperture) * 2.0) / 2.0); let warn = lang == .en
? String(format: "⚠️ Full power underexposed by %.1f EV! Open to %@ or move closer to %.1fm.", deficitStops, formatFStop(max(maxLensAperture, maxApertureAtFull)), maxSafeDist)
: String(format: "⚠️ 全功率仍欠曝 %.1f 档！请增大闪光灯功率、开大光圈至 %@ 或靠近至 %.1fm。", deficitStops, formatFStop(max(maxLensAperture, maxApertureAtFull)), maxSafeDist)
return ("OVER (>1/1)", String(format: "-%.1f EV · ≤ %.1fm", deficitStops, maxSafeDist), Color.red, warn, ambientDiffEV) }
let minDenom = selectedFlashModel.minPowerDenominator; let maxStopsDown = Int(round(log2(Double(minDenom)))); let minPowerFloor = 1.0 / Double(minDenom * 2)
if requiredPower < minPowerFloor { let warn = lang == .en
? "⚠️ Too close for 1/\(minDenom) min power! Stop down aperture, add ND filter, or step back."
: "⚠️ 距离过近，低于该闪光灯最低 1/\(minDenom) 档位！请收小光圈、加装 ND 镜或后退。"
return ("LOW (<1/\(minDenom))", lang == .en ? "Below 1/\(minDenom) min · Stop down" : "低于最低 1/\(minDenom) 档 · 请收小光圈", Color.orange, warn, ambientDiffEV) }
let rawStopsDown = log2(1.0 / requiredPower); let roundedStops = round(rawStopsDown * 3.0) / 3.0; let clampedWhole = max(0, min(maxStopsDown, Int(round(roundedStops)))); let denom = 1 << clampedWhole; let trimEV = Double(clampedWhole) - roundedStops; let baseFraction = denom == 1 ? "1/1" : "1/\(denom)"
var syncWarn: String? = nil
if shutterDenom > effSync { syncWarn = lang == .en
? "⚡ 1/\(shutterDenom)s exceeds 1/\(effSync)s X-Sync (HSS loss applied)."
: "⚡ 快门 1/\(shutterDenom)s 超出同步上限 1/\(effSync)s（已计入光损）。"
} else if syncModeEnum == .leafShutterLens && shutterDenom > maxSyncSpeed { syncWarn = lang == .en
? "🟢 Leaf-Shutter Lens Active: 1/\(shutterDenom)s full-frame sync (set body to 1/8s or X, lens ring to 1/\(shutterDenom)s)."
: "🟢 LS 镜间快门已开启：1/\(shutterDenom)s 全速同步生效（如 67II 机身请拨 1/8s 或 X 档，用镜头快门环控制 1/\(shutterDenom)s）。"
} else if ambientDiffEV > 0.3 { syncWarn = lang == .en
? String(format: "☀️ Ambient alone is %+.1f EV bright! Use faster shutter or smaller aperture.", ambientDiffEV)
: String(format: "☀️ 环境光已偏亮 %+.1f EV！叠加闪光易过曝，建议加快门或收小光圈。", ambientDiffEV) }
if abs(trimEV) < 0.14 { let prefix = lang == .en ? "Exact Step" : "精准整档"
return (baseFraction, "\(prefix) · \(formatFStop(aperture)) · 1/\(shutterDenom)s · \(String(format: "%.1fm", distance))", Color.green, syncWarn, ambientDiffEV) } else {
let trim = String(format: "%+.1f EV", trimEV); let prefix = lang == .en ? "1/3-Stop Trim" : "1/3档微调"
return ("\(baseFraction) (\(trim))", "\(prefix) · \(formatFStop(aperture)) · 1/\(shutterDenom)s · \(String(format: "%.1fm", distance))", theme.accent, syncWarn, ambientDiffEV) }}
private func solveForLockedPower(changed: DialParameter) { guard lockPower else { return }
let effGN = computeFullEffectiveGN(forShutter: shutterDenom); let targetGN = effGN * sqrt(lockedPowerFraction)
if changed != .aperture && !lockAperture { let idealAp = targetGN / max(distance, 0.3); let clampedAp = max(maxLensAperture, min(22.0, idealAp))
if let closest = apertureSteps.min(by: { abs($0 - clampedAp) < abs($1 - clampedAp) }) { aperture = closest }
} else if changed != .distance && !lockDistance { let idealDist = targetGN / max(aperture, 0.8)
if let closestDist = distanceSteps.min(by: { abs($0 - idealDist) < abs($1 - idealDist) }) { distance = closestDist }
} else if changed != .shutter && !lockShutter {
let effectiveISO = max(filmISO * pow(2.0, pushPullEV), 25.0); let targetShutterDouble = pow(2.0, ambientEV100 - filterLossEV - exposureCompEV + log2(effectiveISO / 100.0)) / max(aperture * aperture, 1.0); let maxAllowed = effectiveMaxSyncSpeed
let validSteps = shutterSteps.filter { $0 <= maxAllowed }
if let closest = (validSteps.isEmpty ? shutterSteps : validSteps).min(by: { abs(Double($0) - targetShutterDouble) < abs(Double($1) - targetShutterDouble) }) { shutterDenom = closest }}}
private func normalizeChineseNumbers(_ raw: String) -> String { var s = raw.lowercased()
let phraseReplacements: [(String, String)] = [
("四千", "4000"), ("两千", "2000"), ("二千", "2000"), ("一千六百", "1600"), ("一千", "1000"), ("八百", "800"), ("五百", "500"), ("四百", "400"), ("三百二", "320"), ("两百五", "250"), ("二百五", "250"),
("两百", "200"), ("二百", "200"), ("一百六", "160"), ("一百二十五", "125"), ("一百二", "125"), ("一百", "100"), ("六十", "60"), ("五十", "50"), ("三十", "30"), ("二十二", "22"), ("十六", "16"), ("十五", "15"),
("十三", "13"), ("十一", "11"), ("五点六", "5.6"), ("二点八", "2.8"), ("一点四", "1.4"), ("一点八", "1.8"),
("一点二", "1.2"), ("一点六", "1.6"), ("二点二", "2.2"), ("二点五", "2.5"), ("一点五", "1.5"), ("三点五", "3.5"), ("三点二", "3.2"), ("四点五", "4.5"), ("六点三", "6.3"), ("七点一", "7.1"), ("零点五", "0.5"), ("半米", "0.5米"), ("艾弗", "f"), ("エフ", "f") ]
for (k, v) in phraseReplacements { s = s.replacingOccurrences(of: k, with: v) }
let singleDigits: [(String, String)] = [
("一", "1"), ("二", "2"), ("两", "2"), ("三", "3"), ("四", "4"), ("五", "5"), ("六", "6"), ("七", "7"), ("八", "8"), ("九", "9"), ("十", "10") ]
for (k, v) in singleDigits { s = s.replacingOccurrences(of: k, with: v) }
s = s.replacingOccurrences(of: "点", with: ".")
return s }
private func applyVoiceCommand(_ transcript: String) { let text = normalizeChineseNumbers(transcript)
var matchedAny = false; var lastChanged: DialParameter? = nil; let shutterPatterns = [
"(?:快门速度|快门|shutter(?:\\s*speed)?)\\s*(?:1/)?(\\d{2,4})(?:\\s*分之一秒|\\s*秒)?", "(\\d{2,4})\\s*分之一秒?", "1/(\\d{2,4})\\s*秒?" ]
for pat in shutterPatterns { if let regex = try? NSRegularExpression(pattern: pat), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let r = Range(match.range(at: 1), in: text),
let val = Int(text[r]), val >= 10 && val <= 8000 { if let closest = shutterSteps.min(by: { abs($0 - val) < abs($1 - val) }) { withAnimation(.snappy) { shutterDenom = closest
selectedParameter = .shutter }
lastChanged = .shutter
matchedAny = true
break }}}
if let distRegex = try? NSRegularExpression(pattern: "(?:距离\\s*(\\d+(?:\\.\\d+)?)|(\\d+(?:\\.\\d+)?)\\s*(?:米|meters?|m\\b))"), let match = distRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
let r1 = Range(match.range(at: 1), in: text); let r2 = Range(match.range(at: 2), in: text)
if let str = (r1 != nil ? String(text[r1!]) : (r2 != nil ? String(text[r2!]) : nil)), let val = Double(str), val >= 0.4 && val <= 20.0 {
let snapped = distanceSteps.min(by: { abs($0 - val) < abs($1 - val) }) ?? max(0.5, min(15.0, round(val * 2.0) / 2.0))
withAnimation(.snappy) { distance = snapped
selectedParameter = .distance }
lastChanged = .distance
matchedAny = true }}
if let apRegex = try? NSRegularExpression(pattern: "(?:光圈|aperture\\s*|\\bf\\s*/?\\s*)(\\d+(?:\\.\\d+)?)"),
let match = apRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let r = Range(match.range(at: 1), in: text),
let val = Double(text[r]), val >= 1.0 && val <= 32.0 { let clamped = max(maxLensAperture, min(22.0, val))
if let closest = apertureSteps.min(by: { abs($0 - clamped) < abs($1 - clamped) }) { withAnimation(.snappy) { aperture = closest
selectedParameter = .aperture }
lastChanged = .aperture
matchedAny = true }}
if text.contains("全功率") || text.contains("full power") || text.contains("1/1") { withAnimation(.snappy) { manualPowerIndex = 0
lockPower = true
selectedParameter = .flashPower }
lastChanged = .flashPower
matchedAny = true
} else if let pRegex = try? NSRegularExpression(pattern: "(?:1/|功率\\s*(?:1/)?|power\\s*(?:1/)?)(\\d{1,3})\\s*(?:分之一)?"),
let match = pRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let r = Range(match.range(at: 1), in: text), let denomVal = Int(text[r]),
let idx = powerDenominators.firstIndex(of: denomVal) { withAnimation(.snappy) { manualPowerIndex = idx
lockPower = true
selectedParameter = .flashPower }
lastChanged = .flashPower
matchedAny = true
} else if let cnPowerRegex = try? NSRegularExpression(pattern: "(2|4|8|16|32|64|128)\\s*分之一(?!秒)"),
let match = cnPowerRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let r = Range(match.range(at: 1), in: text), let denomVal = Int(text[r]),
let idx = powerDenominators.firstIndex(of: denomVal) { withAnimation(.snappy) { manualPowerIndex = idx
lockPower = true
selectedParameter = .flashPower }
lastChanged = .flashPower
matchedAny = true }
if text.contains("纯闪光") || text.contains("全闪光") || text.contains("暗室") || text.contains("pure flash") { withAnimation(.snappy) { flashRoleRaw = FlashRoleMode.pureFlash.rawValue }
matchedAny = true
} else if text.contains("主光联动") || text.contains("主光") || text.contains("防过曝") || text.contains("key flash") || text.contains("auto balance") { withAnimation(.snappy) { flashRoleRaw = FlashRoleMode.keyAutoSum.rawValue }
matchedAny = true
} else if text.contains("眼神光") || text.contains("微补") || text.contains("catchlight") { withAnimation(.snappy) { flashRoleRaw = FlashRoleMode.catchlightSoft.rawValue }
matchedAny = true
} else if text.contains("自然补光") || text.contains("逆光补光") || text.contains("补光") || text.contains("fill flash") { withAnimation(.snappy) { flashRoleRaw = FlashRoleMode.fillNatural.rawValue }
matchedAny = true }
if text.contains("大太阳") || text.contains("烈日") || text.contains("晴天") || text.contains("阳光") || text.contains("海边") || text.contains("sunny") || text.contains("direct sun") { withAnimation(.snappy) { ambientEV100 = 15.0
if !text.contains("纯闪光") && !text.contains("主光") { flashRoleRaw = FlashRoleMode.fillNatural.rawValue }}
matchedAny = true
} else if text.contains("多云") || text.contains("晴间多云") || text.contains("hazy") || text.contains("cloudy") { withAnimation(.snappy) { ambientEV100 = 14.0 }
matchedAny = true
} else if text.contains("阴天") || text.contains("overcast") { withAnimation(.snappy) { ambientEV100 = 12.0 }
matchedAny = true
} else if text.contains("树荫") || text.contains("背阴") || text.contains("逆光") || text.contains("傍晚") || text.contains("夕阳") || text.contains("shade") || text.contains("backlight") || text.contains("sunset") {
withAnimation(.snappy) { ambientEV100 = 11.0
if text.contains("逆光") || text.contains("backlight") { flashRoleRaw = FlashRoleMode.fillNatural.rawValue }}
matchedAny = true
} else if text.contains("明亮室内") || text.contains("办公室") || text.contains("商场") || text.contains("窗边") || text.contains("office") || text.contains("mall") { withAnimation(.snappy) { ambientEV100 = 9.0 }
matchedAny = true
} else if text.contains("室内") || text.contains("客厅") || text.contains("咖啡") || text.contains("居家") || text.contains("indoor") || text.contains("cafe") { withAnimation(.snappy) { ambientEV100 = 7.0 }
matchedAny = true
} else if text.contains("酒吧") || text.contains("昏暗") || text.contains("烛光") || text.contains("暗光") || text.contains("bar") || text.contains("dim") || text.contains("candle") {
withAnimation(.snappy) { ambientEV100 = 6.0 }
matchedAny = true
} else if text.contains("夜景") || text.contains("夜晚") || text.contains("夜拍") || text.contains("霓虹") || text.contains("黑夜") || text.contains("night") || text.contains("neon") { withAnimation(.snappy) { ambientEV100 = 5.0 }
matchedAny = true }
if text.contains("归零") || text.contains("零补偿") || text.contains("reset ev") { withAnimation(.snappy) { setExposureCompClean(0.0) }
matchedAny = true
} else if let evPlusRegex = try? NSRegularExpression(pattern: "(?:加|正|过曝|plus\\s*)(\\d+(?:\\.\\d+)?)\\s*(?:档|ev)?"),
let match = evPlusRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let r = Range(match.range(at: 1), in: text),
let val = Double(text[r]), val <= 2.0 { withAnimation(.snappy) { setExposureCompClean(val) }
matchedAny = true
} else if let evMinusRegex = try? NSRegularExpression(pattern: "(?:减|负|欠曝|minus\\s*)(\\d+(?:\\.\\d+)?)\\s*(?:档|ev)?"),
let match = evMinusRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let r = Range(match.range(at: 1), in: text),
let val = Double(text[r]), val <= 2.0 { withAnimation(.snappy) { setExposureCompClean(-val) }
matchedAny = true }
if text.contains("肥皂盒") || text.contains("柔光罩") || text.contains("dome") { modifierLossEV = 1.0
matchedAny = true
} else if text.contains("柔光箱") || text.contains("softbox") { modifierLossEV = 2.0
matchedAny = true
} else if text.contains("裸灯") || text.contains("直闪") || text.contains("bare") { modifierLossEV = 0.0
bounceLossEV = 0.0
matchedAny = true }
if text.contains("跳闪") || text.contains("天花板") || text.contains("白顶") || text.contains("ceiling") { bounceLossEV = 2.0
matchedAny = true }
if matchedAny { if let changed = lastChanged { lastEditedParameter = changed
if lockPower { solveForLockedPower(changed: changed) }
} else if lockPower { solveForLockedPower(changed: .flashPower) }
syncWidgetDefaults() }}
private func syncWidgetDefaults() { let auxLoss = modifierLossEV + bounceLossEV + filterLossEV; let dict: [String: Double] = [
"lf_iso": filmISO, "lf_gn": flashGN, "lf_distance": distance, "lf_aperture": aperture, "lf_shutter": Double(shutterDenom), "lf_sync_speed": Double(maxSyncSpeed), "lf_theme": Double(themeRaw), "lf_film_format": Double(filmFormatRaw), "lf_sync_mode": Double(syncModeRaw), "lf_max_aperture": maxLensAperture, "lf_exp_comp_ev": exposureCompEV, "lf_aux_loss": auxLoss, "lf_sync_ts": Date().timeIntervalSince1970 ]
LocalLoopbackSyncBridge.shared.publishState(dict) }
private func applyRemoteWidgetDict(_ dict: [String: Double]) { if let t = dict["lf_theme"] { let ti = max(0, min(2, Int(round(t))))
if themeRaw != ti { themeRaw = ti }}
if let ap = dict["lf_aperture"] { let clamped = max(maxLensAperture, min(22.0, ap))
if abs(aperture - clamped) > 0.05 { aperture = clamped }}
if let sh = dict["lf_shutter"] { let si = max(1, min(4000, Int(round(sh))))
if shutterDenom != si { shutterDenom = si }}
if let dist = dict["lf_distance"] { let dc = max(0.5, min(15.0, dist))
if abs(distance - dc) > 0.05 { distance = dc }}
if let ev = dict["lf_exp_comp_ev"] { if abs(exposureCompEV - ev) > 0.05 { setExposureCompClean(ev) }}
if let iso = dict["lf_iso"] { if abs(filmISO - iso) > 0.5 { filmISO = iso }}}
private func pullFromWidgetStoreIfNewer() { for gid in LocalLoopbackSyncBridge.shared.discoveredGroups {
if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: gid)?.appendingPathComponent("lumifilm_v93.json"), let d = try? Data(contentsOf: url),
let dec = try? JSONDecoder().decode([String: Double].self, from: d) { applyRemoteWidgetDict(dec); return }}}
private func speakCurrentExposureOnce() { let msg = lang == .en
? "ISO \(Int(filmISO)), aperture \(formatFStop(aperture)), shutter 1 over \(shutterDenom), distance \(String(format: "%.1f", distance)) meters, flash power \(exposureResult.powerTitle)"
: "感光度 \(Int(filmISO))，光圈 \(formatFStop(aperture))，快门 \(shutterDenom) 分之一秒，距离 \(String(format: "%.1f", distance)) 米，建议闪光输出 \(exposureResult.powerTitle)"
if feedback.isSpeaking { feedback.toggleSpeakExposure(msg, soundEnabled: true, persona: voicePersona, lang: lang) }
feedback.toggleSpeakExposure(msg, soundEnabled: true, persona: voicePersona, lang: lang) }
private func triggerActionButtonVoiceFlow() { withAnimation(.snappy) { selectedTab = 0 }
feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
feedback.startVoiceFromShortcut(
lang: lang, onRecognized: { spokenText in
applyVoiceCommand(spokenText)
}, onAutoStoppedSpeak: { speakCurrentExposureOnce() } ) }
private func handleIncomingURL(_ url: URL) { guard url.scheme?.lowercased() == "lumifilm" else { return }
if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = comps.queryItems { for item in items { if let val = Double(item.value ?? "") {
switch item.name { case "ap": aperture = max(maxLensAperture, min(32.0, val))
case "dist": distance = max(0.5, min(15.0, val)); case "ev": setExposureCompClean(val); case "iso": filmISO = val; case "gn": flashGN = val; case "shutter": shutterDenom = max(2, min(8000, Int(round(val))))
case "theme": themeRaw = max(0, min(2, Int(round(val))))
default: break }}}}
let host = (url.host ?? "").lowercased()
if host.contains("voice") || host.contains("listen") { triggerActionButtonVoiceFlow() } else if host.contains("speak") { withAnimation(.snappy) { selectedTab = 0 }
DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { speakCurrentExposureOnce() }
} else if host.contains("onboarding") || host.contains("setup") || host.contains("guide") { withAnimation(.snappy) { showOnboardingSheet = true }} else { withAnimation(.snappy) { selectedTab = 0 }}
syncWidgetDefaults() }
private func checkPendingShortcutTriggers() { if UserDefaults.standard.bool(forKey: "lf_shortcut_trigger_voice") { UserDefaults.standard.set(false, forKey: "lf_shortcut_trigger_voice")
DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { triggerActionButtonVoiceFlow() }
} else if UserDefaults.standard.bool(forKey: "lf_shortcut_trigger_speak") { UserDefaults.standard.set(false, forKey: "lf_shortcut_trigger_speak")
DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { speakCurrentExposureOnce() }}}
private func recordCurrentFrameToLog() { feedback.lockToggleFeedback(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
let maxF = filmFormat.maxFrames; let fNum = max(1, min(maxF, Int(round(currentFrameNumber)))); let fmt = DateFormatter()
fmt.dateFormat = "MM-dd HH:mm"
let stockTitle = "\(selectedFilmStock?.name ?? "ISO \(Int(filmISO))") [\(filmFormat.shortTag)]"; var modParts: [String] = []
if modifierLossEV > 0.05 { modParts.append(String(format: "柔光-%.1f", modifierLossEV)) }
if bounceLossEV > 0.05 { modParts.append(String(format: "跳闪-%.1f", bounceLossEV)) }
if filterLossEV > 0.05 { modParts.append(filterShortName) }
let modSummary = modParts.isEmpty ? (lang == .en ? "Direct" : "直闪无滤镜") : modParts.joined(separator: "·"); let locStr = currentLocationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
? (lang == .en ? "Unmarked Location" : "未标注地点")
: currentLocationNote.trimmingCharacters(in: .whitespacesAndNewlines)
let noteStr = currentSceneNote.trimmingCharacters(in: .whitespacesAndNewlines); let entry = FilmFrameRecord(
frameNumber: fNum, filmStockName: stockTitle, aperture: aperture, shutterDenom: shutterDenom, distance: distance, powerLabel: exposureResult.powerTitle, iso: filmISO * pow(2.0, pushPullEV), evComp: exposureCompEV, filterName: modSummary, locationText: locStr, sceneNote: noteStr, timestamp: fmt.string(from: Date()) )
var list = rollFrames
if let existingIdx = list.firstIndex(where: { $0.frameNumber == fNum }) { list[existingIdx] = entry } else { list.append(entry)
list.sort { $0.frameNumber < $1.frameNumber }}
saveRollFrames(list)
withAnimation(.snappy) { logSavedToast = lang == .en
? String(format: "Saved #%02d (%@ · 1/%ds · %@)", fNum, formatFStop(aperture), shutterDenom, exposureResult.powerTitle)
: String(format: "已存 #%02d (%@ · 1/%ds · %@)", fNum, formatFStop(aperture), shutterDenom, exposureResult.powerTitle)
if fNum < maxF { currentFrameNumber = Double(fNum + 1) }}}
private var activeFilmMeshColors: (Color, Color) { (selectedFilmStock?.brand ?? .kodak).meshColors }
var body: some View { ZStack { LinearGradient(colors: theme.backgroundGradient, startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea().animation(.easeInOut(duration: 0.35), value: themeRaw)
Circle().fill(activeFilmMeshColors.0.opacity(0.28)).frame(width: 280, height: 280).blur(radius: 72).offset(x: -105, y: -210).animation(.easeInOut(duration: 0.65), value: selectedFilmStockID)
Circle().fill(activeFilmMeshColors.1.opacity(0.24)).frame(width: 260, height: 260).blur(radius: 72).offset(x: 115, y: 175).animation(.easeInOut(duration: 0.65), value: selectedFilmStockID)
VStack(spacing: 6) { headerBar.padding(.horizontal, 14).padding(.top, 2).frame(height: 44)
ZStack { if selectedTab == 0 { meterMainTab.transition(.opacity.combined(with: .scale(scale: 0.985)))
} else if selectedTab == 1 { modifiersTab.transition(.opacity.combined(with: .scale(scale: 0.985))) } else { settingsTab.transition(.opacity.combined(with: .scale(scale: 0.985)))
}}.animation(.spring(response: 0.34, dampingFraction: 0.82), value: selectedTab).padding(.horizontal, 14).frame(maxWidth: .infinity, maxHeight: .infinity)
VStack(spacing: 6) { appleMusicMiniRollBar.padding(.horizontal, 14).frame(height: 42)
appleMusicLiquidGlassBottomBar.padding(.horizontal, 16).frame(height: 58)
}.frame(height: 106).padding(.bottom, 2)
}.ignoresSafeArea(.keyboard, edges: .bottom) }.onAppear { if aperture < maxLensAperture { aperture = maxLensAperture }
setExposureCompClean(exposureCompEV)
feedback.refreshVoiceQualityStatus(persona: voicePersona, lang: lang)
syncWidgetDefaults()
if !hasCompletedOnboarding { showOnboardingSheet = true } else { checkPendingShortcutTriggers() }}.onOpenURL { url in
handleIncomingURL(url) }.onReceive(NotificationCenter.default.publisher(for: Notification.Name("LumiFilmActionVoiceTrigger"))) { _ in
UserDefaults.standard.set(false, forKey: "lf_shortcut_trigger_voice")
triggerActionButtonVoiceFlow() }.onReceive(NotificationCenter.default.publisher(for: Notification.Name("LumiFilmActionSpeakTrigger"))) { _ in
UserDefaults.standard.set(false, forKey: "lf_shortcut_trigger_speak")
speakCurrentExposureOnce() }.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
LocalLoopbackSyncBridge.shared.startServerIfNeeded()
pullFromWidgetStoreIfNewer()
checkPendingShortcutTriggers() }.onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
syncWidgetDefaults() }.onReceive(NotificationCenter.default.publisher(for: Notification.Name("LumiFilmWidgetRemoteSet"))) { note in
if let dict = note.userInfo as? [String: Double] { applyRemoteWidgetDict(dict) }}.onChange(of: aperture) { _, _ in
if lastEditedParameter == .aperture && lockPower { solveForLockedPower(changed: .aperture) }
syncWidgetDefaults() }.onChange(of: distance) { _, _ in
if lastEditedParameter == .distance && lockPower { solveForLockedPower(changed: .distance) }
syncWidgetDefaults() }.onChange(of: shutterDenom) { _, _ in
if lastEditedParameter == .shutter && lockPower { solveForLockedPower(changed: .shutter) }
syncWidgetDefaults() }.onChange(of: themeRaw) { _, _ in
syncWidgetDefaults() }.onChange(of: modifierLossEV) { _, _ in
syncWidgetDefaults() }.onChange(of: bounceLossEV) { _, _ in
syncWidgetDefaults() }.onChange(of: filterLossEV) { _, _ in
syncWidgetDefaults() }.onChange(of: filmISO) { _, _ in
syncWidgetDefaults() }.onChange(of: filmFormatRaw) { _, _ in
if currentFrameNumber > Double(filmFormat.maxFrames) { currentFrameNumber = Double(filmFormat.maxFrames) }
syncWidgetDefaults() }.onChange(of: flashGN) { _, _ in
syncWidgetDefaults() }.onChange(of: maxSyncSpeed) { _, _ in
syncWidgetDefaults() }.onChange(of: syncModeRaw) { _, _ in
syncWidgetDefaults() }.onChange(of: manualPowerIndex) { _, _ in
if lockPower { solveForLockedPower(changed: .flashPower) }}.onChange(of: exposureCompEV) { _, newVal in
let cleanVal: Double
if abs(newVal) < 0.14 { cleanVal = 0.0 } else { cleanVal = evCompSteps.min(by: { abs($0 - newVal) < abs($1 - newVal) }) ?? 0.0 }
if abs(cleanVal - newVal) > 0.005 { exposureCompEV = cleanVal }
if abs(cleanVal - lastSnappedEVComp) >= 0.15 { if abs(cleanVal) < 0.05 { feedback.zeroEVSnapFeedback(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled) } else {
feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled, magneticSnap: false) }
lastSnappedEVComp = cleanVal }
if lockPower { solveForLockedPower(changed: .flashPower) }
syncWidgetDefaults() }.sheet(isPresented: $showGuideSheet) { LumiFilmManualAndVoiceSheet(
initialTab: guideInitialSection, lang: lang, theme: theme ).presentationDetents([.large]) }.sheet(isPresented: $showCameraEVMeterSheet) { CameraAmbientMeterSheet(
ambientEV100: $ambientEV100, subjectDistance: $distance, lang: lang, theme: theme ).presentationDetents([.large]) }.sheet(isPresented: $showOnboardingSheet) { OnboardingSetupSheet(
filmISO: $filmISO, selectedFilmStockID: $selectedFilmStockID, filmFormatRaw: $filmFormatRaw, flashGN: $flashGN, selectedFlashID: $selectedFlashID, maxLensAperture: $maxLensAperture, maxSyncSpeed: $maxSyncSpeed, syncModeRaw: $syncModeRaw, cameraPresetID: $cameraPresetID, aperture: $aperture, themeRaw: $themeRaw, hasCompletedOnboarding: $hasCompletedOnboarding, lang: lang, theme: theme ).presentationDetents([.large]).interactiveDismissDisabled(!hasCompletedOnboarding) }}
private var currentFilmBrand: FilmBrandCategory { selectedFilmStock?.brand ?? .customISO }
private var headerBar: some View { HStack(spacing: 6) { Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { selectedTab = 2 }} label: { HStack(spacing: 5) { FilmBrandLogoBadge(brand: currentFilmBrand, compact: true)
Text("ISO \(Int(filmISO)) · \(filmFormat.shortTag) · \(formatFStop(maxLensAperture)) · GN\(Int(flashGN))").fMono(10.5, .bold).foregroundStyle(Color.white.opacity(0.92)).lineLimit(1).minimumScaleFactor(0.8)
}.padding(.horizontal, 9).frame(height: 32).background(Color.white.opacity(0.10), in: Capsule())
}.buttonStyle(.plain)
Spacer(minLength: 2)
Button { feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled, magneticSnap: true)
withAnimation(.snappy) { syncModeRaw = (syncModeEnum == .leafShutterLens) ? ShutterSyncMode.focalPlaneMechanical.rawValue : ShutterSyncMode.leafShutterLens.rawValue }} label: { HStack(spacing: 3.5) {
Image(systemName: syncModeEnum == .leafShutterLens ? "camera.aperture" : "rectangle.split.2x1.fill").fSys(10, .bold)
Text(syncModeEnum == .leafShutterLens ? (lang == .en ? "LS 1/500s" : "LS 1/500s") : (lang == .en ? "≤1/\(maxSyncSpeed)s" : "幕帘≤1/\(maxSyncSpeed)s")).fMono(10.5, .bold).lineLimit(1)
}.foregroundStyle(syncModeEnum == .leafShutterLens ? Color.black : (shutterDenom > effectiveMaxSyncSpeed ? Color.white : theme.accent)).padding(.horizontal, 9).frame(height: 32).background(syncModeEnum == .leafShutterLens ? Color.green : (shutterDenom > effectiveMaxSyncSpeed ? Color.red : Color.white.opacity(0.10)), in: Capsule())
}.buttonStyle(.plain)
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
feedback.toggleVoiceListening(lang: lang) { spokenText in applyVoiceCommand(spokenText) }} label: {
Image(systemName: feedback.isListening ? "waveform" : "mic.fill").fSys(11, .bold).foregroundStyle(Color.white).frame(width: 32, height: 32).background(feedback.isListening ? Color.red : Color.white.opacity(0.10), in: Circle()) }}}
private var meterMainTab: some View { VStack(spacing: 0) { flashOutputBannerCard
Spacer(minLength: 5)
parameterLockGridCard
Spacer(minLength: 5)
dedicatedExposureCompensationCard
Spacer(minLength: 5)
bottomDrumAndRightThumbConsoleCard.frame(maxHeight: .infinity)
}.frame(maxWidth: .infinity, maxHeight: .infinity) }
private var powerMainAndTrim: (main: String, trim: String?) { let raw = exposureResult.powerTitle
if let openIdx = raw.firstIndex(of: "("), let closeIdx = raw.firstIndex(of: ")"), openIdx < closeIdx {
let mainPart = String(raw[..<openIdx]).trimmingCharacters(in: .whitespaces); let trimPart = String(raw[raw.index(after: openIdx)..<closeIdx]).trimmingCharacters(in: .whitespaces); return (mainPart, trimPart) }
return (raw, nil) }
private var flashOutputBannerCard: some View {
let isCurtainAlert = (syncModeEnum == .focalPlaneMechanical && shutterDenom > effectiveMaxSyncSpeed); let bannerStroke: Color = isCurtainAlert ? Color.red : (lockPower ? theme.accent : Color.clear); let parts = powerMainAndTrim
return VStack(alignment: .leading, spacing: 4) { HStack(alignment: .center, spacing: 8) { VStack(alignment: .leading, spacing: 2) { HStack(spacing: 6) {
Text(lang == .en ? "FLASH OUTPUT" : "推荐闪光灯输出功率").fMono(9.5, .bold).foregroundStyle(Color.white.opacity(0.62))
if lockPower { Text(lang == .en ? "LOCKED" : "已锁定反推").fMono(8.5, .black).foregroundStyle(Color.black).padding(.horizontal, 5).padding(.vertical, 1.5).background(theme.accent, in: Capsule()) }}
HStack(alignment: .firstTextBaseline, spacing: 6) {
Text(parts.main).font(.system(size: 36, weight: .black, design: .monospaced)).foregroundStyle(isCurtainAlert ? Color.red : Color.white).lineLimit(1).minimumScaleFactor(0.75)
if let tr = parts.trim { Text(tr).fMono(12, .black).foregroundStyle(Color.black).padding(.horizontal, 7).padding(.vertical, 2.5).background(theme.accent, in: Capsule()) }
}.frame(height: 38, alignment: .leading) }
Spacer(minLength: 4)
VStack(alignment: .trailing, spacing: 5) { HStack(spacing: 5) { Button { feedback.lockToggleFeedback(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { lockPower.toggle()
if lockPower { selectedParameter = .flashPower; lastEditedParameter = .flashPower; solveForLockedPower(changed: .flashPower) }}} label: { HStack(spacing: 3) {
Image(systemName: lockPower ? "lock.fill" : "lock.open").fSys(10, .bold)
Text(lockPower ? (lang == .en ? "Locked" : "已锁功率") : (lang == .en ? "Lock" : "锁功率")).fSys(10.5, .bold)
}.foregroundStyle(lockPower ? Color.black : Color.white).padding(.horizontal, 9).padding(.vertical, 5).background(lockPower ? theme.accent : Color.white.opacity(0.12), in: Capsule()) }
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
let msg = lang == .en ? "ISO \(Int(filmISO)), aperture \(formatFStop(aperture)), shutter 1 over \(shutterDenom), distance \(String(format: "%.1f", distance)) meters, flash power \(exposureResult.powerTitle)" : "感光度 \(Int(filmISO))，光圈 \(formatFStop(aperture))，快门 \(shutterDenom) 分之一秒，距离 \(String(format: "%.1f", distance)) 米，闪光输出 \(exposureResult.powerTitle)"
feedback.toggleSpeakExposure(msg, soundEnabled: soundEnabled, persona: voicePersona, lang: lang) } label: {
Image(systemName: feedback.isSpeaking ? "stop.fill" : "speaker.wave.2.fill").fSys(10.5, .bold).foregroundStyle(Color.white).frame(width: 28, height: 28).background(feedback.isSpeaking ? Color.red : Color.white.opacity(0.12), in: Circle()) }}
HStack(spacing: 4) { Circle().fill(exposureResult.statusColor).frame(width: 6.5, height: 6.5)
Text(ambientBalanceBadgeText).fMono(10, .bold).foregroundStyle(Color.white.opacity(0.9))
}.padding(.horizontal, 8).padding(.vertical, 3).background(Color.black.opacity(0.26), in: Capsule()) }}
Group { if let warning = exposureResult.warningBanner { HStack(spacing: 4) { Image(systemName: "exclamationmark.triangle.fill").fSys(10, .bold).foregroundStyle(Color.yellow)
Text(warning).fSys(10, .semibold).foregroundStyle(Color.yellow).lineLimit(1).minimumScaleFactor(0.72) }} else { Text(exposureResult.subNote).fMono(10.5, .bold).foregroundStyle(exposureResult.statusColor).lineLimit(1) }
}.frame(height: 15, alignment: .leading)
}.padding(.horizontal, 14).padding(.vertical, 8).frame(height: 92).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(bannerStroke, lineWidth: isCurtainAlert || lockPower ? 1.6 : 0)) }
private func flashRoleRightThumbTile(_ role: FlashRoleMode) -> some View { let isSel: Bool = (flashRoleRaw == role.rawValue)
let iconName: String = role == .keyAutoSum ? "bolt.shield.fill" : (role == .fillNatural ? "sun.max.fill" : (role == .catchlightSoft ? "sparkles" : "moon.stars.fill"))
let shortTitle: String = role == .keyAutoSum ? (lang == .en ? "Key Auto-Sum" : "主光防过曝") : (role == .fillNatural ? (lang == .en ? "Natural Fill" : "逆光柔补光") : (role == .catchlightSoft ? (lang == .en ? "Catchlight" : "眼神光微补") : (lang == .en ? "Pure Flash" : "暗室纯闪光")))
let badgeTag: String = role == .keyAutoSum ? (lang == .en ? "0EV Sum" : "0EV联动") : (role == .fillNatural ? "-1.3 EV" : (role == .catchlightSoft ? "-2.0 EV" : (lang == .en ? "Full GN" : "GN全额")))
let descText: String = role == .keyAutoSum ? (lang == .en ? "Subtracts ambient to prevent blowouts" : "扣减环境光占比·防窗边/逆光过曝") : (role == .fillNatural ? (lang == .en ? "Softens backlit shadows, keeps mood" : "降1.3档柔化暗部·保留现场光氛围") : (role == .catchlightSoft ? (lang == .en ? "Subtle eye catchlight, zero flash look" : "降2.0档微闪点亮瞳孔·自然零闪光感") : (lang == .en ? "Standard darkroom/studio GN formula" : "暗室/棚拍标准GN直算·忽略环境光")))
let badgeBg: Color = isSel ? Color.black.opacity(0.16) : Color.white.opacity(0.10); let badgeFg: Color = isSel ? Color.black : theme.accent; return Button {
feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled, magneticSnap: true)
withAnimation(.snappy) { flashRoleRaw = role.rawValue
if lockPower { solveForLockedPower(changed: .flashPower) }
syncWidgetDefaults() }
} label: { VStack(alignment: .leading, spacing: 1.5) { HStack(spacing: 4) { Image(systemName: iconName).fSys(10.5, .bold).foregroundStyle(isSel ? Color.black : theme.accent)
Text(shortTitle).fSys(11, .black).lineLimit(1).minimumScaleFactor(0.8)
Spacer(minLength: 2)
Text(badgeTag).fMono(8.5, .black).foregroundStyle(badgeFg).padding(.horizontal, 5).padding(.vertical, 1.5).background(badgeBg, in: Capsule()) }
Text(descText).fSys(8.5, .semibold).foregroundStyle(isSel ? Color.black.opacity(0.76) : Color.white.opacity(0.56)).lineLimit(1).minimumScaleFactor(0.72)
}.foregroundStyle(isSel ? Color.black : Color.white).padding(.horizontal, 8).padding(.vertical, 3).frame(maxWidth: .infinity, maxHeight: .infinity).background(isSel ? theme.accent : Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 10))
}.buttonStyle(.plain) }
private var parameterLockGridCard: some View { LazyVGrid(columns: [GridItem(.flexible(), spacing: 7), GridItem(.flexible(), spacing: 7)], spacing: 7) {
lockableMetricTile(param: .distance, label: lang == .en ? "1. DISTANCE (∝ d²)" : "★ 距离 DISTANCE (最敏感)", value: String(format: "%.1f m", distance), isLocked: $lockDistance)
lockableMetricTile(param: .aperture, label: lang == .en ? "2. APERTURE (f/)" : "★ 光圈 APERTURE (控景深)", value: formatFStop(aperture), isLocked: $lockAperture)
lockableMetricTile(param: .shutter, label: lang == .en ? "3. SHUTTER (Amb)" : "快门 SHUTTER (控背景)", value: "1/\(shutterDenom)s", isLocked: $lockShutter)
lockableMetricTile(param: .flashPower, label: lang == .en ? "4. POWER" : "闪光功率 POWER", value: lockPower ? lockedPowerText : (lang == .en ? "AUTO" : "AUTO 自动"), isLocked: $lockPower) } }
private var dedicatedExposureCompensationCard: some View { HStack(spacing: 8) { Text(lang == .en ? "EV Bias" : "曝光补偿").fSys(11.5, .bold).foregroundStyle(Color.white.opacity(0.85)).fixedSize()
Button { feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { stepExposureComp(by: -1) }
} label: { Image(systemName: "minus").fSys(10.5, .black).foregroundStyle(Color.white).frame(width: 26, height: 26).background(Color.white.opacity(0.10), in: Circle()) }
Slider(value: $exposureCompEV, in: -2.0...2.0).tint(theme.accent)
Button { feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { stepExposureComp(by: 1) }
} label: { Image(systemName: "plus").fSys(10.5, .black).foregroundStyle(Color.white).frame(width: 26, height: 26).background(Color.white.opacity(0.10), in: Circle()) }
Button { feedback.zeroEVSnapFeedback(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { exposureCompEV = 0.0; lastSnappedEVComp = 0.0 }
} label: {
Text(abs(exposureCompEV) < 0.05 ? "0.0 EV" : String(format: "%+.1f EV", exposureCompEV)).fMono(11, .black).foregroundStyle(abs(exposureCompEV) < 0.05 ? Color.white.opacity(0.85) : Color.black).frame(width: 58, height: 26).background(abs(exposureCompEV) < 0.05 ? Color.white.opacity(0.10) : theme.accent, in: Capsule()) }
}.padding(.horizontal, 12).padding(.vertical, 6).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14)) }
private var appleMusicMiniRollBar: some View { HStack(spacing: 8) { Button { feedback.tabSwitchHaptic(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) { selectedTab = (selectedTab == 1) ? 0 : 1 }
} label: { HStack(spacing: 7) { FilmBrandLogoBadge(brand: currentFilmBrand, compact: false)
VStack(alignment: .leading, spacing: 1) { HStack(spacing: 4) { Text(selectedFilmStock?.name ?? "ISO \(Int(filmISO))").fSys(11, .black).foregroundStyle(Color.white).lineLimit(1)
Text("· \(filmFormat.shortTag)").fMono(9.5, .bold).foregroundStyle(theme.accent) }
Text(logSavedToast ?? String(format: "#%02d/%02d · %@ · 1/%ds · %@", Int(round(currentFrameNumber)), filmFormat.maxFrames, formatFStop(aperture), shutterDenom, powerMainAndTrim.main)).fMono(9.5, .semibold).foregroundStyle(logSavedToast != nil ? Color.green : Color.white.opacity(0.68)).lineLimit(1) } }
}.buttonStyle(.plain)
Spacer(minLength: 2)
Button { feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { currentFrameNumber = max(1.0, currentFrameNumber - 1.0) }
} label: { Image(systemName: "minus").fSys(10, .black).foregroundStyle(Color.white).frame(width: 24, height: 24).background(Color.white.opacity(0.10), in: Circle()) }
Button { recordCurrentFrameToLog() } label: { HStack(spacing: 4) { Image(systemName: "camera.shutter.button.fill").fSys(10.5, .bold)
Text(lang == .en ? "+1 Log" : "+1 快记").fSys(10.5, .black)
}.foregroundStyle(Color.black).padding(.horizontal, 10).padding(.vertical, 5.5).background(theme.accent, in: Capsule()) }
}.padding(.horizontal, 10).padding(.vertical, 5.5).background(.ultraThinMaterial, in: Capsule()) }
private var currentDrumItems: [String] { switch selectedParameter { case .aperture: return apertureSteps.map { formatFStop($0) }
case .distance: return distanceSteps.map { String(format: "%.1f m", $0) }; case .shutter: return shutterSteps.map { "1/\($0)s" }; case .flashPower: return powerDenominators.map { $0 == 1 ? "1/1" : "1/\($0)" } } }
private var currentDrumIndex: Int { switch selectedParameter { case .aperture: return apertureSteps.enumerated().min(by: { abs($0.element - aperture) < abs($1.element - aperture) })?.offset ?? 0
case .distance: return distanceSteps.enumerated().min(by: { abs($0.element - distance) < abs($1.element - distance) })?.offset ?? 0
case .shutter: return shutterSteps.enumerated().min(by: { abs($0.element - shutterDenom) < abs($1.element - shutterDenom) })?.offset ?? 0
case .flashPower: return max(0, min(powerDenominators.count - 1, manualPowerIndex)) } }
private var rightColumnFlashModesAndCameraButton: some View { VStack(alignment: .leading, spacing: 4.5) { HStack(spacing: 4) { Image(systemName: "bolt.badge.automatic.fill").fSys(9, .bold).foregroundStyle(theme.accent)
Text(lang == .en ? "FLASH MODE" : "闪光补光模式").fMono(9.5, .bold).foregroundStyle(Color.white.opacity(0.65))
Spacer(minLength: 0) }
VStack(spacing: 4) { ForEach(FlashRoleMode.allCases) { role in flashRoleRightThumbTile(role) }
}.frame(maxWidth: .infinity, maxHeight: .infinity)
Button { feedback.tabSwitchHaptic(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
showCameraEVMeterSheet = true
} label: { HStack(spacing: 7) { ZStack { Circle().fill(Color.black.opacity(0.22)).frame(width: 28, height: 28)
Image(systemName: "camera.fill").fSys(13, .black).foregroundStyle(Color.black) }
VStack(alignment: .leading, spacing: 1) { HStack(spacing: 4) { Text(lang == .en ? "Camera Meter" : "实景测光 · 测距").fSys(11.5, .black).foregroundStyle(Color.black).lineLimit(1)
if cameraEVReader.isRunning { Circle().fill(Color.green).frame(width: 5.5, height: 5.5) }}
Text(String(format: "EV %.1f · %.1fm", ambientEV100, distance)).fMono(9.5, .bold).foregroundStyle(Color.black.opacity(0.75)).lineLimit(1) }
Spacer(minLength: 0)
Image(systemName: "chevron.right").fSys(10, .black).foregroundStyle(Color.black.opacity(0.65))
}.padding(.horizontal, 9).frame(maxWidth: .infinity).frame(height: 40).background(LinearGradient(colors: [theme.accent, theme.secondaryAccent], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12)).shadow(color: theme.accent.opacity(0.25), radius: 5, x: 0, y: 2)
}.buttonStyle(.plain)
}.frame(maxWidth: .infinity, maxHeight: .infinity) }
private var bottomDrumAndRightThumbConsoleCard: some View { VStack(spacing: 6) { quickChipsBar
HStack(alignment: .center, spacing: 8) { iOSClockDrumWheelView(
items: currentDrumItems, selectedIndex: currentDrumIndex, parameterIcon: selectedParameter.icon, subtitleText: currentSelectedParameterSubtitle, theme: theme,
onStepChange: { delta in withAnimation(.snappy) { stepSelectedParameter(by: delta) } }
).frame(maxWidth: .infinity, maxHeight: .infinity)
Rectangle().fill(LinearGradient(colors: [Color.white.opacity(0.02), Color.white.opacity(0.18), theme.accent.opacity(0.28), Color.white.opacity(0.18), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom)).frame(width: 1).padding(.vertical, 6)
rightColumnFlashModesAndCameraButton
}.frame(maxHeight: .infinity)
}.padding(.horizontal, 10).padding(.vertical, 8).frame(maxWidth: .infinity, maxHeight: .infinity).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22)) }
private var ambientBalanceBadgeText: String { let diff = exposureResult.ambientDiffEV; let roleTag = flashRole.shortTag(for: lang)
if diff < -1.8 { return "\(roleTag) · EV\(Int(ambientEV100))" }
if diff <= 0.4 { return String(format: "%@(%+.1fEV)", roleTag, diff) }
return String(format: "%@(%+.1fEV)", lang == .en ? "Amb.High" : "环境亮", diff) }
private func lockableMetricTile(param: DialParameter, label: String, value: String, isLocked: Binding<Bool>) -> some View {
let isSelected = (selectedParameter == param); let strokeColor: Color = isSelected ? theme.accent : Color.clear; let iconColor: Color = isLocked.wrappedValue ? theme.accent : Color.white.opacity(0.42); let textColor: Color = isSelected ? theme.accent : Color.white; let valSize: CGFloat = isSelected ? 21.0 : 18.5
return VStack(alignment: .leading, spacing: 3) { HStack { Text(label).fMono(9.5, .bold).foregroundStyle(isSelected ? theme.accent.opacity(0.9) : Color.white.opacity(0.58)).lineLimit(1)
Spacer()
Button { feedback.lockToggleFeedback(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { isLocked.wrappedValue.toggle()
if param == .flashPower && isLocked.wrappedValue { selectedParameter = .flashPower; lastEditedParameter = .flashPower; solveForLockedPower(changed: .flashPower) }}} label: {
Image(systemName: isLocked.wrappedValue ? "lock.fill" : "lock.open").fSys(10.5, .bold).foregroundStyle(iconColor).padding(4).background(Color.white.opacity(0.08), in: Circle()) }}
HStack { Text(value).font(.system(size: valSize, weight: .black, design: .rounded)).foregroundStyle(textColor).lineLimit(1).minimumScaleFactor(0.75).contentTransition(.numericText())
Spacer() }} .padding(.horizontal, 12).padding(.vertical, 7.5).background(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(strokeColor, lineWidth: isSelected ? 1.6 : 0)).contentShape(Rectangle()).onTapGesture {
feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { selectedParameter = param
lastEditedParameter = param }}}
private var activeQuickChipID: String { switch selectedParameter { case .aperture: let closest = apertureSteps.min(by: { abs($0 - aperture) < abs($1 - aperture) }) ?? aperture
return "ap_\(Int(round(closest * 10)))"
case .distance: let closest = distanceSteps.min(by: { abs($0 - distance) < abs($1 - distance) }) ?? distance; return "dist_\(Int(round(closest * 10)))"
case .shutter: let closest = shutterSteps.min(by: { abs($0 - shutterDenom) < abs($1 - shutterDenom) }) ?? shutterDenom; return "sh_\(closest)"
case .flashPower: let idx = max(0, min(powerDenominators.count - 1, manualPowerIndex)); return "pw_\(idx)" }}
private var quickChipsBar: some View { ScrollViewReader { proxy in
ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 6) { switch selectedParameter { case .aperture: ForEach(apertureSteps, id: \.self) { step in
let active = abs(aperture - step) < 0.05; let chipID = "ap_\(Int(round(step * 10)))"
Button { guard !lockAperture else { return }
lastEditedParameter = .aperture
feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled, magneticSnap: true)
withAnimation(.snappy) { aperture = step
if lockPower { solveForLockedPower(changed: .aperture) }}} label: {
Text(formatFStop(step)).fMono(11, .bold).foregroundStyle(active ? Color.black : Color.white).padding(.horizontal, 10).padding(.vertical, 5).background(active ? theme.accent : Color.white.opacity(0.12), in: Capsule())
}.id(chipID) }
case .distance: ForEach(distanceSteps, id: \.self) { d in let active = abs(distance - d) < 0.08; let chipID = "dist_\(Int(round(d * 10)))"
Button { guard !lockDistance else { return }
lastEditedParameter = .distance
feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled, magneticSnap: true)
withAnimation(.snappy) { distance = d
if lockPower { solveForLockedPower(changed: .distance) }}} label: {
Text(String(format: "%.1fm", d)).fMono(11, .bold).foregroundStyle(active ? Color.black : Color.white).padding(.horizontal, 10).padding(.vertical, 5).background(active ? theme.accent : Color.white.opacity(0.12), in: Capsule())
}.id(chipID) }
case .shutter: ForEach(shutterSteps, id: \.self) { s in
let active = (shutterDenom == s); let overSync = s > effectiveMaxSyncSpeed; let fg: Color = active ? Color.black : (overSync ? (syncModeEnum == .focalPlaneMechanical ? Color.red : Color.orange) : Color.white); let chipID = "sh_\(s)"
Button { guard !lockShutter else { return }
lastEditedParameter = .shutter
feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled, magneticSnap: s == effectiveMaxSyncSpeed)
withAnimation(.snappy) { shutterDenom = s
if lockPower { solveForLockedPower(changed: .shutter) }}} label: {
Text("1/\(s)").fMono(11, .bold).foregroundStyle(fg).padding(.horizontal, 10).padding(.vertical, 5).background(active ? theme.accent : Color.white.opacity(0.12), in: Capsule())
}.id(chipID) }
case .flashPower: ForEach(0..<powerDenominators.count, id: \.self) { idx in
let d = powerDenominators[idx]; let label = d == 1 ? "1/1" : "1/\(d)"; let active = (manualPowerIndex == idx && lockPower); let chipID = "pw_\(idx)"
Button { lastEditedParameter = .flashPower
feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled, magneticSnap: true)
withAnimation(.snappy) { lockPower = true; manualPowerIndex = idx; solveForLockedPower(changed: .flashPower) }} label: {
Text(label).fMono(11, .bold).foregroundStyle(active ? Color.black : Color.white).padding(.horizontal, 10).padding(.vertical, 5).background(active ? theme.accent : Color.white.opacity(0.12), in: Capsule())
}.id(chipID) }}}}.onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { withAnimation(.snappy) { proxy.scrollTo(activeQuickChipID, anchor: .center) }}}.onChange(of: selectedParameter) { _, _ in
DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { withAnimation(.snappy) { proxy.scrollTo(activeQuickChipID, anchor: .center) }}}.onChange(of: aperture) { _, _ in
withAnimation(.snappy) { proxy.scrollTo(activeQuickChipID, anchor: .center) }}.onChange(of: distance) { _, _ in
withAnimation(.snappy) { proxy.scrollTo(activeQuickChipID, anchor: .center) }}.onChange(of: shutterDenom) { _, _ in
withAnimation(.snappy) { proxy.scrollTo(activeQuickChipID, anchor: .center) }}.onChange(of: manualPowerIndex) { _, _ in
withAnimation(.snappy) { proxy.scrollTo(activeQuickChipID, anchor: .center) }}}}
private var currentSelectedParameterSubtitle: String { switch selectedParameter { case .aperture: return lockAperture
? (lang == .en ? "🔒 Aperture Locked" : "🔒 光圈已锁定 (点卡片解锁)")
: (lang == .en ? "Lens Limit ≥ \(formatFStop(maxLensAperture))" : "镜头限制 ≥ \(formatFStop(maxLensAperture))")
case .distance: return lockDistance
? (lang == .en ? "🔒 Distance Locked" : "🔒 距离已锁定 (点卡片解锁)")
: (lang == .en ? "🧲 0.5m Magnetic Snap Dial" : "🧲 0.5m 磁铁吸附转盘调节")
case .shutter: return lockShutter
? (lang == .en ? "🔒 Shutter Locked" : "🔒 快门已锁定")
: (shutterDenom > effectiveMaxSyncSpeed
? (syncModeEnum == .focalPlaneMechanical
? (lang == .en ? "🚨 Curtain Blackout (>1/\(effectiveMaxSyncSpeed)s)!" : "🚨 幕帘遮挡黑边 (>1/\(effectiveMaxSyncSpeed)s)!")
: (lang == .en ? "⚡ HSS High-Speed Sync" : "⚡ HSS 高速同步区间"))
: (syncModeEnum == .leafShutterLens
? (lang == .en ? "🟢 LS Leaf Full Sync ≤ 1/500s" : "🟢 LS 镜间快门全同步 ≤ 1/500s")
: (lang == .en ? "Safe Sync ≤ 1/\(effectiveMaxSyncSpeed)s" : "安全同步 ≤ 1/\(effectiveMaxSyncSpeed)s")))
case .flashPower: return lockPower
? (lang == .en ? "🔒 Power Locked · Auto-solving f/ & Dist" : "🔒 已锁功率 · 自动解算光圈与距离")
: (lang == .en ? "Turn dial to lock manual power" : "转动波轮即可锁定输出功率") }}
private func stepSelectedParameter(by delta: Int) { lastEditedParameter = selectedParameter
switch selectedParameter { case .aperture: guard !lockAperture else { feedback.lockToggleFeedback(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
return }
let steps = apertureSteps
if let idx = steps.enumerated().min(by: { abs($0.element - aperture) < abs($1.element - aperture) })?.offset { let next = max(0, min(steps.count - 1, idx + delta))
if next != idx { aperture = steps[next]
feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
if lockPower { solveForLockedPower(changed: .aperture) }}}
case .distance: guard !lockDistance else { feedback.lockToggleFeedback(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled); return }
if let idx = distanceSteps.enumerated().min(by: { abs($0.element - distance) < abs($1.element - distance) })?.offset { let nextIdx = max(0, min(distanceSteps.count - 1, idx + delta))
if nextIdx != idx { distance = distanceSteps[nextIdx]
feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled, magneticSnap: true)
if lockPower { solveForLockedPower(changed: .distance) }}}
case .shutter: guard !lockShutter else { feedback.lockToggleFeedback(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled); return }
if let idx = shutterSteps.firstIndex(of: shutterDenom) { let next = max(0, min(shutterSteps.count - 1, idx + delta))
if next != idx { shutterDenom = shutterSteps[next]
feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled, magneticSnap: shutterDenom == maxSyncSpeed)
if lockPower { solveForLockedPower(changed: .shutter) }}} else { shutterDenom = 125 }
case .flashPower: lockPower = true; let next = max(0, min(powerDenominators.count - 1, manualPowerIndex + delta))
if next != manualPowerIndex { manualPowerIndex = next
feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled, magneticSnap: true)
solveForLockedPower(changed: .flashPower) }}}
private var modifiersTab: some View { ScrollView(showsIndicators: false) { VStack(spacing: 10) { modifiersLiveSummaryBanner
opticalModifiers2x2Grid
compactFilmRollLogCard } .padding(.bottom, 6) }}
private var modifiersLiveSummaryBanner: some View {
let bellowsLoss = filmFormat.closeUpLoss(at: distance); let totalOpticalLoss = modifierLossEV + bounceLossEV + filterLossEV + bellowsLoss; let effISO = Int(round(max(filmISO * pow(2.0, pushPullEV), 25.0))); let effGN = Int(round(computeFullEffectiveGN(forShutter: shutterDenom)))
return HStack(spacing: 10) { VStack(alignment: .leading, spacing: 3) { HStack(spacing: 5) { Image(systemName: "bolt.circle.fill").fSys(11, .bold).foregroundStyle(theme.accent)
Text(lang == .en ? "MODIFIED FLASH OUTPUT" : "光学修正后建议功率").fMono(9.5, .black).foregroundStyle(theme.accent) }
Text(exposureResult.powerTitle).font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(exposureResult.statusColor == .red ? Color.red : Color.white).lineLimit(1).minimumScaleFactor(0.75) }
Spacer(minLength: 4)
VStack(alignment: .trailing, spacing: 4) { HStack(spacing: 5) {
Text(String(format: lang == .en ? "Loss -%.1fEV" : "附件光损 -%.1fEV", totalOpticalLoss)).fMono(10, .bold).foregroundStyle(totalOpticalLoss > 0.05 ? Color.black : Color.white.opacity(0.8)).padding(.horizontal, 7).padding(.vertical, 3).background(totalOpticalLoss > 0.05 ? theme.accent : Color.white.opacity(0.12), in: Capsule())
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { modifierLossEV = 0.0
bounceLossEV = 0.0
filterLossEV = 0.0
pushPullEV = 0.0 }} label: { Text(lang == .en ? "Reset" : "归零").fSys(10, .black).foregroundStyle(theme.accent).padding(.horizontal, 8).padding(.vertical, 3).background(Color.white.opacity(0.12), in: Capsule()) }}
Text(lang == .en ? "EI \(effISO) · Eff. GN \(effGN) · \(formatFStop(aperture)) · \(String(format: "%.1fm", distance))" : "折算 EI \(effISO) · 有效 GN \(effGN) · \(formatFStop(aperture)) · \(String(format: "%.1fm", distance))").fMono(9.5, .semibold).foregroundStyle(Color.white.opacity(0.65)).lineLimit(1) }} .padding(.horizontal, 13).padding(.vertical, 10).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18)) }
private var opticalModifiers2x2Grid: some View { VStack(spacing: 8) { HStack(spacing: 8) { diffuserBentoTile
bounceBentoTile }
HStack(spacing: 8) { filterBentoTile
pushPullBentoTile }}}
private var diffuserBentoTile: some View { let active: Bool = modifierLossEV > 0.05; let badge: String = active ? String(format: "-%.1f EV", modifierLossEV) : "0 EV"
return modifierTileContainer(icon: "light.beacon.max.fill", title: lang == .en ? "Diffuser" : "柔光附件", badgeText: badge, isActive: active) { VStack(spacing: 5) { HStack(spacing: 5) {
modifierChipButton(label: lang == .en ? "Bare 0" : "裸灯 0", target: 0.0, selection: $modifierLossEV)
modifierChipButton(label: lang == .en ? "Dome -1" : "肥皂盒 -1", target: 1.0, selection: $modifierLossEV) }
HStack(spacing: 5) { modifierChipButton(label: lang == .en ? "Sphere -1.5" : "球形 -1.5", target: 1.5, selection: $modifierLossEV)
modifierChipButton(label: lang == .en ? "Softbox -2" : "柔光箱 -2", target: 2.0, selection: $modifierLossEV) }}}}
private var bounceBentoTile: some View { let active: Bool = bounceLossEV > 0.05; let badge: String = active ? String(format: "-%.1f EV", bounceLossEV) : "0 EV"
return modifierTileContainer(icon: "arrow.up.right.circle.fill", title: lang == .en ? "Bounce" : "跳闪角度", badgeText: badge, isActive: active) { VStack(spacing: 5) { HStack(spacing: 5) {
modifierChipButton(label: lang == .en ? "Direct 0°" : "0°直闪", target: 0.0, selection: $bounceLossEV)
modifierChipButton(label: lang == .en ? "60° -1.5" : "60°眼神板", target: 1.5, selection: $bounceLossEV) }
HStack(spacing: 5) { modifierChipButton(label: lang == .en ? "90° -2.0" : "90°白顶", target: 2.0, selection: $bounceLossEV)
modifierChipButton(label: lang == .en ? "Wall -2.5" : "反跳白墙", target: 2.5, selection: $bounceLossEV) }}}}
private var filterBentoTile: some View { let active: Bool = filterLossEV > 0.05; let badge: String = active ? String(format: "-%.1f EV", filterLossEV) : "0 EV"
return modifierTileContainer(icon: "circle.hexagongrid.fill", title: lang == .en ? "Lens Filter" : "镜头滤镜", badgeText: badge, isActive: active) { VStack(spacing: 5) { HStack(spacing: 5) {
modifierChipButton(label: lang == .en ? "None 0" : "无滤镜", target: 0.0, selection: $filterLossEV)
modifierChipButton(label: lang == .en ? "Mist -0.3" : "黑柔-0.3", target: 0.3, selection: $filterLossEV) }
HStack(spacing: 5) { modifierChipButton(label: lang == .en ? "CPL -1" : "CPL/黄-1", target: 1.0, selection: $filterLossEV)
modifierChipButton(label: "ND4 -2", target: 2.0, selection: $filterLossEV)
modifierChipButton(label: "ND8 -3", target: 3.0, selection: $filterLossEV) }}}}
private var pushPullBentoTile: some View { let active: Bool = abs(pushPullEV) > 0.05; let badge: String = active ? String(format: "%+.0f EV", pushPullEV) : "EI \(Int(filmISO))"
return modifierTileContainer(icon: "film.stack.fill", title: lang == .en ? "Push / Pull" : "迫冲与减感", badgeText: badge, isActive: active) { VStack(spacing: 5) { HStack(spacing: 5) {
modifierChipButton(label: lang == .en ? "Pull -1" : "减感 -1", target: -1.0, selection: $pushPullEV)
modifierChipButton(label: lang == .en ? "Box 0" : "标准 0", target: 0.0, selection: $pushPullEV) }
HStack(spacing: 5) { modifierChipButton(label: lang == .en ? "Push +1" : "迫冲 +1", target: 1.0, selection: $pushPullEV)
modifierChipButton(label: lang == .en ? "Push +2" : "迫冲 +2", target: 2.0, selection: $pushPullEV) }}}}
private func modifierTileContainer<Content: View>(icon: String, title: String, badgeText: String, isActive: Bool, @ViewBuilder content: () -> Content) -> some View {
let badgeFg: Color = isActive ? Color.black : Color.white.opacity(0.75); let badgeBg: Color = isActive ? theme.accent : Color.white.opacity(0.12); let strokeCol: Color = isActive ? theme.accent.opacity(0.55) : Color.white.opacity(0.16)
return VStack(alignment: .leading, spacing: 7) { HStack(spacing: 4) { Image(systemName: icon).fSys(11.5, .bold).foregroundStyle(theme.accent)
Text(title).fSys(12, .bold).foregroundStyle(Color.white).lineLimit(1)
Spacer(minLength: 2)
Text(badgeText).fMono(9.5, .black).foregroundStyle(badgeFg).padding(.horizontal, 6).padding(.vertical, 2).background(badgeBg, in: Capsule()) }
content() } .padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(strokeCol, lineWidth: 1.0)) }
private func modifierChipButton(label: String, target: Double, selection: Binding<Double>) -> some View {
let selected: Bool = abs(selection.wrappedValue - target) < 0.05; let fg: Color = selected ? Color.black : Color.white.opacity(0.88); let bg: Color = selected ? theme.accent : Color.white.opacity(0.10); let border: Color = selected ? Color.white.opacity(0.6) : Color.white.opacity(0.12); let weight: Font.Weight = selected ? .black : .semibold
return Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { selection.wrappedValue = target }} label: {
Text(label).font(.system(size: 10.5, weight: weight, design: .rounded)).foregroundStyle(fg).lineLimit(1).minimumScaleFactor(0.72).frame(maxWidth: .infinity).padding(.vertical, 6.5).background(bg, in: RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).stroke(border, lineWidth: 0.8)) }}
private var exportedRollMarkdown: String {
let stockName = selectedFilmStock?.name ?? "Custom ISO \(Int(filmISO))"; let header = String(format: "# LumiFilm Roll #%02d · %@ (ISO %.0f) · %@\nFrame | Film Stock | Aperture | Shutter | Flash Power | Dist | EI | Modifiers | Location | Note | Time\n",
currentRollNumber, stockName, filmISO, topBarFlashSummary)
let rows = rollFrames.map { String(format: "#%02d | %@ | %@ | 1/%ds | %@ | %.1fm | EI %.0f | %@ | 📍%@ | %@ | %@",
$0.frameNumber, $0.filmStockName, formatFStop($0.aperture), $0.shutterDenom, $0.powerLabel, $0.distance, $0.iso, $0.filterName, $0.locationText, $0.sceneNote.isEmpty ? "-" : $0.sceneNote, $0.timestamp)
}.joined(separator: "\n")
return header + rows }
private var compactFilmRollLogCard: some View { let stockTitle = selectedFilmStock?.name ?? "ISO \(Int(filmISO))"
return VStack(alignment: .leading, spacing: 9) { HStack { Label(
lang == .en
? String(format: "Roll #%02d · %@", currentRollNumber, stockTitle)
: String(format: "第 #%02d 卷 · %@", currentRollNumber, stockTitle), systemImage: "film.stack.fill" ).fSys(12.5, .bold).foregroundStyle(Color.white).lineLimit(1)
Spacer()
Text("\(filmFormat.shortTag) · \(rollFrames.count)/\(filmFormat.maxFrames) 张").fMono(11, .bold).foregroundStyle(theme.accent) }
VStack(spacing: 6) { HStack(spacing: 6) { Image(systemName: "location.fill").fSys(11, .bold).foregroundStyle(theme.accent)
TextField(lang == .en ? "Location / Street / City..." : "拍摄地址（如：悉尼歌剧院 / 武康路）", text: $currentLocationNote).fSys(11.5, .semibold).foregroundStyle(Color.white)
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
locationResolver.fetchCurrentPlace { place in
currentLocationNote = place }} label: { HStack(spacing: 3) { Image(systemName: locationResolver.isLocating ? "location.circle.fill" : "location.viewfinder").fSys(10.5, .bold)
Text(locationResolver.isLocating ? (lang == .en ? "Locating" : "定位中") : (lang == .en ? "GPS" : "自动定位")).fSys(10, .bold) } .foregroundStyle(Color.black).padding(.horizontal, 8).padding(.vertical, 4.5).background(theme.accent, in: Capsule()) }} .padding(.horizontal, 9).padding(.vertical, 5.5).background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 10))
HStack(spacing: 6) { Image(systemName: "pencil.and.list.clipboard").fSys(11, .bold).foregroundStyle(theme.secondaryAccent)
TextField(lang == .en ? "Scene / Lens note (e.g. 35mm f/1.4 portrait)..." : "画面或器材备注（如：35mm 逆光人像 / 街拍）", text: $currentSceneNote).fSys(11.5, .semibold).foregroundStyle(Color.white)
if !currentSceneNote.isEmpty { Button { currentSceneNote = "" } label: {
Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.45)) }}} .padding(.horizontal, 9).padding(.vertical, 5.5).background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 10)) }
HStack(spacing: 6) { Button { recordCurrentFrameToLog() } label: {
Label(lang == .en ? String(format: "Log #%02d", Int(round(currentFrameNumber))) : String(format: "记下第 #%02d 张", Int(round(currentFrameNumber))), systemImage: "plus.circle.fill").fSys(11, .black).foregroundStyle(Color.black).padding(.horizontal, 11).padding(.vertical, 6).background(theme.accent, in: Capsule()) }
if !rollFrames.isEmpty { ShareLink(item: exportedRollMarkdown) {
Label(lang == .en ? "Export" : "导出分享", systemImage: "square.and.arrow.up").fSys(10.5, .bold).foregroundStyle(Color.white).padding(.horizontal, 9).padding(.vertical, 6).background(Color.white.opacity(0.14), in: Capsule()) }
Button { UIPasteboard.general.string = exportedRollMarkdown
logSavedToast = lang == .en ? "Copied Roll #\(currentRollNumber)" : "已复制第 #\(currentRollNumber) 卷手账" } label: {
Image(systemName: "doc.on.doc.fill").fSys(10.5, .bold).foregroundStyle(Color.white).padding(6).background(Color.white.opacity(0.14), in: Circle()) }}
Spacer()
Button { feedback.lockToggleFeedback(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { currentRollNumber += 1
saveRollFrames([])
currentFrameNumber = 1.0 }} label: { HStack(spacing: 3) { Image(systemName: "film.fill").font(.system(size: 10))
Text(lang == .en ? "New Roll" : "换新卷").fSys(10.5, .bold) } .foregroundStyle(theme.accent).padding(.horizontal, 9).padding(.vertical, 5.5).background(Color.white.opacity(0.10), in: Capsule()) }}
if rollFrames.isEmpty { Text(lang == .en
? "No frames logged yet. Enter a location/note above or tap 'Log Frame' to record film stock, flash power, aperture, shutter, and GPS address."
: "暂无手账记录。可先点「自动定位」获取当前街道地址或填写备注，再点击「记下第 #01 张」完整保存胶卷型号、闪光功率、光圈快门与拍摄地点。").font(.system(size: 10.5)).foregroundStyle(Color.white.opacity(0.62)).padding(.vertical, 3) } else {
VStack(spacing: 6) { ForEach(rollFrames) { item in
loggedFrameRowView(item) }}}} .padding(13).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20)) }
private func loggedFrameRowView(_ item: FilmFrameRecord) -> some View { VStack(alignment: .leading, spacing: 3) { HStack(spacing: 5) {
Text(String(format: "#%02d", item.frameNumber)).fMono(10.5, .black).foregroundStyle(Color.black).padding(.horizontal, 5.5).padding(.vertical, 1.5).background(theme.accent, in: Capsule())
FilmBrandLogoBadge(brand: FilmBrandCategory.detect(from: item.filmStockName), compact: true)
Text(item.filmStockName).fSys(11, .heavy).foregroundStyle(theme.accent).lineLimit(1)
Spacer(minLength: 2)
Text(item.powerLabel).fMono(11, .black).foregroundStyle(Color.white)
Text(item.timestamp).fMono(9, .medium).foregroundStyle(Color.white.opacity(0.52))
Button { var list = rollFrames
list.removeAll { $0.id == item.id }
saveRollFrames(list) } label: { Image(systemName: "trash").fSys(10, .bold).foregroundStyle(Color.white.opacity(0.45)) }}
HStack(spacing: 6) { Text("\(formatFStop(item.aperture)) · 1/\(item.shutterDenom)s · \(String(format: "%.1fm", item.distance)) · EI \(Int(item.iso))").fMono(10.5, .bold).foregroundStyle(Color.white.opacity(0.9))
Spacer(minLength: 2)
Text(item.filterName).fSys(9.5, .semibold).foregroundStyle(Color.white.opacity(0.62)).lineLimit(1) }
HStack(spacing: 8) { Label(item.locationText, systemImage: "mappin.and.ellipse").fSys(9.5, .semibold).foregroundStyle(theme.secondaryAccent).lineLimit(1)
if !item.sceneNote.isEmpty {
Text("· \(item.sceneNote)").fSys(9.5, .medium).foregroundStyle(Color.white.opacity(0.75)).lineLimit(1) }}} .padding(.horizontal, 9).padding(.vertical, 7).background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 11)) }
private func collapsibleSettingsRowHeader(id: Int, icon: String, title: String, valueSummary: String) -> some View { let isOpen: Bool = (expandedSettingsSection == id)
return Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { expandedSettingsSection = isOpen ? -1 : id }} label: { HStack(spacing: 10) { Image(systemName: icon).fSys(14, .bold).foregroundStyle(theme.accent).frame(width: 24)
Text(title).fSys(13.5, .bold).foregroundStyle(Color.white).lineLimit(1)
Spacer(minLength: 4)
Text(valueSummary).fMono(11, .bold).foregroundStyle(theme.accent).lineLimit(1)
Image(systemName: isOpen ? "chevron.up" : "chevron.down").fSys(11, .bold).foregroundStyle(Color.white.opacity(0.5))
}.padding(.horizontal, 14).padding(.vertical, 13).background(Color.white.opacity(isOpen ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 15))
}.buttonStyle(.plain) }
private var settingsTab: some View { ScrollView(showsIndicators: false) { VStack(spacing: 8) {
collapsibleSettingsRowHeader(id: 0, icon: "bolt.fill", title: lang == .en ? "01. Flash Model & GN" : "01. 热靴闪光灯型号与指数", valueSummary: "GN \(Int(flashGN))")
if expandedSettingsSection == 0 { flashHardwareSettingsCard.transition(.opacity.combined(with: .move(edge: .top))) }
collapsibleSettingsRowHeader(id: 1, icon: "film.stack", title: lang == .en ? "02. Film Stock, ISO & Shutter" : "02. 胶卷型号、画幅与机身快门", valueSummary: "ISO \(Int(filmISO)) · \(filmFormat.shortTag) · ≤1/\(effectiveMaxSyncSpeed)s")
if expandedSettingsSection == 1 { cameraAndFilmBaseSettingsCard.transition(.opacity.combined(with: .move(edge: .top))) }
collapsibleSettingsRowHeader(id: 2, icon: "waveform.and.mic", title: lang == .en ? "03. Voice, Haptics & Language" : "03. 语音播报、触感与界面语言", valueSummary: "\(lang.displayName) · \(soundEnabled ? "🔊" : "🔇")")
if expandedSettingsSection == 2 { audioHapticsAndSystemSettingsCard.transition(.opacity.combined(with: .move(edge: .top))) }
collapsibleSettingsRowHeader(id: 3, icon: "paintpalette.fill", title: lang == .en ? "04. Theme, Guide & Wizard" : "04. 界面主题、算法手册与首次向导", valueSummary: theme.name(for: lang))
if expandedSettingsSection == 3 { appearanceAndWizardSettingsCard.transition(.opacity.combined(with: .move(edge: .top))) }
}.padding(.top, 2).padding(.bottom, 8) }}
private var twoLevelFilmStockSelectorView: some View { VStack(alignment: .leading, spacing: 7) { HStack {
Text(lang == .en ? "Film Format (135 / 120)" : "胶片画幅（联动手账张数与120近摄皮腔补偿）").fSys(10.5, .bold).foregroundStyle(Color.white.opacity(0.72))
Spacer()
Text("\(filmFormat.maxFrames) 张/卷").fMono(10, .black).foregroundStyle(theme.accent) }
ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 6) { ForEach(FilmFormatType.allCases) { fmt in
let isFmtSel: Bool = (filmFormatRaw == fmt.rawValue)
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { filmFormatRaw = fmt.rawValue }} label: {
Text(fmt.pillTitle(for: lang)).fMono(11, .bold).foregroundStyle(isFmtSel ? Color.black : Color.white).padding(.horizontal, 10).padding(.vertical, 5.5).background(isFmtSel ? theme.accent : Color.white.opacity(0.12), in: Capsule()) }}}}
Text(filmFormat.bellowsHint(for: lang)).fSys(9.5, .medium).foregroundStyle(theme.secondaryAccent).lineLimit(1)
HStack { Text(lang == .en ? "Step 1: Film Brand" : "第一步：选择胶片厂商").fSys(10.5, .bold).foregroundStyle(Color.white.opacity(0.72))
Spacer()
Text(currentFilmBadgeName).fMono(10.5, .black).foregroundStyle(theme.accent) }
ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 6) { ForEach(FilmBrandCategory.allCases) { brand in
let isBrandSel: Bool = (selectedFilmBrand == brand)
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { selectedFilmBrand = brand
if brand == .customISO { selectedFilmStockID = "custom" }}} label: {
Text(brand.title(for: lang)).fSys(11, .bold).foregroundStyle(isBrandSel ? Color.black : Color.white).padding(.horizontal, 10).padding(.vertical, 5.5).background(isBrandSel ? theme.accent : Color.white.opacity(0.12), in: Capsule()) }}}}
Text(selectedFilmBrand == .customISO
? (lang == .en ? "Step 2: Select Manual ISO Speed" : "第二步：手动指定感光度 (ISO)")
: (lang == .en ? "Step 2: Select Film Stock (Auto-sets ISO)" : "第二步：选择具体胶卷型号（自动匹配 ISO）")).fSys(10.5, .bold).foregroundStyle(Color.white.opacity(0.72))
if selectedFilmBrand == .customISO { ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 6) { ForEach(isoSteps, id: \.self) { isoVal in
let active: Bool = (abs(filmISO - isoVal) < 0.5 && selectedFilmStockID == "custom")
Button { feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled, magneticSnap: true)
withAnimation(.snappy) { selectedFilmStockID = "custom"
filmISO = isoVal
if lockPower { solveForLockedPower(changed: .flashPower) }
syncWidgetDefaults() }} label: {
Text("ISO \(Int(isoVal))").fMono(11, .bold).foregroundStyle(active ? Color.black : Color.white).padding(.horizontal, 10).padding(.vertical, 6).background(active ? theme.accent : Color.white.opacity(0.10), in: Capsule()) }}}}} else {
ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 7) { ForEach(FilmStockModel.catalog.filter { $0.brand == selectedFilmBrand }) { stock in
filmStockChipView(stock) }}}}}}
private func filmStockChipView(_ stock: FilmStockModel) -> some View {
let isSel: Bool = (selectedFilmStockID == stock.id); let fgTitle: Color = isSel ? Color.black : Color.white; let fgSub: Color = isSel ? Color.black.opacity(0.75) : Color.white.opacity(0.62); let bgCol: Color = isSel ? theme.accent : Color.white.opacity(0.10)
return Button { feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled, magneticSnap: true)
withAnimation(.snappy) { selectedFilmStockID = stock.id
filmISO = stock.iso
if lockPower { solveForLockedPower(changed: .flashPower) }
syncWidgetDefaults() }} label: { VStack(alignment: .leading, spacing: 2) { HStack(spacing: 5) { Text(stock.name).fSys(11.5, .black).foregroundStyle(fgTitle).lineLimit(1)
Text("ISO \(Int(stock.iso))").fMono(9.5, .black).foregroundStyle(isSel ? theme.accent : Color.black).padding(.horizontal, 5).padding(.vertical, 1.5).background(isSel ? Color.black.opacity(0.82) : theme.accent, in: Capsule()) }
Text(stock.subtitle(for: lang)).fSys(9.5, .medium).foregroundStyle(fgSub).lineLimit(1) } .padding(.horizontal, 10).padding(.vertical, 7).background(bgCol, in: RoundedRectangle(cornerRadius: 11)) }}
private var flashHardwareSettingsCard: some View { VStack(alignment: .leading, spacing: 8) { HStack {
Label(lang == .en ? "1. FLASH HARDWARE" : "1. 闪光灯硬件配置 (FLASH UNIT)", systemImage: "bolt.shield.fill").fMono(11, .black).foregroundStyle(theme.accent)
Spacer()
Text(selectedFlashID == "custom" ? (lang == .en ? "Manual GN" : "手动自定义指数") : selectedFlashModel.brand.title(for: lang)).fSys(10, .semibold).foregroundStyle(Color.white.opacity(0.6)) }
HStack { Text(lang == .en ? "Flash Model" : "闪光灯型号").fSys(12, .semibold).foregroundStyle(Color.white)
Spacer()
Menu { ForEach([FlashBrandCategory.godox, .contax, .canon, .nikon, .leicaFuji, .custom]) { brandCat in
Section(header: Text(brandCat.title(for: lang))) { ForEach(FlashUnitModel.catalog.filter { $0.brand == brandCat }) { model in
Button { feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled, magneticSnap: true)
withAnimation(.snappy) { selectedFlashID = model.id
if model.id != "custom" { flashGN = model.gnAtISO100 }
if lockPower { solveForLockedPower(changed: .flashPower) }
syncWidgetDefaults() }} label: { HStack { Text(model.displayName(for: lang))
if selectedFlashID == model.id { Image(systemName: "checkmark") }}}}}}} label: { dropdownCapsuleLabel(
text: selectedFlashID == "custom"
? (lang == .en ? "Custom (GN\(Int(flashGN)))" : "自定义 (GN\(Int(flashGN)))")
: "\(selectedFlashModel.shortBadge) (GN\(Int(flashGN)))" ) }}
HStack(spacing: 8) { Text(lang == .en ? "Guide No. (ISO100·m)" : "闪光指数 (ISO100·米)").fSys(11.5, .semibold).foregroundStyle(Color.white.opacity(0.88)).fixedSize()
Button { feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { flashGN = max(3.0, flashGN - 1.0)
selectedFlashID = "custom"
if lockPower { solveForLockedPower(changed: .flashPower) }
syncWidgetDefaults() }} label: { Image(systemName: "minus").fSys(10, .black).foregroundStyle(Color.white).frame(width: 25, height: 25).background(Color.white.opacity(0.12), in: Circle()) }
Slider(
value: Binding(
get: { flashGN }, set: { newVal in
flashGN = round(newVal)
selectedFlashID = "custom"
if lockPower { solveForLockedPower(changed: .flashPower) }} ), in: 5...64, step: 1 ).tint(theme.accent)
Button { feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { flashGN = min(80.0, flashGN + 1.0)
selectedFlashID = "custom"
if lockPower { solveForLockedPower(changed: .flashPower) }
syncWidgetDefaults() }} label: { Image(systemName: "plus").fSys(10, .black).foregroundStyle(Color.white).frame(width: 25, height: 25).background(Color.white.opacity(0.12), in: Circle()) }
Text("GN \(Int(flashGN))").fMono(11, .black).foregroundStyle(theme.accent).frame(width: 46, alignment: .trailing) }
HStack { Text(lang == .en ? "Flash Zoom / Lens Focal" : "灯头变焦 / 挂机镜头焦距").fSys(11.5, .semibold).foregroundStyle(Color.white.opacity(0.88))
Spacer()
Menu { ForEach(flashZoomPresets, id: \.self) { mm in
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { flashZoomMM = mm
if lockPower { solveForLockedPower(changed: .flashPower) }}} label: { HStack { Text(flashZoomMenuLabel(for: mm))
if flashZoomMM == mm { Image(systemName: "checkmark") }}}}} label: {
dropdownCapsuleLabel(text: flashZoomMenuLabel(for: flashZoomMM)) }}} .padding(.horizontal, 13).padding(.vertical, 10).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16)) }
private var cameraAndFilmBaseSettingsCard: some View { VStack(alignment: .leading, spacing: 8) { HStack {
Label(lang == .en ? "2. CAMERA, LENS & FILM" : "2. 胶卷感光度与机身镜头 (CAMERA & FILM)", systemImage: "camera.aperture").fMono(11, .black).foregroundStyle(theme.accent)
Spacer()
Text(lang == .en ? "1/3-Stop Standard" : "1/3档国际标准").fMono(9.5, .semibold).foregroundStyle(Color.white.opacity(0.55)) }
twoLevelFilmStockSelectorView
HStack(spacing: 10) { HStack { Text(lang == .en ? "Lens Max f/" : "镜头最大光圈").fSys(11.5, .semibold).foregroundStyle(Color.white.opacity(0.88)).lineLimit(1)
Spacer(minLength: 4)
Menu { ForEach(maxAperturePresets, id: \.self) { apVal in
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { maxLensAperture = apVal
if aperture < apVal { aperture = apVal }
syncWidgetDefaults() }} label: { HStack { Text(formatFStop(apVal))
if abs(maxLensAperture - apVal) < 0.05 { Image(systemName: "checkmark") }}}}} label: { dropdownCapsuleLabel(text: formatFStop(maxLensAperture)) }}
HStack { Text(lang == .en ? "Body X-Sync" : "机身同步上限").fSys(11.5, .semibold).foregroundStyle(Color.white.opacity(0.88)).lineLimit(1)
Spacer(minLength: 4)
Menu { ForEach(syncPresets, id: \.self) { spd in
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { maxSyncSpeed = spd }} label: { HStack { Text("1/\(spd)s")
if maxSyncSpeed == spd { Image(systemName: "checkmark") }}}}} label: { dropdownCapsuleLabel(text: "1/\(maxSyncSpeed)s") }}}
Divider().background(Color.white.opacity(0.14))
VStack(alignment: .leading, spacing: 6) { HStack { Text(lang == .en ? "Camera Shutter System & Lens Sync" : "机身快门结构与镜间快门镜头 (LS)").fSys(11, .bold).foregroundStyle(theme.accent)
Spacer()
Menu { ForEach(CameraShutterPreset.allCases) { preset in
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { cameraPresetID = preset.rawValue
maxSyncSpeed = preset.defaultSync
syncModeRaw = preset.defaultMode.rawValue
if let fmt = preset.suggestedFormat { filmFormatRaw = fmt.rawValue }
if shutterDenom > effectiveMaxSyncSpeed { shutterDenom = effectiveMaxSyncSpeed }}} label: { HStack { Text(preset.title(for: lang))
if cameraPresetID == preset.rawValue { Image(systemName: "checkmark") }}}}} label: { dropdownCapsuleLabel(text: cameraPresetEnum.title(for: lang)) }}
HStack(spacing: 6) { ForEach(ShutterSyncMode.allCases) { mode in
let isModeSel = (syncModeRaw == mode.rawValue)
Button { feedback.dialTick(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled, magneticSnap: true)
withAnimation(.snappy) { syncModeRaw = mode.rawValue }} label: {
Text(mode.shortBadge(for: lang, bodySync: maxSyncSpeed)).fMono(10, .bold).foregroundStyle(isModeSel ? Color.black : Color.white).frame(maxWidth: .infinity).padding(.vertical, 6).background(isModeSel ? (mode == .leafShutterLens ? Color.green : theme.accent) : Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 9)) } .buttonStyle(.plain) }}
Text(cameraPresetEnum.defectWarning(for: lang)).fSys(9.5, .medium).foregroundStyle(Color.orange.opacity(0.95)).fixedSize(horizontal: false, vertical: true).padding(8).background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10)) }} .padding(.horizontal, 13).padding(.vertical, 10).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16)) }
private var audioHapticsAndSystemSettingsCard: some View { VStack(alignment: .leading, spacing: 8) { HStack {
Label(lang == .en ? "3. VOICE, HAPTICS & LANGUAGE" : "3. 语音、触感与语言偏好", systemImage: "waveform.and.mic").fMono(11, .black).foregroundStyle(theme.accent)
Spacer()
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
guideInitialSection = 0
showGuideSheet = true } label: { HStack(spacing: 3) { Image(systemName: "text.bubble.fill").fSys(9.5, .bold)
Text(lang == .en ? "Voice Keywords" : "🎙️ 语音口令词典").fSys(10, .bold) } .foregroundStyle(Color.black).padding(.horizontal, 8).padding(.vertical, 4).background(theme.accent, in: Capsule()) }}
HStack(spacing: 10) { HStack { Text(lang == .en ? "Voice" : "播报音色").fSys(11.5, .semibold).foregroundStyle(Color.white.opacity(0.88))
Spacer(minLength: 4)
Menu { ForEach(VoicePersona.allCases) { p in
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { voicePersonaRaw = p.rawValue
feedback.refreshVoiceQualityStatus(persona: p, lang: lang)
let sample = lang == .en
? "Switched to \(p.title(for: lang)), aperture \(formatFStop(aperture))"
: "已切换为\(p.title(for: lang))，光圈 \(formatFStop(aperture))"
feedback.toggleSpeakExposure(sample, soundEnabled: true, persona: p, lang: lang) }} label: { HStack { Text(p.title(for: lang))
if voicePersonaRaw == p.rawValue { Image(systemName: "checkmark") }}}}} label: { dropdownCapsuleLabel(text: voicePersona.title(for: lang)) }}
HStack { Text(lang == .en ? "Lang" : "界面语言").fSys(11.5, .semibold).foregroundStyle(Color.white.opacity(0.88))
Spacer(minLength: 4)
Menu { ForEach(AppLanguage.allCases) { l in
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { langRaw = l.rawValue
feedback.refreshVoiceQualityStatus(persona: voicePersona, lang: l) }} label: { HStack { Text(l.displayName)
if langRaw == l.rawValue { Image(systemName: "checkmark") }}}}} label: { dropdownCapsuleLabel(text: lang.displayName) }}}
HStack(spacing: 16) { Toggle(isOn: $soundEnabled) { Text(lang == .en ? "Mechanical & Voice Audio" : "机械拨盘音与语音播报").fSys(11.5, .semibold).foregroundStyle(Color.white).lineLimit(1) } .tint(theme.accent)
Toggle(isOn: $hapticEnabled) {
Text(lang == .en ? "Haptics" : "棘轮震动").fSys(11.5, .semibold).foregroundStyle(Color.white).lineLimit(1) } .tint(theme.accent) }} .padding(.horizontal, 13).padding(.vertical, 10).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16)) }
private var appearanceAndWizardSettingsCard: some View { VStack(alignment: .leading, spacing: 8) { HStack(spacing: 6) {
Label(lang == .en ? "4. THEME & MANUAL" : "4. 主题、算法手册与向导", systemImage: "paintpalette.fill").fMono(11, .black).foregroundStyle(theme.accent).lineLimit(1)
Spacer()
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
guideInitialSection = 1
showGuideSheet = true } label: { HStack(spacing: 3) { Image(systemName: "book.pages.fill").fSys(9.5, .bold)
Text(lang == .en ? "Algorithm & Guide" : "📐 算法与使用指南").fSys(10, .bold) } .foregroundStyle(Color.white).padding(.horizontal, 8).padding(.vertical, 4.5).background(Color.white.opacity(0.16), in: Capsule()) }
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
showOnboardingSheet = true } label: { HStack(spacing: 3) { Image(systemName: "sparkles.rectangle.stack").fSys(9.5, .bold)
Text(lang == .en ? "Wizard" : "装卷向导").fSys(10, .bold) } .foregroundStyle(Color.black).padding(.horizontal, 8).padding(.vertical, 4.5).background(theme.accent, in: Capsule()) }}
HStack(spacing: 8) { ForEach(AppTheme.allCases) { item in
let isCur = (themeRaw == item.rawValue)
Button { feedback.buttonTap(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.snappy) { themeRaw = item.rawValue }} label: { VStack(spacing: 4) {
ZStack { Circle().fill(LinearGradient(colors: item.backgroundGradient, startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 28, height: 28).overlay(Circle().stroke(item.accent, lineWidth: isCur ? 2.0 : 1.0))
Image(systemName: item.icon).foregroundStyle(item.accent).fSys(12, .bold) }
Text(item.name(for: lang)).fSys(9.5, .bold).foregroundStyle(isCur ? Color.black : Color.white).lineLimit(1).minimumScaleFactor(0.75) } .frame(maxWidth: .infinity).padding(.vertical, 7).background(isCur ? theme.accent : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13)).scaleEffect(isCur ? 1.02 : 0.98) }}}} .padding(.horizontal, 13).padding(.vertical, 10).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16)) }
private func dropdownCapsuleLabel(text: String) -> some View { HStack(spacing: 5) { Text(text).fMono(11, .bold).foregroundStyle(Color.white).lineLimit(1).contentTransition(.numericText())
Image(systemName: "chevron.up.chevron.down").fSys(9, .bold).foregroundStyle(theme.accent) } .padding(.horizontal, 10).padding(.vertical, 5.5).background(Color.white.opacity(0.12), in: Capsule()) }
private var appleMusicLiquidGlassBottomBar: some View { GeometryReader { geo in
let pad: CGFloat = 6; let availW = max(180, geo.size.width - pad * 2); let tabW = availW / 3.0
ZStack(alignment: .leading) {
Capsule().fill(.ultraThinMaterial).overlay(LinearGradient(stops: [.init(color: Color.white.opacity(0.18), location: 0.0), .init(color: Color.white.opacity(0.04), location: 0.5), .init(color: theme.accent.opacity(0.08), location: 1.0)], startPoint: .top, endPoint: .bottom).clipShape(Capsule())).shadow(color: Color.black.opacity(0.38), radius: 14, x: 0, y: 6)
ZStack { Capsule().fill(.thinMaterial)
Capsule().fill(LinearGradient(stops: [.init(color: Color.white.opacity(0.32), location: 0.0), .init(color: Color.white.opacity(0.08), location: 0.45), .init(color: theme.accent.opacity(0.18), location: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
Capsule().strokeBorder(LinearGradient(colors: [Color.white.opacity(0.60), theme.accent.opacity(0.42), Color.white.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2) }.frame(width: tabW, height: geo.size.height - 10).shadow(color: theme.accent.opacity(0.25), radius: 8, x: 0, y: 3).offset(x: pad + CGFloat(selectedTab) * tabW).animation(.spring(response: 0.36, dampingFraction: 0.72, blendDuration: 0.14), value: selectedTab)
HStack(spacing: 0) { appleMusicLiquidTabButton(index: 0, title: lang == .en ? "Meter" : "测光台", icon: "dial.medium.fill", width: tabW)
appleMusicLiquidTabButton(index: 1, title: lang == .en ? "Roll & Mod" : "附件手账", icon: "camera.filters", width: tabW)
appleMusicLiquidTabButton(index: 2, title: lang == .en ? "Settings" : "器材设置", icon: "slider.horizontal.3", width: tabW)
}.padding(.horizontal, pad) }
}.frame(height: 58) }
private func appleMusicLiquidTabButton(index: Int, title: String, icon: String, width: CGFloat) -> some View {
let isSelected = (selectedTab == index); let activeColor: Color = theme.accent; let inactiveColor: Color = Color.white.opacity(0.72)
return Button { feedback.tabSwitchHaptic(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
withAnimation(.spring(response: 0.36, dampingFraction: 0.72, blendDuration: 0.14)) { selectedTab = index }} label: { VStack(spacing: 2.5) {
Image(systemName: icon).font(.system(size: 17.5, weight: .bold)).scaleEffect(isSelected ? 1.12 : 1.0)
Text(title).font(.system(size: 10.5, weight: isSelected ? .black : .semibold, design: .rounded)).lineLimit(1) }.foregroundStyle(isSelected ? activeColor : inactiveColor).frame(width: width, height: 48).contentShape(Rectangle()).animation(.spring(response: 0.34, dampingFraction: 0.72), value: isSelected)
}.buttonStyle(.plain) }}
struct iOSClockDrumWheelView: View { let items: [String]; let selectedIndex: Int; let parameterIcon: String; let subtitleText: String; let theme: AppTheme; let onStepChange: (Int) -> Void
@State private var dragAccumY: CGFloat = 0; @State private var liveDragY: CGFloat = 0
@ViewBuilder private func drumRowView(offset: Int) -> some View { let targetIdx = selectedIndex + offset
let isCenter = (offset == 0); let absOff = abs(offset); let rowH: CGFloat = isCenter ? 34.0 : (absOff == 1 ? 22.0 : 19.0)
if targetIdx >= 0 && targetIdx < items.count { let fontSz: CGFloat = isCenter ? 23.5 : (absOff == 1 ? 15.5 : 13.0)
let rowAlpha: Double = isCenter ? 1.0 : (absOff == 1 ? 0.72 : 0.45); let rowScale: CGFloat = isCenter ? 1.04 : (absOff == 1 ? 0.92 : 0.82); let deg: Double = Double(offset) * -15.5 + Double(liveDragY * 0.38)
let tickW: CGFloat = isCenter ? 10.0 : (absOff == 1 ? 6.0 : 3.5)
HStack(spacing: 5) { RoundedRectangle(cornerRadius: 1).fill(isCenter ? theme.accent : Color.white.opacity(absOff == 1 ? 0.32 : 0.18)).frame(width: tickW, height: isCenter ? 2.2 : 1.2)
Text(items[targetIdx]).font(.system(size: fontSz, weight: isCenter ? .black : .bold, design: .monospaced)).foregroundStyle(isCenter ? Color.white : Color.white.opacity(0.90)).shadow(color: isCenter ? theme.accent.opacity(0.75) : Color.clear, radius: isCenter ? 8 : 0).contentTransition(.numericText()).lineLimit(1).minimumScaleFactor(0.75).frame(maxWidth: .infinity)
RoundedRectangle(cornerRadius: 1).fill(isCenter ? theme.accent : Color.white.opacity(absOff == 1 ? 0.32 : 0.18)).frame(width: tickW, height: isCenter ? 2.2 : 1.2)
}.padding(.horizontal, 6).frame(height: rowH).scaleEffect(rowScale).opacity(rowAlpha).rotation3DEffect(.degrees(deg), axis: (x: 1, y: 0, z: 0), perspective: 0.45).offset(y: liveDragY * (isCenter ? 0.25 : 0.16)).contentShape(Rectangle()).onTapGesture {
if offset != 0 { onStepChange(offset) } }
} else { Color.clear.frame(height: rowH) } }
var body: some View { VStack(spacing: 3) { ZStack { RadialGradient(colors: [theme.accent.opacity(0.28), theme.secondaryAccent.opacity(0.08), Color.clear], center: .center, startRadius: 6, endRadius: 80)
ZStack { RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [theme.accent.opacity(0.26), Color.white.opacity(0.16), theme.accent.opacity(0.20)], startPoint: .leading, endPoint: .trailing))
RoundedRectangle(cornerRadius: 12).strokeBorder(LinearGradient(colors: [Color.white.opacity(0.55), theme.accent.opacity(0.85), Color.white.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
}.frame(height: 35).padding(.horizontal, 4).shadow(color: theme.accent.opacity(0.35), radius: 9, x: 0, y: 0)
VStack(spacing: 1) { drumRowView(offset: -2)
drumRowView(offset: -1)
drumRowView(offset: 0)
drumRowView(offset: 1)
drumRowView(offset: 2)
}.mask(LinearGradient(stops: [.init(color: .white.opacity(0.18), location: 0.0), .init(color: .white.opacity(0.88), location: 0.10), .init(color: .white, location: 0.26), .init(color: .white, location: 0.74), .init(color: .white.opacity(0.88), location: 0.90), .init(color: .white.opacity(0.18), location: 1.0)], startPoint: .top, endPoint: .bottom))
}.frame(maxHeight: .infinity).contentShape(Rectangle()).gesture(
DragGesture(minimumDistance: 3).onChanged { val in
let dy = val.translation.height - dragAccumY
withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.75)) { liveDragY = max(-12, min(12, dy)) }
let stepH: CGFloat = 20.0
if abs(dy) >= stepH { let steps = Int(dy / stepH); dragAccumY += CGFloat(steps) * stepH; liveDragY = 0
onStepChange(steps < 0 ? 1 : -1) }
}.onEnded { _ in
dragAccumY = 0
withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { liveDragY = 0 } })
HStack(spacing: 4) { Image(systemName: parameterIcon).fSys(9.5, .bold).foregroundStyle(theme.accent)
Text(subtitleText).fSys(9.5, .medium).foregroundStyle(Color.white.opacity(0.72)).lineLimit(1) } } } }
struct CameraAmbientMeterSheet: View {
@Binding var ambientEV100: Double
@Binding var subjectDistance: Double
let lang: AppLanguage; let theme: AppTheme
@Environment(\.dismiss) private var dismiss
@ObservedObject private var reader = CameraAmbientEVReader.shared
@State private var keepRunningInBackground: Bool = false
private let distSteps: [Double] = [0.5, 0.7, 1.0, 1.2, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 7.0, 10.0, 15.0]
private func snapDistance(_ raw: Double) -> Double { distSteps.min(by: { abs($0 - raw) < abs($1 - raw) }) ?? max(0.5, min(15.0, (raw * 2.0).rounded() / 2.0)) }
var body: some View { ZStack { Color.black.ignoresSafeArea()
CameraPreviewLayerView(session: reader.session).ignoresSafeArea().onTapGesture { reader.recenterExposurePoint() }
ZStack { RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.28), lineWidth: 1.2).frame(width: 260, height: 260)
Circle().stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6])).frame(width: 120, height: 120)
Circle().stroke(theme.accent, lineWidth: 2.2).frame(width: 28, height: 28)
VStack { Spacer().frame(height: 165)
Text(String(format: "🎯 %.1f m · %@", reader.liveDistanceMeters, reader.distanceSensorLabel)).fMono(11.5, .black).foregroundStyle(Color.black).padding(.horizontal, 10).padding(.vertical, 4).background(theme.accent, in: Capsule()) }
}.allowsHitTesting(false)
VStack { HStack(spacing: 8) { HStack(spacing: 6) { Circle().fill(reader.isRunning ? Color.green : Color.orange).frame(width: 8, height: 8)
Text(lang == .en ? "LIVE VIEWFINDER" : "全屏实景测光 · 激光测距").fSys(13, .black).foregroundStyle(Color.white)
}.padding(.horizontal, 12).padding(.vertical, 7).background(.ultraThinMaterial, in: Capsule())
Button { reader.toggleLensFieldOfView(lang: lang) } label: {
Text(reader.useUltraWideLens ? "0.5x" : "1x").fMono(12, .black).foregroundStyle(Color.black).padding(.horizontal, 10).padding(.vertical, 7).background(theme.accent, in: Capsule()) }
Spacer()
Button { if !keepRunningInBackground { reader.stopReading() }
dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundStyle(Color.white).shadow(radius: 4) }
}.padding(.horizontal, 16).padding(.top, 14)
HStack {
Text(String(format: "CMOS: f/%.1f · 1/%ds · ISO %.0f", reader.cameraAperture, reader.cameraShutterDenom, reader.cameraISO)).fMono(10, .bold).foregroundStyle(Color.cyan).padding(.horizontal, 10).padding(.vertical, 4.5).background(Color.black.opacity(0.55), in: Capsule())
Spacer()
}.padding(.horizontal, 16).padding(.top, 4)
Spacer()
VStack(spacing: 10) { HStack(alignment: .center) { VStack(alignment: .leading, spacing: 2) { Text(lang == .en ? "AMBIENT LIGHT" : "现场环境光亮度").fMono(9.5, .bold).foregroundStyle(Color.white.opacity(0.7))
Text(String(format: "☀️ EV %.1f", reader.liveEV100)).font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(theme.accent).contentTransition(.numericText()) }
Spacer()
VStack(alignment: .trailing, spacing: 2) { Text(reader.distanceSensorLabel).fMono(9.5, .bold).foregroundStyle(Color.green)
Text(String(format: "🎯 %.1f m", reader.liveDistanceMeters)).font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(Color.white).contentTransition(.numericText()) }}
HStack(spacing: 8) { Text(lang == .en ? "EV Trim" : "反射率校准").fSys(11, .semibold).foregroundStyle(Color.white.opacity(0.85))
Slider(value: $reader.calibrationTrimEV, in: -1.0...1.0, step: 0.1).tint(theme.accent)
Button { reader.calibrationTrimEV = 0.0 } label: {
Text(String(format: "%+.1f EV", reader.calibrationTrimEV)).fMono(10, .bold).foregroundStyle(abs(reader.calibrationTrimEV) < 0.05 ? Color.white : Color.black).padding(.horizontal, 7).padding(.vertical, 4).background(abs(reader.calibrationTrimEV) < 0.05 ? Color.white.opacity(0.14) : theme.accent, in: Capsule()) }}
Toggle(isOn: $keepRunningInBackground) { Text(lang == .en ? "Keep Live EV active in background" : "返回主页后保持后台连续测光").fSys(11, .semibold).foregroundStyle(Color.white.opacity(0.9))
}.tint(Color.green)
Button { ambientEV100 = reader.liveEV100
subjectDistance = snapDistance(reader.liveDistanceMeters)
if !keepRunningInBackground { reader.stopReading() }
dismiss() } label: { HStack(spacing: 6) { Image(systemName: "scope").fSys(14, .black)
Text(lang == .en ? String(format: "Apply EV %.1f + Distance %.1fm", reader.liveEV100, snapDistance(reader.liveDistanceMeters)) : String(format: "同时填入环境光 (EV %.1f) 与中心距离 (%.1fm)", reader.liveEV100, snapDistance(reader.liveDistanceMeters))).fSys(13.5, .black)
}.foregroundStyle(Color.black).frame(maxWidth: .infinity).padding(.vertical, 13).background(theme.accent, in: RoundedRectangle(cornerRadius: 15)) }
Button { ambientEV100 = reader.liveEV100
if !keepRunningInBackground { reader.stopReading() }
dismiss() } label: {
Text(lang == .en ? String(format: "Apply EV %.1f Only (Keep Distance)", reader.liveEV100) : String(format: "仅填入环境光 EV %.1f（保持原距离不变）", reader.liveEV100)).fSys(11.5, .bold).foregroundStyle(Color.white.opacity(0.9)).frame(maxWidth: .infinity).padding(.vertical, 9).background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12)) }
}.padding(16).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24)).padding(.horizontal, 12).padding(.bottom, 10) }}.onAppear { keepRunningInBackground = reader.isRunning
reader.startReading(lang: lang) { newEV in ambientEV100 = newEV }}.onDisappear { if !keepRunningInBackground { reader.stopReading() }}}}
struct LumiFilmManualAndVoiceSheet: View { let initialTab: Int; let lang: AppLanguage; let theme: AppTheme
@Environment(\.dismiss) private var dismiss
@State private var activeTab: Int = 0
var body: some View { ZStack { LinearGradient(colors: theme.backgroundGradient, startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
VStack(spacing: 12) { HStack { Label(
lang == .en ? "LumiFilm Guide & Voice Dictionary" : "LumiFilm 语音口令词典与核心算法手册", systemImage: "book.pages.fill" ).fSys(15, .black).foregroundStyle(Color.white)
Spacer()
Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundStyle(Color.white.opacity(0.68)) }}
Picker("Section", selection: $activeTab) { Text(lang == .en ? "🎙️ Voice Keywords" : "🎙️ 语音识别关键字指引").tag(0)
Text(lang == .en ? "📐 Algorithm & Usage" : "📐 核心算法与使用指南").tag(1) } .pickerStyle(.segmented)
ScrollView(showsIndicators: true) { if activeTab == 0 { voiceKeywordsGuideContent } else { algorithmAndUsageGuideContent }}} .padding(18) }.onAppear { activeTab = initialTab }}
private var voiceKeywordsGuideContent: some View { VStack(alignment: .leading, spacing: 11) { guideSectionCard(
title: lang == .en ? "1. Ambient Scene Keywords (Auto-Sets Scene EV & Fill)" : "1. 环境光描述关键字（自动匹配现场 EV 与补光策略）", icon: "sun.max.fill", rows: [
("“大太阳天” / “晴天” / “烈日” / “海边”", "自动设为 EV 15 直射阳光，并切换为自然逆光补光 (-1.3 EV)"), ("“多云” / “晴间多云”", "自动设为 EV 14 户外晴间多云"), ("“阴天” / “overcast”", "自动设为 EV 12 户外柔和阴天"), ("“树荫” / “背阴” / “傍晚” / “夕阳”", "自动设为 EV 11 树荫环境光"), ("“逆光” / “逆光补光”", "自动设为 EV 11 并开启自然补光 (-1.3 EV)"), ("“明亮室内” / “办公室” / “商场” / “窗边”", "自动设为 EV 9 室内明亮环境光"), ("“室内” / “客厅” / “咖啡馆” / “居家”", "自动设为 EV 7 室内暖光环境"), ("“酒吧” / “昏暗” / “烛光” / “暗光”", "自动设为 EV 6 昏暗氛围环境"), ("“夜景” / “夜晚” / “夜拍” / “霓虹”", "自动设为 EV 5 夜晚街拍慢门环境") ] )
guideSectionCard(
title: lang == .en ? "2. Flash Role & Energy Balance Keywords" : "2. 闪光与环境光联动模式关键字", icon: "bolt.badge.automatic.fill", rows: [
("“主光联动” / “主光” / “防过曝”", "开启主光联动：自动扣减环境光已贡献的能量占比，防止过曝"),
("“纯闪光” / “全闪光” / “暗室”", "开启纯闪光模式：忽略环境光，100% 按闪光灯 GN 公式计算"), ("“自然补光” / “补光”", "开启自然补光 (-1.3 EV)：压低闪光输出，柔和提亮暗部"), ("“眼神光” / “微补”", "开启眼神光模式 (-2.0 EV)：仅点亮被摄者眼神反光") ] )
guideSectionCard(
title: lang == .en ? "3. Aperture, Shutter, Distance & EV Comp Keywords" : "3. 光圈、快门、距离与曝光补偿语音口令", icon: "dial.medium.fill", rows: [
("“光圈 2.8” / “f4” / “f5.6”", "直接将光圈设定为对应的 1/3 档标准光圈值"), ("“快门 200” / “125分之一秒”", "直接将快门速度设定为 1/200s、1/125s 等"), ("“距离 0.7米” / “1.2米” / “2.5米”", "直接将拍摄距离设定为对应米数（近摄支持 0.1m 精度）"),
("“功率 4分之一” / “1/8” / “全功率”", "直接锁定闪光灯输出功率为对应档位并反推光圈/距离"), ("“加 0.4 档” / “减 1 档” / “归零”", "直接调节曝光补偿 EV 值或一键复位至 0.0 EV"), ("“肥皂盒” / “柔光箱” / “跳闪” / “裸灯”", "自动计入柔光罩 (-1EV)、柔光箱 (-2EV) 或天花板跳闪 (-2EV) 光损") ] ) }}
private var algorithmAndUsageGuideContent: some View { VStack(alignment: .leading, spacing: 11) { guideSectionCard(
title: lang == .en ? "1. Core Workflow (3-Step Film Flash Metering)" : "1. 核心使用方法（三步快速胶片闪光测光）", icon: "1.circle.fill", rows: [
("第一步：设基准 (Settings)", "在第三页选择装入的胶卷 ISO（如 250D / 400）、闪光灯型号（或自定义 GN）及挂机镜头焦距。"), ("第二步：测现场 (Meter 主页)", "点击『实时测光 EV』用手机镜头测取现场环境光，并点『主光联动』选择主光或逆光补光 (-1.3 EV)。"),
("第三步：拨波轮 / 语音速算", "转动底部大波轮（或按侧边 Action 键直接说出“f4 距离2米”），顶部即刻算出并播报推荐闪光灯功率（如 1/4 +0.3EV）。") ] )
guideSectionCard(
title: lang == .en ? "2. Effective Guide Number & Fresnel Zoom Physics" : "2. 有效闪光指数 (GN) 与灯头变焦折算算法", icon: "function", rows: [
("基础与感光度换算", "GN_eff = GN_100 × √(ISO_eff / 100) × (Zoom_mm / Rated_mm)^0.35 × 2^(-Loss_EV / 2)"), ("菲涅尔透镜焦距折算", "厂家标称 GN 多在 105mm 测得；当挂机 35mm/50mm 镜头时，软件按光学聚光曲线自动折算真实有效 GN，消除广角欠曝。"),
("附件、滤镜与近摄修正", "叠加柔光罩、跳闪角度、镜头滤镜、迫冲 EI 以及 <1.0m 近摄距离光损，计算出 1/1 全功率下的最大可用光圈。") ] )
guideSectionCard(
title: lang == .en ? "3. Ambient + Flash Energy Summation Algorithm" : "3. 主光联动（环境光+闪光能量守恒防过曝算法）", icon: "sun.max.trianglebadge.exclamationmark.fill", rows: [
("为什么传统公式会过曝？", "在明亮室内或树荫逆光下，当现场环境光已提供 40%~70% 曝光量时，若闪光灯仍按暗室公式 100% 输出，两者叠加会导致面部过曝 +0.6~1.0 EV。"),
("LumiFilm 能量守恒算法", "在『主光联动』模式下，软件先计算相机当前光圈快门吸纳的环境光占比 E_amb = 2^(EV_scene - EV_camera)，再自动将闪光所需功率下调为 E_flash = 1 - E_amb，使总曝光精准恒定为 0.0 EV。") ] )
guideSectionCard(
title: lang == .en ? "4. HSS Slit Loss & iPhone Camera EV Calibration" : "4. 高速同步 (HSS) 与手机镜头反射测光校准原理", icon: "camera.metering.center.weighted", rows: [
("HSS 高速同步光损模型", "快门超过机身最高同步速度 (X-Sync) 时，闪光灯转为高频频闪，软件自动计入 1.5 EV 阈值损耗 + 每快一档快门 1.0 EV 的狭缝损耗。"),
("iPhone 传感器 EV100 算法", "以 30fps 读取后置镜头 CMOS 的光圈 N、快门 t、ISO 与 Smart HDR 高光偏移寄存器 exposureTargetOffset：EV100 = log2(N²/t) - log2(ISO/100) - offset + 校准偏移。") ] ) }}
private func guideSectionCard(title: String, icon: String, rows: [(String, String)]) -> some View { VStack(alignment: .leading, spacing: 8) {
Label(title, systemImage: icon).fSys(12.5, .black).foregroundStyle(theme.accent)
ForEach(0..<rows.count, id: \.self) { idx in
VStack(alignment: .leading, spacing: 2) { Text(rows[idx].0).font(.system(size: 11.5, weight: .bold, design: .rounded)).foregroundStyle(Color.white)
Text(rows[idx].1).fSys(10.5, .medium).foregroundStyle(Color.white.opacity(0.75)).fixedSize(horizontal: false, vertical: true) } .padding(.vertical, 3) }} .frame(maxWidth: .infinity, alignment: .leading).padding(13).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16)) }}
struct OnboardingSetupSheet: View {
@Binding var filmISO: Double; @Binding var selectedFilmStockID: String; @Binding var filmFormatRaw: Int
@Binding var flashGN: Double; @Binding var selectedFlashID: String; @Binding var maxLensAperture: Double
@Binding var maxSyncSpeed: Int; @Binding var syncModeRaw: Int; @Binding var cameraPresetID: String
@Binding var aperture: Double; @Binding var themeRaw: Int; @Binding var hasCompletedOnboarding: Bool
let lang: AppLanguage; let theme: AppTheme
@Environment(\.dismiss) private var dismiss
@AppStorage("lf_lang_v8") private var langRaw: Int = 0; @State private var stepIndex: Int = 0; @State private var autoAdvanceEnabled: Bool = true; @State private var selectedBrandFilter: FlashBrandCategory = .godox; @State private var onboardingFilmBrand: FilmBrandCategory = .kodak
private let isoPresets: [Double] = [50, 100, 125, 160, 200, 250, 320, 400, 500, 800, 1600, 3200]
private let maxAperturePresets: [Double] = [1.0, 1.2, 1.4, 1.8, 2.0, 2.8, 3.5, 4.0, 5.6]
private let syncPresets: [Int] = [30, 50, 60, 90, 100, 125, 200, 250, 400, 500]
private var currentPreset: CameraShutterPreset { CameraShutterPreset(rawValue: cameraPresetID) ?? .pentax67 }
private var currentFormat: FilmFormatType { FilmFormatType(rawValue: filmFormatRaw) ?? .f135 }
private var currentSyncMode: ShutterSyncMode { ShutterSyncMode(rawValue: syncModeRaw) ?? .focalPlaneMechanical }
private var meshPair: (Color, Color) { onboardingFilmBrand.meshColors }
private var filteredFlashModels: [FlashUnitModel] { if selectedBrandFilter == .all { return FlashUnitModel.catalog.filter { $0.id != "custom" }}
if selectedBrandFilter == .custom { return FlashUnitModel.catalog.filter { $0.id == "custom" }}
return FlashUnitModel.catalog.filter { $0.brand == selectedBrandFilter }}
private var lyricsStepLines: [(badge: String, title: String, sub: String)] { [
(lang == .en ? "STEP 1 / 5 · FORMAT" : "第 1 / 5 步 · 胶片画幅", lang == .en ? "1. What film format are you shooting?" : "1. 您使用的是什么胶片画幅？", lang == .en ? "Tap format to auto-set roll exposures & bellows compensation." : "点选画幅自动匹配每卷张数上限与 120 近摄皮腔补偿，并自动进入第 2 步。"),
(lang == .en ? "STEP 2 / 5 · SHUTTER SYNC" : "第 2 / 5 步 · 快门同步限制", lang == .en ? "2. Which camera shutter system?" : "2. 您的机身快门与同步上限是？", lang == .en ? "Prevents focal-plane curtain blackout (e.g. 67II 1/30s vs LS 1/500s)." : "核对机身快门限制（如 67II 幕帘 1/30s vs LS 镜间 1/500s），点击橙色确认条进入第 3 步。"),
(lang == .en ? "STEP 3 / 5 · FILM STOCK" : "第 3 / 5 步 · 装入胶卷", lang == .en ? "3. Which film roll is loaded?" : "3. 相机里现在装的是哪一卷胶片？", lang == .en ? "Tap stock to auto-set ISO & fluid background." : "先选厂商再点选胶卷型号，自动设定感光度 ISO 并进入第 4 步。"),
(lang == .en ? "STEP 4 / 5 · LENS MAX f/" : "第 4 / 5 步 · 镜头光圈上限", lang == .en ? "4. What is your lens max aperture?" : "4. 您挂机镜头的最大光圈是多少？", lang == .en ? "Tap f-stop to lock physical lens ceiling." : "点选光圈锁定物理上限（防止反推越界），自动进入最后一步。"),
(lang == .en ? "STEP 5 / 5 · FLASH & READY" : "第 5 / 5 步 · 闪光灯与确认", lang == .en ? "5. Select flash unit & start metering" : "5. 选择热靴闪光灯并开启测光", lang == .en ? "Pick flash GN and tap Start Metering below." : "点选闪光灯型号或微调 GN 指数，确认下方器材通行证后即可开拍。") ] }
private func triggerAutoAdvance(from step: Int) { guard autoAdvanceEnabled, stepIndex == step, stepIndex < 4 else { return }
FeedbackEngine.shared.buttonTap(soundEnabled: true, hapticEnabled: true)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { if self.stepIndex == step && self.stepIndex < 4 { withAnimation(.snappy) { self.stepIndex += 1 }}}}
var body: some View { ZStack { LinearGradient(colors: theme.backgroundGradient, startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
Circle().fill(meshPair.0.opacity(0.30)).frame(width: 280, height: 280).blur(radius: 72).offset(x: -95, y: -190).animation(.easeInOut(duration: 0.6), value: onboardingFilmBrand)
Circle().fill(meshPair.1.opacity(0.24)).frame(width: 250, height: 250).blur(radius: 72).offset(x: 110, y: 180).animation(.easeInOut(duration: 0.6), value: onboardingFilmBrand)
VStack(spacing: 0) { wizardTopHeader
ScrollView(showsIndicators: false) { VStack(alignment: .leading, spacing: 12) { appleMusicLyricsFocusRail
switch stepIndex { case 0: step1FormatOnlyView
case 1: step2ShutterSystemOnlyView; case 2: step3FilmStockView; case 3: step4LensApertureView
default: step5FlashAndSummaryView }
}.padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 22) }
wizardBottomNavBar }}.onAppear { stepIndex = 0 }}
@ViewBuilder private func lyricsFocusRow(_ idx: Int) -> some View { let isCur: Bool = (idx == stepIndex); let isNear: Bool = abs(idx - stepIndex) == 1
if isCur || isNear {
let item = lyricsStepLines[idx]; let badgeFg: Color = isCur ? Color.black : theme.accent; let badgeBg: Color = isCur ? theme.accent : Color.clear; let rowOpacity: Double = isCur ? 1.0 : 0.35; let titleSize: CGFloat = isCur ? 19.0 : 12.5
Button { FeedbackEngine.shared.buttonTap(soundEnabled: true, hapticEnabled: true)
withAnimation(.snappy) { stepIndex = idx }} label: { VStack(alignment: .leading, spacing: 3) { HStack(spacing: 6) {
Text(item.badge).fMono(9.5, .black).foregroundStyle(badgeFg).padding(.horizontal, isCur ? 7 : 0).padding(.vertical, isCur ? 2 : 0).background(badgeBg, in: Capsule())
if idx < stepIndex { Image(systemName: "checkmark.circle.fill").fSys(10, .bold).foregroundStyle(Color.green) }}
Text(item.title).fSys(titleSize, .black).foregroundStyle(Color.white)
if isCur { Text(item.sub).fSys(11, .medium).foregroundStyle(Color.white.opacity(0.76)).fixedSize(horizontal: false, vertical: true) }
}.frame(maxWidth: .infinity, alignment: .leading).opacity(rowOpacity)
}.buttonStyle(.plain) }}
private var appleMusicLyricsFocusRail: some View { VStack(alignment: .leading, spacing: 6) { ForEach(0..<5, id: \.self) { idx in lyricsFocusRow(idx) }
}.padding(12).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16)) }
private var wizardTopHeader: some View { VStack(spacing: 8) { HStack { Text(lang == .en ? "STEP \(stepIndex + 1) OF 5" : "首次配置引导 · 第 \(stepIndex + 1) / 5 步").fMono(11.5, .black).foregroundStyle(theme.accent)
Spacer()
Button { withAnimation(.snappy) { autoAdvanceEnabled.toggle() }} label: {
Text(autoAdvanceEnabled ? (lang == .en ? "⚡ Auto-Next" : "⚡ 点选自动翻页") : (lang == .en ? "Manual" : "手动翻页")).fSys(9.5, .bold).foregroundStyle(autoAdvanceEnabled ? Color.black : Color.white).padding(.horizontal, 8).padding(.vertical, 4).background(autoAdvanceEnabled ? theme.accent : Color.white.opacity(0.12), in: Capsule()) }
Button { withAnimation(.snappy) { langRaw = (langRaw == 0) ? 1 : 0 }} label: {
Text(lang == .en ? "中文/EN" : "EN/中文").fMono(10, .bold).foregroundStyle(Color.white).padding(.horizontal, 8).padding(.vertical, 4).background(Color.white.opacity(0.12), in: Capsule()) }
if hasCompletedOnboarding { Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 19)).foregroundStyle(Color.white.opacity(0.55)) }}}
HStack(spacing: 6) { ForEach(0..<5, id: \.self) { idx in
Button { withAnimation(.snappy) { stepIndex = idx }} label: { Capsule().fill(idx <= stepIndex ? theme.accent : Color.white.opacity(0.16)).frame(height: idx == stepIndex ? 6 : 4).frame(maxWidth: .infinity)
}.buttonStyle(.plain) }}
}.padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 6) }
private var step1FormatOnlyView: some View { VStack(alignment: .leading, spacing: 8) { ForEach(FilmFormatType.allCases) { fmt in
let isFmtSel = (filmFormatRaw == fmt.rawValue)
Button { withAnimation(.snappy) { filmFormatRaw = fmt.rawValue }
triggerAutoAdvance(from: 0) } label: { HStack { VStack(alignment: .leading, spacing: 2) { Text(fmt.pillTitle(for: lang)).fMono(14, .black).foregroundStyle(isFmtSel ? Color.black : Color.white)
Text(fmt.bellowsHint(for: lang)).fSys(10, .medium).foregroundStyle(isFmtSel ? Color.black.opacity(0.75) : Color.white.opacity(0.65)).lineLimit(1) }
Spacer()
Image(systemName: isFmtSel ? "checkmark.circle.fill" : "circle").font(.system(size: 16)).foregroundStyle(isFmtSel ? Color.black : Color.white.opacity(0.4))
}.padding(.horizontal, 13).padding(.vertical, 11).background(isFmtSel ? theme.accent : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13)) }}
}.padding(13).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18)) }
private var step2ShutterSystemOnlyView: some View { VStack(alignment: .leading, spacing: 8) { ForEach(CameraShutterPreset.allCases) { preset in
let isPresetSel = (cameraPresetID == preset.rawValue)
Button { withAnimation(.snappy) { cameraPresetID = preset.rawValue; maxSyncSpeed = preset.defaultSync; syncModeRaw = preset.defaultMode.rawValue
if let fmt = preset.suggestedFormat { filmFormatRaw = fmt.rawValue }}} label: { HStack { Text(preset.title(for: lang)).fSys(11.5, .bold).foregroundStyle(isPresetSel ? Color.black : Color.white).lineLimit(1)
Spacer()
Text("≤1/\(preset.defaultSync)s").fMono(10, .black).foregroundStyle(isPresetSel ? Color.black : theme.accent)
Image(systemName: isPresetSel ? "checkmark.circle.fill" : "circle").font(.system(size: 13)).foregroundStyle(isPresetSel ? Color.black : Color.white.opacity(0.4))
}.padding(.horizontal, 11).padding(.vertical, 7.5).background(isPresetSel ? theme.accent : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10)) }}
HStack(spacing: 6) { ForEach(ShutterSyncMode.allCases) { mode in
let isMSel = (syncModeRaw == mode.rawValue)
Button { withAnimation(.snappy) { syncModeRaw = mode.rawValue }} label: {
Text(mode.shortBadge(for: lang, bodySync: maxSyncSpeed)).fMono(10, .bold).foregroundStyle(isMSel ? Color.black : Color.white).frame(maxWidth: .infinity).padding(.vertical, 6.5).background(isMSel ? (mode == .leafShutterLens ? Color.green : theme.accent) : Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 9)) }}}
VStack(alignment: .leading, spacing: 6) { Text(currentPreset.defectWarning(for: lang)).fSys(10, .medium).foregroundStyle(Color.orange).fixedSize(horizontal: false, vertical: true)
Button { triggerAutoAdvance(from: 1) } label: { HStack(spacing: 6) { Image(systemName: "checkmark.seal.fill").fSys(12.5, .bold).foregroundStyle(Color.green)
Text(lang == .en ? "I understand this shutter limit · Next →" : "我已了解该机身快门同步限制 · 点击进入第 3 步 →").fSys(10.5, .black).foregroundStyle(Color.white)
Spacer()
}.padding(.horizontal, 10).padding(.vertical, 7).background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8)) }
}.padding(9).background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 11))
}.padding(12).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18)) }
private var step3FilmStockView: some View { VStack(alignment: .leading, spacing: 9) { ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 6) { ForEach(FilmBrandCategory.allCases) { fBrand in
let isBrandSel = (onboardingFilmBrand == fBrand)
Button { withAnimation(.snappy) { onboardingFilmBrand = fBrand; if fBrand == .customISO { selectedFilmStockID = "custom" }}} label: {
Text(fBrand.title(for: lang)).fSys(11, .bold).foregroundStyle(isBrandSel ? Color.black : Color.white).padding(.horizontal, 10).padding(.vertical, 6).background(isBrandSel ? theme.accent : Color.white.opacity(0.10), in: Capsule()) }}}}
if onboardingFilmBrand == .customISO { LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 7) { ForEach(isoPresets, id: \.self) { val in
let isSel = (abs(filmISO - val) < 0.5 && selectedFilmStockID == "custom")
Button { withAnimation(.snappy) { selectedFilmStockID = "custom"; filmISO = val }
triggerAutoAdvance(from: 2) } label: {
Text("ISO \(Int(val))").fMono(12.5, .bold).foregroundStyle(isSel ? Color.black : Color.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(isSel ? theme.accent : Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10)) }}}} else {
ForEach(FilmStockModel.catalog.filter { $0.brand == onboardingFilmBrand }) { stock in
let isSel = (selectedFilmStockID == stock.id)
Button { withAnimation(.snappy) { selectedFilmStockID = stock.id; filmISO = stock.iso }
triggerAutoAdvance(from: 2) } label: { HStack { VStack(alignment: .leading, spacing: 1.5) { Text(stock.name).fSys(12, .bold).foregroundStyle(isSel ? Color.black : Color.white)
Text(stock.subtitle(for: lang)).fSys(9.5, .medium).foregroundStyle(isSel ? Color.black.opacity(0.75) : Color.white.opacity(0.6)) }
Spacer()
Text("ISO \(Int(stock.iso))").fMono(11, .black).foregroundStyle(isSel ? Color.black : theme.accent)
Image(systemName: isSel ? "checkmark.circle.fill" : "circle").font(.system(size: 14)).foregroundStyle(isSel ? Color.black : Color.white.opacity(0.4))
}.padding(.horizontal, 11).padding(.vertical, 8).background(isSel ? theme.accent : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11)) }}}
}.padding(13).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18)) }
private var step4LensApertureView: some View { VStack(alignment: .leading, spacing: 10) { LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
ForEach(maxAperturePresets, id: \.self) { val in
let selected = abs(maxLensAperture - val) < 0.05
Button { withAnimation(.snappy) { maxLensAperture = val; if aperture < val { aperture = val }}
triggerAutoAdvance(from: 3) } label: {
Text(String(format: "f/%.1f", val)).fMono(15, .black).foregroundStyle(selected ? Color.black : Color.white).frame(maxWidth: .infinity).padding(.vertical, 13).background(selected ? theme.accent : Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 11)) }}}
}.padding(13).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18)) }
private var step5FlashAndSummaryView: some View { VStack(alignment: .leading, spacing: 10) { ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 6) {
ForEach([FlashBrandCategory.godox, .contax, .canon, .nikon, .leicaFuji, .all, .custom]) { cat in
let isCatSel = (selectedBrandFilter == cat)
Button { withAnimation(.snappy) { selectedBrandFilter = cat; if cat == .custom { selectedFlashID = "custom" }}} label: {
Text(cat.title(for: lang)).fSys(11, .bold).foregroundStyle(isCatSel ? Color.black : Color.white).padding(.horizontal, 10).padding(.vertical, 6).background(isCatSel ? theme.accent : Color.white.opacity(0.10), in: Capsule()) }}}}
if selectedBrandFilter != .custom { ForEach(filteredFlashModels) { model in
let isModelSel = (selectedFlashID == model.id)
Button { withAnimation(.snappy) { selectedFlashID = model.id; flashGN = model.gnAtISO100 }} label: { HStack {
Text(lang == .en ? model.nameEn : model.nameZh).fSys(12, .semibold).foregroundStyle(isModelSel ? Color.black : Color.white).lineLimit(1)
Spacer()
Text("GN \(Int(model.gnAtISO100))").fMono(11, .black).foregroundStyle(isModelSel ? Color.black : theme.accent)
Image(systemName: isModelSel ? "checkmark.circle.fill" : "circle").font(.system(size: 14)).foregroundStyle(isModelSel ? Color.black : Color.white.opacity(0.4))
}.padding(.horizontal, 11).padding(.vertical, 8).background(isModelSel ? theme.accent : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11)) }}}
HStack(spacing: 10) { Button { flashGN = max(5.0, flashGN - 1.0); selectedFlashID = "custom" } label: { Image(systemName: "minus.circle.fill").font(.system(size: 21)).foregroundStyle(theme.accent) }
Slider(value: Binding(get: { flashGN }, set: { newVal in flashGN = round(newVal); selectedFlashID = "custom" }), in: 8...64, step: 1).tint(theme.accent)
Button { flashGN = min(80.0, flashGN + 1.0); selectedFlashID = "custom" } label: { Image(systemName: "plus.circle.fill").font(.system(size: 21)).foregroundStyle(theme.accent) }
Text("GN \(Int(flashGN))").fMono(12.5, .black).foregroundStyle(Color.white).frame(width: 50, alignment: .trailing) }
HStack(spacing: 8) { ForEach(AppTheme.allCases) { item in
let isSel = (themeRaw == item.rawValue)
Button { withAnimation(.snappy) { themeRaw = item.rawValue }} label: {
Text(item.name(for: lang)).fSys(10.5, .bold).foregroundStyle(isSel ? Color.black : Color.white).frame(maxWidth: .infinity).padding(.vertical, 7.5).background(isSel ? theme.accent : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9)) }}}
VStack(alignment: .leading, spacing: 5) { Text(lang == .en ? "EQUIPMENT READY SUMMARY" : "当前配置总览（随时可在顶部或设置修改）").fMono(9.5, .black).foregroundStyle(theme.accent)
Text("\(currentFormat.pillTitle(for: lang)) · \(currentSyncMode.shortBadge(for: lang, bodySync: maxSyncSpeed)) · ISO \(Int(filmISO)) · f/\(String(format: "%.1f", maxLensAperture)) · GN \(Int(flashGN))").fMono(10.5, .bold).foregroundStyle(Color.white)
}.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
}.padding(13).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18)) }
private var wizardBottomNavBar: some View { HStack(spacing: 10) { if stepIndex > 0 { Button { withAnimation(.snappy) { stepIndex -= 1 }} label: { HStack(spacing: 4) { Image(systemName: "chevron.left").fSys(12, .bold)
Text(lang == .en ? "Back" : "上一步").fSys(13, .bold)
}.foregroundStyle(Color.white).padding(.horizontal, 16).padding(.vertical, 12.5).background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14)) }}
Button { if stepIndex < 4 { withAnimation(.snappy) { stepIndex += 1 }} else { if aperture < maxLensAperture { aperture = maxLensAperture }
hasCompletedOnboarding = true
LocalLoopbackSyncBridge.shared.publishState([
"lf_iso": filmISO, "lf_gn": flashGN, "lf_distance": 2.0, "lf_aperture": aperture, "lf_shutter": Double(min(125, maxSyncSpeed)), "lf_sync_speed": Double(maxSyncSpeed), "lf_sync_mode": Double(syncModeRaw), "lf_film_format": Double(filmFormatRaw), "lf_theme": Double(themeRaw), "lf_max_aperture": maxLensAperture, "lf_exp_comp_ev": 0.0, "lf_aux_loss": 0.0, "lf_sync_ts": Date().timeIntervalSince1970
])
dismiss() }} label: { HStack(spacing: 6) {
Text(stepIndex < 4 ? (lang == .en ? "Next (Step \(stepIndex + 1)/5) →" : "下一步 · 当前第 \(stepIndex + 1)/5 步 →") : (lang == .en ? "Start Metering (5/5)" : "完成配置 · 进入测光表 (5/5)")).fSys(14, .black)
Image(systemName: stepIndex < 4 ? "arrow.right" : "bolt.fill").fSys(12.5, .bold)
}.foregroundStyle(Color.black).frame(maxWidth: .infinity).padding(.vertical, 12.5).background(theme.accent, in: RoundedRectangle(cornerRadius: 14)) }
}.padding(.horizontal, 18).padding(.vertical, 11).background(.ultraThinMaterial) }}
