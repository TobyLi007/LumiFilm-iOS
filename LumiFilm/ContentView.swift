import SwiftUI
import WidgetKit
import AVFoundation

struct ContentView: View {
    @StateObject private var store = ExposureStore.shared
    @State private var selectedTab: Int = 0
    private let speechSynthesizer = AVSpeechSynthesizer()

    var body: some View {
        let solved = store.calculateRecommendedPower(distance: store.distanceM, fStop: store.aperture)

        TabView(selection: $selectedTab) {
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.lang == "en" ? "LumiFilm Exposure Log" : (store.lang == "ja" ? "銀塩フラッシュ露出手帖" : "银盐测光手账"))
                                .font(.headline)
                            Text("\(store.displayFlashTitle) (GN\(Int(store.activeGN))) · \(store.filmName) (ISO \(store.iso))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(store.lang == "en" ? "🌐 EN" : (store.lang == "ja" ? "🌐 JP" : "🌐 中文")) {
                            if store.lang == "zh" { store.lang = "en" }
                            else if store.lang == "en" { store.lang = "ja" }
                            else { store.lang = "zh" }
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(store.lang == "en" ? "🎙️ Instant Snap & Voice Command" : (store.lang == "ja" ? "🎙️ スナップ音声即算" : "🎙️ 抓拍语音/口令速算"))
                                .font(.subheadline.bold())
                            Spacer()
                            Button(store.lang == "en" ? "🔊 Speak" : (store.lang == "ja" ? "🔊 読み上げ" : "🔊 播报")) {
                                speakPower(solved.powerText)
                            }
                            .font(.caption.bold())
                        }
                        Text("⚡ \(store.lang == "en" ? "Set Flash Power to:" : (store.lang == "ja" ? "推奨フラッシュ出力:" : "请将闪光灯拨至:")) \(solved.powerText)")
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(.orange)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricCard(
                            title: store.lang == "en" ? "① Distance" : (store.lang == "ja" ? "① 撮影距離" : "① 拍摄距离"),
                            value: String(format: "%.1f m", store.distanceM),
                            sub: String(format: "≈ %.1f ft", store.distanceM * 3.28084)
                        )
                        MetricCard(
                            title: store.lang == "en" ? "② Flash Power" : (store.lang == "ja" ? "② 発光量" : "② 闪光灯功率比"),
                            value: solved.powerText,
                            sub: store.displayFlashTitle
                        )
                        MetricCard(
                            title: store.lang == "en" ? "③ Aperture" : (store.lang == "ja" ? "③ 絞り値" : "③ 光圈大小"),
                            value: String(format: "f/%.1f", store.aperture),
                            sub: "ISO \(store.iso)"
                        )
                        MetricCard(
                            title: store.lang == "en" ? "④ Shutter Speed" : (store.lang == "ja" ? "④ シャッター速度" : "④ 快门速度"),
                            value: "1/\(store.shutterDenom)s",
                            sub: "≤1/\(store.maxSyncDenom)s X-Sync"
                        )
                    }
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        HStack {
                            Text(store.lang == "en" ? "Subject Distance (m)" : (store.lang == "ja" ? "撮影距離 (m)" : "拍摄距离调节 (m)"))
                                .font(.caption.bold())
                            Spacer()
                            Text(String(format: "%.1f m", store.distanceM))
                                .font(.system(.caption, design: .monospaced))
                        }
                        Slider(value: $store.distanceM, in: 0.5...10.0, step: 0.1)

                        HStack {
                            Text(store.lang == "en" ? "Aperture (f-stop)" : (store.lang == "ja" ? "絞り値 (f-stop)" : "光圈环调节 (f-stop)"))
                                .font(.caption.bold())
                            Spacer()
                            Text(String(format: "f/%.1f", store.aperture))
                                .font(.system(.caption, design: .monospaced))
                        }
                        Slider(value: $store.aperture, in: 1.4...16.0, step: 0.2)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .tabItem {
                Label(store.lang == "en" ? "Meter" : (store.lang == "ja" ? "露出計" : "测光"), systemImage: "camera.aperture")
            }
            .tag(0)

            Form {
                Section(store.lang == "en" ? "Diffuser & Bounce Loss" : "柔光附件与跳闪补偿") {
                    Picker(store.lang == "en" ? "Diffuser" : "柔光附件", selection: $store.modifierLossEV) {
                        Text(store.lang == "en" ? "Direct Bare (0 EV)" : "裸灯直闪 (0 EV)").tag(0.0)
                        Text(store.lang == "en" ? "Dome Diffuser (-1.0 EV)" : "肥皂盒 (-1.0 EV)").tag(1.0)
                        Text(store.lang == "en" ? "Softbox (-1.8 EV)" : "柔光箱 (-1.8 EV)").tag(1.8)
                    }
                    Picker(store.lang == "en" ? "Bounce Angle" : "跳闪角度", selection: $store.bounceLossEV) {
                        Text(store.lang == "en" ? "0° Direct" : "0° 正面直打").tag(0.0)
                        Text(store.lang == "en" ? "45° Bounce (-1.7 EV)" : "45° 眼神板 (-1.7 EV)").tag(1.7)
                        Text(store.lang == "en" ? "75° Ceiling (-2.3 EV)" : "75° 白天花板 (-2.3 EV)").tag(2.3)
                    }
                }
            }
            .tabItem {
                Label(store.lang == "en" ? "Ambient" : (store.lang == "ja" ? "環境光補正" : "环境光修正"), systemImage: "sun.max")
            }
            .tag(1)

            Form {
                Section(store.lang == "en" ? "Flash & Manual GN (Auto User Custom)" : "闪光灯与手动 GN 值（输入后显示用户自定义）") {
                    Picker(store.lang == "en" ? "Preset Flash" : "预设闪光灯型号", selection: $store.flashId) {
                        ForEach(store.catalog) { item in
                            Text("\(item.shortName) (GN\(Int(item.baseGN)))").tag(item.id)
                        }
                    }
                    .onChange(of: store.flashId) { _ in
                        store.isCustomGN = false
                    }

                    Toggle(store.lang == "en" ? "Manual GN Input (User Custom)" : "手动输入 GN 值 (显示“用户自定义”)", isOn: $store.isCustomGN)

                    if store.isCustomGN {
                        Stepper(value: $store.customGNVal, in: 3...120, step: 1) {
                            HStack {
                                Text(store.displayFlashTitle).bold()
                                Spacer()
                                Text("GN \(Int(store.customGNVal))")
                                    .font(.system(.body, design: .monospaced).bold())
                            }
                        }
                    }
                }

                Section(store.lang == "en" ? "Film Roll ISO" : "本卷胶卷固定感光度 (ISO)") {
                    Picker("ISO", selection: $store.iso) {
                        Text("ISO 100").tag(100)
                        Text("ISO 200").tag(200)
                        Text("ISO 400 (Portra 400)").tag(400)
                        Text("ISO 800 (CineStill 800T)").tag(800)
                    }
                }
            }
            .tabItem {
                Label(store.lang == "en" ? "Settings" : (store.lang == "ja" ? "設定" : "用户设置"), systemImage: "gearshape")
            }
            .tag(2)
        }
    }

    private func speakPower(_ powerText: String) {
        let msg = "距离 \(String(format: "%.1f", store.distanceM)) 米，光圈 \(String(format: "%.1f", store.aperture))，请将闪光灯拨至 \(powerText) 功率。"
        let utterance = AVSpeechUtterance(string: msg)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        speechSynthesizer.speak(utterance)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let sub: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.title2, design: .monospaced).bold())
            Text(sub).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
