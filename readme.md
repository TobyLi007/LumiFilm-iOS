# ⚡ LumiFilm — Pro Analog Flash & Ambient Light Meter for iOS

**Professional Manual Flash Calculator, Interactive Home Screen Widgets, Live Camera EV100 & GPS Film Roll Logger for 135 & 120 Medium Format Cameras**

**专业 135 / 120 胶片摄影闪光测光表 · 机顶桌面小组件 · 实时环境光比 · GPS 胶片手账**

[Build Unsigned IPA](https://www.google.com/search?q=https://github.com/TobyLi007/LumiFilm-iOS/actions) [Latest Release](https://www.google.com/search?q=https://github.com/TobyLi007/LumiFilm-iOS/releases/latest)   [License: MIT](https://www.google.com/search?q=LICENSE)

* **🌐 Language / 语言切换**: [**🇬🇧 English Documentation**](#-english-documentation) · [**🇨🇳 中文说明文档**](#-中文说明文档-chinese-documentation)

* **📲 Direct Download / 直接下载安装包**: [⬇️ Download LumiFilm-Unsigned.ipa (Latest Release)](https://www.google.com/search?q=https://github.com/TobyLi007/LumiFilm-iOS/releases/latest/download/LumiFilm-Unsigned.ipa)

## 📱 App & Widget Preview / 真机界面与桌面小组件预览

### 1. Core App Interfaces / 主程序三大核心界面

| Main Mechanical Dial Meter  机械转盘测光主界面 | 2×2 Modifiers & GPS Film Log  光学附件四宫格与 GPS 手账 | Live Camera EV100 Spot Meter  iPhone 镜头实时环境光测光 | 
| ----- | ----- | ----- | 
| <img src="Screenshots/Main%20page.jpg" width="250" alt="Main Meter Page" /> | <img src="Screenshots/Second%20Page.jpeg" width="250" alt="Modifiers and GPS Log Page" /> | <img src="Screenshots/Real-time%20ambient%20light%20Measure.jpg" width="250" alt="Live Camera EV100 Meter" /> | 
| **Ambient Auto-Sum · Locked-Power Solver**  主光联动 · 锁定功率反推 · 语音口令 | **1-Tap Modifier Loss · GPS Roll Logger**  一键光损补偿 · GPS 街道定位手账 | **30fps CMOS EV100 · Calibration Trim**  30帧实时测光取景器 · 反射率校准 | 

### 2. Three-Size Home Screen Widgets / 三尺寸复古相机桌面小组件 (`2×2` · `4×2` · `4×4`)

| Small Widget (`2×2`)  小号机顶液晶组件 | Medium Widget (`4×2`)  中号只读参数机顶组件 | Large Interactive Console (`4×4`)  大号全功能桌面调参工作台 | 
| ----- | ----- | ----- | 
| <img src="Screenshots/Small%20Widget.jpg" width="220" alt="Small Widget" /> | <img src="Screenshots/Med%20Widget.jpg" width="260" alt="Medium Widget" /> | <img src="Screenshots/Large%20Widget.jpg" width="250" alt="Large 4x4 Widget" /> | 
| **Power Output + Camera Voice Key**  输出功率 + 语音输入相机快门键 | **Power Output + Read-Only Exposure Grid**  输出功率 + 当下 ISO/快门/距离/光圈只读屏 | **Direct Desktop Stepper for f/ · 1/s · m · EV · ISO**  桌面直接加减光圈、快门、距离、补偿与 ISO | 

## 🌐 English Documentation

**LumiFilm** is a native iOS utility crafted for analog film photographers shooting with mechanical 35mm (`135`) and Medium Format (`120`: `645`, `6×6`, `6×7`, `6×9`) cameras (Leica M, Hasselblad 500C/M, Rolleiflex, Pentax 67, Mamiya RB67/7, Contax G/TLA, Nikon FM2, Canon FD) paired with manual hot-shoe flashes. Tap **`中文 / EN`** in the top-right header bar inside the app to switch the entire UI and voice engine between English and Chinese.

### ✨ Key Features

* **1/3-Stop Manual Flash Power (`1/1` to `1/256`) & Inverse Locked-Power Solver**: Computes full-stop power fractions with a separate `±0.3 EV` fine trim badge, and back-solves optimal aperture or distance when power is locked.

* **`135` (36 exp) & `120` Medium Format (`645` 16 exp · `6×6` 12 exp · `6×7` 10 exp · `6×9` 8 exp)**: Automatically adjusts roll logger frame limits and applies format-specific close-up bellows extension compensation (`< 1.0m` to `< 1.3m`).

* **135 & 120 Camera Shutter Sync System & Leaf-Shutter (`LS`) Lens Toggle**: Built-in onboarding & settings presets for **Pentax 67/67II (`1/30s` cloth curtain vs. `90mm/165mm LS` `1/500s` leaf-shutter lenses)**, **Leica M (`⚡ 1/50s` cloth curtain)**, **Classic SLRs (`1/60s`–`1/250s`)**, **Hasselblad 500 / Rolleiflex (`1/500s` leaf shutter `X` vs `M` trap)**, and **Mamiya RB67/RZ67 (`1/400s` + bellows)**, with real-time **`🚨 CURTAIN BLACKOUT!`** interception and a 1-tap header bar **`Body ≤1/30s` ↔ `LS 1/500s`** switch.

* **Ambient + Flash Energy Auto-Summation & Live Camera `EV100` Meter**: Subtracts ambient exposure contribution so combined flash + ambient lighting never overexposes your subject.

* **Two-Level Film Stock Database (5 Brands · 37 Film Stocks) & Flash Catalog**: Select manufacturer (**Kodak / Fujifilm / CineStill / Ilford / Lomo & Harman**) then film stock to auto-set ISO, paired with built-in GN profiles for Godox, Contax TLA, Leica SF, Fujifilm EF, Nikon SB, and Canon Speedlite units.

* **Entitlement-Free `127.0.0.1` UDP Widget Theme Sync & GPS Roll Logger**: Syncs all 3 camera themes (**Film Brass**, **Sakura Mist**, **Threads Obsidian**) with Home Screen widgets in under 1 ms, and logs GPS street addresses (`📍`) for every frame.

### 🚀 1-Minute Installation via Sideloadly (No Mac Required)

1. Download `LumiFilm-Unsigned.ipa` from [Releases](https://www.google.com/search?q=https://github.com/TobyLi007/LumiFilm-iOS/releases/latest).

2. Open [Sideloadly](https://sideloadly.io/) on Windows or macOS, connect your iPhone via USB, drag `LumiFilm-Unsigned.ipa` in, and click **Start**.

3. Trust your Apple ID under **Settings → General → VPN & Device Management** on your iPhone, then add the **LumiFilm** widget to your Home Screen.

## 🇨🇳 中文说明文档 (Chinese Documentation)

**LumiFilm** 是一款专为 **135 全画幅 (36张)** 与 **120 中画幅（645 16张 / 6×6 12张 / 6×7 10张 / 6×9 8张）** 机械胶片相机与手动闪光灯打造的 iOS 原生测光与手账工具。

### 🌟 核心功能与 135 / 120 画幅联动表

| 胶片画幅选项 | 常见代表机型 | 手账每卷张数上限 | 自动近摄皮腔补偿阈值与系数 | 标头等效 135 灯头变焦提示 | 
| ----- | ----- | ----- | ----- | ----- | 
| **`135 (36张)`** | Leica M6 / Nikon FM2 / Contax G2 | **36 张/卷** | `< 1.0m` 按 `0.35 × (1.0 - d) EV` 补偿 | 1.0× 标准视角 | 
| **`645 (16张)`** | Contax 645 / Pentax 645 / Fuji GA645 | **16 张/卷** | `< 1.2m` 按 `0.50 × (1.2 - d) EV` 补偿 | 75/80mm 镜头等效 50mm | 
| **`6x6 (12张)`** | Hasselblad 500C/M / Rolleiflex 2.8F | **12 张/卷** | `< 1.2m` 按 `0.60 × (1.2 - d) EV` 补偿 | 80mm 镜头等效 44mm | 
| **`6x7 (10张)`** | Pentax 67 / Mamiya RB67 · RZ67 · 7 | **10 张/卷** | `< 1.3m` 按 `0.75 × (1.3 - d) EV` 补偿 | 105mm 镜头等效 50mm | 
| **`6x9 (8张)`** | Fujifilm GW690 / GSW690 | **8 张/卷** | `< 1.3m` 按 `0.75 × (1.3 - d) EV` 补偿 | 90mm 镜头等效 39mm | 

### ⚡ 135 与 120 常见胶片机身快门同步限制与硬件避坑指南（App 初始化内置）

| 机身/镜头快门类别 | 常见代表机型 | 闪光同步上限 | 致命硬件缺陷与 App 避坑保护机制 | 
| ----- | ----- | ----- | ----- | 
| **120 大画幅横走布帘 + LS 镜间镜头** | **Pentax 67 / 67II** | 机身 **`1/30s`**  LS 镜头 **`1/500s`** | 机身巨大横走布帘超 `1/30s` 必出半幅黑边！若挂载 **90mm f/2.8 LS / 165mm f/4 LS** 镜间快门镜头，点顶部 **`LS镜间 1/500s`** 一键切换全速同步（机身拨 `1/8s` 或 `X`，用镜头快门环控制 `1/125~1/500s`）。 | 
| **135 旁轴横走布帘** | **Leica M2 / M3 / M4 / M6 / MP** | **`⚡ 1/50s`** | 最高同步为 `1/30s` 与 `1/60s` 之间的 **`⚡ 1/50s` 专档**（拨到 `1/60s` 右侧边缘即出黑边）！老 M 机背后双 PC 孔切记插 **`⚡` 孔**，勿插灯泡孔。 | 
| **70/80年代横走布帘单反 & 645** | **Canon AE-1 / OM-1 / K1000 / X-700 / Mamiya 645** | **`1/60s`** | 横走橡胶丝绸布帘上限仅 `1/60s`，白天逆光补光需配合低感胶卷、小光圈或 ND 减光镜（645 换用 LS 镜头可切至 `1/500s`）。 | 
| **经典纵走金属快门单反** | **Nikon F3 (`1/80s`) / FM · FE (`1/125s`)** | **`1/80s ~ 1/125s`** | 纵走钢片超速会在画面上下切出黑边！注意 Nikon F3 最高仅 `1/80s` 且需倒片轴热靴转换座。 | 
| **高速钛合金蜂巢/纵走快门** | **Nikon FM2 / FE2 / FM3A (`1/250s`) / Contax G2 (`1/200s`)** | **`1/200s ~ 1/250s`** | 虽达机械纵走极限，但仍不支持数码 HSS 频闪，快门超过 `1/250s` 同样会被幕帘遮挡。 | 
| **120 镜间叶片快门系统** | **Hasselblad 500C/M / Rolleiflex / Mamiya 7 / 富士690** | **`1/500s` 全程同步** | 镜头内置叶片快门支持 `1/500s` 日光压光！**切记将镜头同步杆锁在 `X` 档**（误拨 `M` 档灯泡延时会导致快门未开先闪、整张全黑），且勿触碰 `V` 自拍档；`1/500s` 大光圈下自动计入 `-0.35 EV` 叶片效率补偿。 | 
| **120 镜间快门 + 皮腔对焦** | **Mamiya RB67 / RZ67** | **`1/400s` 全程同步** | Seiko 镜间快门支持 `1/400s` 同步（确认拨杆在 `X` 档），且采用皮腔伸展对焦，`<1.3m` 近摄自动叠加 `6×7` 皮腔补偿。 | 
| **135 镜间快门旁轴/袖珍机** | **Contax T2 / T3 / 佳能 QL17 GIII / 禄来 35** | **`1/500s` 全程同步** | 镜间叶片快门支持 `1/500s` 全速同步，白天户外直闪神器，但机顶小灯 GN 较小（`GN 9~14`），注意控制拍摄距离在 `1.5~2.5m`。 | 

### 📐 核心光学计算公式

```
GN_eff = GN_100_zoom × sqrt(EI / 100) × 2^(-ΔEV_total / 2)
其中：EI = ISO_box × 2^(ΔEV_push_pull)，GN_zoom = GN_rated × (Focal_mm / Rated_mm)^0.35

```

## 📄 License / 开源协议

Released under the [MIT License](https://www.google.com/search?q=LICENSE).