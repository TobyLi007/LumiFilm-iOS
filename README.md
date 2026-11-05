# ⚡ LumiFilm — Pro Analog Flash & Ambient Light Meter for iOS

**Professional Manual Flash Calculator, Interactive Home Screen Widgets, Live Camera EV100 & GPS Film Roll Logger for 135 & 120 Medium Format Cameras**  
**专业 135 / 120 胶片摄影闪光测光表 · 机顶桌面小组件 · 实时环境光比 · GPS 胶片手账**

[![Build Unsigned IPA](https://github.com/TobyLi007/LumiFilm-iOS/actions/workflows/main.yml/badge.svg)](https://github.com/TobyLi007/LumiFilm-iOS/actions)
[![Latest Release](https://img.shields.io/github/v/release/TobyLi007/LumiFilm-iOS?style=flat-square&logo=github&color=E5A93C)](https://github.com/TobyLi007/LumiFilm-iOS/releases/latest)
[![Swift 5.10+](https://img.shields.io/badge/Swift-5.10%2B-F05138.svg?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![iOS 17.0+](https://img.shields.io/badge/iOS-17.0%2B-000000.svg?style=flat-square&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![License: MIT](https://img.shields.io/badge/License-MIT-28A745.svg?style=flat-square)](LICENSE)

* **🌐 Language / 语言切换**: [**🇬🇧 English Documentation**](#-english-documentation) · [**🇨🇳 中文说明文档**](#-中文说明文档-chinese-documentation)
* **📲 Direct Download / 直接下载安装包**: [**⬇️ Download LumiFilm-Unsigned.ipa (Latest Release)**](https://github.com/TobyLi007/LumiFilm-iOS/releases/latest/download/LumiFilm-Unsigned.ipa)

## 📱 App & Widget Preview / 真机界面与桌面小组件预览

### 1. Core App Interfaces / 主程序三大核心界面

| Main Mechanical Dial Meter<br>机械转盘测光主界面 | 2×2 Modifiers & GPS Film Log<br>光学附件四宫格与 GPS 手账 | Live Camera EV100 Spot Meter<br>iPhone 镜头实时环境光测光 |
| :---: | :---: | :---: |
| <img src="Screenshots/Main%20page.jpg" width="250" alt="Main Meter Page" /> | <img src="Screenshots/Second%20Page.jpeg" width="250" alt="Modifiers and GPS Log Page" /> | <img src="Screenshots/Real-time%20ambient%20light%20Measure.jpg" width="250" alt="Live Camera EV100 Meter" /> |
| **Ambient Auto-Sum · Locked-Power Solver**<br>主光联动 · 锁定功率反推 · 语音口令 | **1-Tap Modifier Loss · GPS Roll Logger**<br>一键光损补偿 · GPS 街道定位手账 | **30fps CMOS EV100 · Calibration Trim**<br>30帧实时测光取景器 · 反射率校准 |

### 2. Three-Size Home Screen Widgets / 三尺寸复古相机桌面小组件 (`2×2` · `4×2` · `4×4`)

| Small Widget (`2×2`)<br>小号机顶液晶组件 | Medium Widget (`4×2`)<br>中号只读参数机顶组件 | Large Interactive Console (`4×4`)<br>大号全功能桌面调参工作台 |
| :---: | :---: | :---: |
| <img src="Screenshots/Small%20Widget.jpg" width="220" alt="Small Widget" /> | <img src="Screenshots/Med%20Widget.jpg" width="260" alt="Medium Widget" /> | <img src="Screenshots/Large%20Widget.jpg" width="250" alt="Large 4x4 Widget" /> |
| **Power Output + Camera Voice Key**<br>输出功率 + 语音输入相机快门键 | **Power Output + Read-Only Exposure Grid**<br>输出功率 + 当下 ISO/快门/距离/光圈只读屏 | **Direct Desktop Stepper for f/ · 1/s · m · EV · ISO**<br>桌面直接加减光圈、快门、距离、补偿与 ISO |

## 🌐 English Documentation

**LumiFilm** is a native iOS utility crafted for analog film photographers shooting with mechanical 35mm (`135`) and Medium Format (`120`: `645`, `6×6`, `6×7`, `6×9`) cameras (Leica M, Hasselblad 500C/M, Rolleiflex, Pentax 67, Mamiya RB67/7, Contax G/TLA, Nikon FM2, Canon FD) paired with manual hot-shoe flashes. Tap **`中文 / EN`** in the top-right header bar inside the app to switch the entire UI and voice engine between English and Chinese.

### ✨ Key Features
* **1/3-Stop Manual Flash Power (`1/1` to `1/256`) & Inverse Locked-Power Solver**: Computes full-stop power fractions with a separate `±0.3 EV` fine trim badge, and back-solves optimal aperture or distance when power is locked.
* **`135` (36 exp) & `120` Medium Format (`645` 16 exp · `6×6` 12 exp · `6×7` 10 exp · `6×9` 8 exp)**: Automatically adjusts roll logger frame limits and applies format-specific close-up bellows extension compensation (`< 1.0m` to `< 1.3m`).
* **Ambient + Flash Energy Auto-Summation & Live Camera `EV100` Meter**: Subtracts ambient exposure contribution so combined flash + ambient lighting never overexposes your subject.
* **Two-Level Film Stock Database (5 Brands · 37 Film Stocks) & Flash Catalog**: Select manufacturer (**Kodak / Fujifilm / CineStill / Ilford / Lomo & Harman**) then film stock to auto-set ISO, paired with built-in GN profiles for Godox, Contax TLA, Leica SF, Fujifilm EF, Nikon SB, and Canon Speedlite units.
* **Entitlement-Free `127.0.0.1` UDP Widget Theme Sync & GPS Roll Logger**: Syncs all 3 camera themes (**Film Brass**, **Sakura Mist**, **Threads Obsidian**) with Home Screen widgets in under 1 ms, and logs GPS street addresses (`📍`) for every frame.

### 🚀 1-Minute Installation via Sideloadly (No Mac Required)
1. Download `LumiFilm-Unsigned.ipa` from [**Releases**](https://github.com/TobyLi007/LumiFilm-iOS/releases/latest).
2. Open [Sideloadly](https://sideloadly.io/) on Windows or macOS, connect your iPhone via USB, drag `LumiFilm-Unsigned.ipa` in, and click **Start**.
3. Trust your Apple ID under **Settings → General → VPN & Device Management** on your iPhone, then add the **LumiFilm** widget to your Home Screen.

## 🇨🇳 中文说明文档 (Chinese Documentation)

**LumiFilm** 是一款专为 **135 全画幅 (36张)** 与 **120 中画幅（645 16张 / 6×6 12张 / 6×7 10张 / 6×9 8张）** 机械胶片相机与手动闪光灯打造的 iOS 原生测光与手账工具。

### 🌟 核心功能与 135 / 120 画幅联动表

| 胶片画幅选项 | 常见代表机型 | 手账每卷张数上限 | 自动近摄皮腔补偿阈值与系数 | 标头等效 135 灯头变焦提示 |
| :--- | :--- | :--- | :--- | :--- |
| **`135 (36张)`** | Leica M6 / Nikon FM2 / Contax G2 | **36 张/卷** | `< 1.0m` 按 `0.35 × (1.0 - d) EV` 补偿 | 1.0× 标准视角 |
| **`645 (16张)`** | Contax 645 / Pentax 645 / Fuji GA645 | **16 张/卷** | `< 1.2m` 按 `0.50 × (1.2 - d) EV` 补偿 | 75/80mm 镜头等效 50mm |
| **`6x6 (12张)`** | Hasselblad 500C/M / Rolleiflex 2.8F | **12 张/卷** | `< 1.2m` 按 `0.60 × (1.2 - d) EV` 补偿 | 80mm 镜头等效 44mm |
| **`6x7 (10张)`** | Pentax 67 / Mamiya RB67 · RZ67 · 7 | **10 张/卷** | `< 1.3m` 按 `0.75 × (1.3 - d) EV` 补偿 | 105mm 镜头等效 50mm |
| **`6x9 (8张)`** | Fujifilm GW690 / GSW690 | **8 张/卷** | `< 1.3m` 按 `0.75 × (1.3 - d) EV` 补偿 | 90mm 镜头等效 39mm |

### 📐 核心光学计算公式
```text
GN_eff = GN_100_zoom × sqrt(EI / 100) × 2^(-ΔEV_total / 2)
其中：EI = ISO_box × 2^(ΔEV_push_pull)，GN_zoom = GN_rated × (Focal_mm / Rated_mm)^0.35
```

## 📄 License / 开源协议
Released under the [MIT License](LICENSE).
