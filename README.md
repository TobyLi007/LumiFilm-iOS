 # ⚡ LumiFilm v10.4 — Pro Analog Flash & Ambient Light Meter for iOS

 **Professional Manual Flash Calculator, Interactive Home Screen Widgets, Live Camera EV100 & LiDAR Distance Meter, and GPS Film Roll Logger for 135 & 120 Medium Format Cameras**  
 **专业 135 / 120 胶片摄影闪光测光表 · 3D 聚光拨轮 · 1×4 闪光模式 · 右下角实景测光测距 · 机顶小组件 · GPS 胶片手账**

 [![Build Unsigned IPA](https://github.com/TobyLi007/LumiFilm-iOS/actions/workflows/main.yml/badge.svg)](https://github.com/TobyLi007/LumiFilm-iOS/actions)
 [![Latest Release](https://img.shields.io/github/v/release/TobyLi007/LumiFilm-iOS?style=flat-square&logo=github&color=E5A93C)](https://github.com/TobyLi007/LumiFilm-iOS/releases/latest)
 [![Swift 5.10+](https://img.shields.io/badge/Swift-5.10%2B-F05138.svg?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
 [![iOS 17.0+](https://img.shields.io/badge/iOS-17.0%2B-000000.svg?style=flat-square&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
 [![License: MIT](https://img.shields.io/badge/License-MIT-28A745.svg?style=flat-square)](LICENSE)

 * **📲 Direct Download / 直接下载安装包**: [**⬇️ Download LumiFilm-Unsigned.ipa (Latest Release)**](https://github.com/TobyLi007/LumiFilm-iOS/releases/latest/download/LumiFilm-Unsigned.ipa)

 ## 📱 App & Widget Preview / 真机界面与桌面小组件预览

 | Main Mechanical Dial Meter<br>机械转盘测光主界面 | Modifiers & GPS Film Log<br>光学附件与 GPS 手账 | Live Camera EV100 & LiDAR Meter<br>全屏实景测光与激光测距 |
 | :---: | :---: | :---: |
 | <img src="Screenshots/Main%20page.jpg" width="250" alt="Main Meter Page" /> | <img src="Screenshots/Second%20Page.jpeg" width="250" alt="Modifiers and GPS Log Page" /> | <img src="Screenshots/Real-time%20ambient%20light%20Measure.jpg" width="250" alt="Live Camera EV100 Meter" /> |

 | Small Widget (`2×2`)<br>小号机顶组件 | Medium Widget (`4×2`)<br>中号参数组件 | Large Interactive Console (`4×4`)<br>大号桌面调参工作台 |
 | :---: | :---: | :---: |
 | <img src="Screenshots/Small%20Widget.jpg" width="220" alt="Small Widget" /> | <img src="Screenshots/Med%20Widget.jpg" width="260" alt="Medium Widget" /> | <img src="Screenshots/Large%20Widget.jpg" width="250" alt="Large 4x4 Widget" /> |

 ## 🌟 Core Highlights / 核心功能亮点 (v10.4)
 * **5-Row Illuminated 3D Drum Wheel (`iOSClockDrumWheelView`)**: Displays 2 selectable options above and 2 below the glowing center slot (`-2, -1, [0], +1, +2`) with smooth background fade and haptic/mechanical click ticks.
 * **1×4 Full-Width Flash Mode Stack (`闪光补光模式`)**: Dedicated 4-row vertical selector on the right console with EV tags and practical shooting descriptions (`主光防过曝 0EV联动`, `逆光柔补光 -1.3EV`, `眼神光微补 -2.0EV`, `暗室纯闪光 GN全额`), separated from the left 3D wheel by a subtle gradient divider.
 * **Bottom-Right Ergonomic Camera Meter Button (`实景测光 · 测距`)**: Placed at the bottom-right corner for effortless right-thumb access, launching the full-screen 30fps `EV100` + LiDAR/AF distance viewfinder.
 * **135 & 120 Format Sync & Bellows Engine**: Built-in shutter sync protection (`Pentax 67 1/30s vs LS 1/500s`, `Leica M 1/50s`, `Hasselblad 500 1/500s X-sync`), brand emblem badges (`KODAK`, `FUJI`, `800T`, `ILFORD`, `LOMO`), and numbered accordion Settings (`01`–`07`).

 ## 📐 Core Optical Formula / 核心光学公式
 ```text
 GN_eff = GN_100_zoom × sqrt(EI / 100) × 2^(-ΔEV_total / 2)
 ```

 ## 🚀 1-Minute Installation via Sideloadly
 1. Download `LumiFilm-Unsigned.ipa` from [**Releases**](https://github.com/TobyLi007/LumiFilm-iOS/releases/latest).
 2. Drag `LumiFilm-Unsigned.ipa` into [Sideloadly](https://sideloadly.io/) and click **Start**.
 3. Trust your Apple ID under **Settings → General → VPN & Device Management** on your iPhone.
