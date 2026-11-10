# ⚡ LumiFilm v10.6.2 — Pro Analog Flash & Ambient Light Meter for iOS

**Professional Manual Flash Calculator, 5-Parameter 3D Drum Wheel (with Zero-Bounce 1/3-Stop EV Bias), 1×4 Flash Mode Console, Instant Tap-Spot Camera EV100 & LiDAR Hold Meter, Slow-Sync Reciprocity Engine, Interactive Home Screen Widgets & GPS Film Roll Logger for 135 & 120 Medium Format Cameras**  
**专业 135 / 120 胶片摄影闪光测光表 · 48pt 聚光功率主屏 · 5维零跳动 3D 滚轮（含曝光补偿） · 1×4 闪光模式 · 实景静止即时点测光测距+HOLD锁定 · 慢门倒易律 · 机顶小组件 · GPS 胶片手账**

[Build Unsigned IPA](https://www.google.com/search?q=https://github.com/TobyLi007/LumiFilm-iOS/actions)
[Latest Release](https://www.google.com/search?q=https://github.com/TobyLi007/LumiFilm-iOS/releases/latest)
[](https://swift.org)
[](https://developer.apple.com/ios/)
[License: MIT](https://www.google.com/search?q=LICENSE)

* **🌐 Language / 语言切换**: [**🇬🇧 English Documentation**](#-english-documentation) · [**🇨🇳 中文说明文档**](#-中文说明文档-chinese-documentation) · [**📜 Full Changelog / 全量更新日志 (`WHATS_NEW.md`)**](WHATS_NEW.md)
* **📲 Direct Download / 直接下载安装包**: [⬇️ Download LumiFilm-Unsigned.ipa (Latest Release)](https://www.google.com/search?q=https://github.com/TobyLi007/LumiFilm-iOS/releases/latest/download/LumiFilm-Unsigned.ipa)

## 📱 App & Widget Preview / 真机界面与桌面小组件预览

### 1. Core App Interfaces / 主程序三大核心界面

| Main Mechanical Dial Meter<br>机械转盘测光主界面 | Segmented Modifiers & GPS Log<br>分段附件四宫格与 GPS 手账 | Tap-Spot EV100 & LiDAR Hold Meter<br>全屏任意点测光与激光测距锁定 |
| :---: | :---: | :---: |
| &lt;img src=&quot;Screenshots/Main%20page.jpg&quot; width=&quot;250&quot; alt=&quot;Main Meter Page&quot; /&gt; | &lt;img src=&quot;Screenshots/Second%20Page.jpeg&quot; width=&quot;250&quot; alt=&quot;Modifiers and GPS Log Page&quot; /&gt; | &lt;img src=&quot;Screenshots/Real-time%20ambient%20light%20Measure.jpg&quot; width=&quot;250&quot; alt=&quot;Live Camera EV100 Meter&quot; /&gt; |
| **48pt Hero Output · 5-Tile Grid · 3D Wheel EV Bias**<br>48pt 聚光主屏 · 5卡片定高参数阵 · 3D滚轮调EV | **Segmented Switcher · Auto Frame Rollback**<br>附件/手账一键切换 · 删帧自动回退帧号 | **Stationary Tap-Spot LiDAR/AF · ❄️ HOLD Lock**<br>静止点击即刻精准测距 · ❄️ HOLD 读数锁定 |

### 2. Three-Size Home Screen Widgets / 三尺寸复古相机桌面小组件 (`2×2` · `4×2` · `4×4`)

| Small Widget (`2×2`)<br>小号机顶液晶组件 | Medium Widget (`4×2`)<br>中号只读参数机顶组件 | Large Interactive Console (`4×4`)<br>大号全功能桌面调参工作台 |
| :---: | :---: | :---: |
| &lt;img src=&quot;Screenshots/Small%20Widget.jpg&quot; width=&quot;220&quot; alt=&quot;Small Widget&quot; /&gt; | &lt;img src=&quot;Screenshots/Med%20Widget.jpg&quot; width=&quot;260&quot; alt=&quot;Medium Widget&quot; /&gt; | &lt;img src=&quot;Screenshots/Large%20Widget.jpg&quot; width=&quot;250&quot; alt=&quot;Large 4x4 Widget&quot; /&gt; |
| **Power Output + Camera Voice Key**<br>输出功率 + 语音输入相机快门键 | **Power Output + Read-Only Exposure Grid**<br>输出功率 + 当下 ISO/快门/距离/光圈只读屏 | **Direct Desktop Stepper for f/ · 1/s · m · EV · ISO**<br>桌面直接加减光圈、快门、距离、补偿与 ISO |

## 🌐 English Documentation

**LumiFilm** is a native iOS utility crafted for analog film photographers shooting with mechanical 35mm (`135`) and Medium Format (`120`: `645`, `6×6`, `6×7`, `6×9`) cameras (Leica M, Hasselblad 500C/M, Rolleiflex, Pentax 67, Mamiya RB67/7, Contax G/TLA, Nikon FM2, Canon FD) paired with manual hot-shoe flashes. See [**`WHATS_NEW.md`**](WHATS_NEW.md) for the complete version evolution from `v1.0.0` to `v10.6.2`.

### ✨ Key Features (v10.6.2)
* **Decoupled Optical Physics & Creative Bias Engine**: Strictly separates physical optical light loss (`Diffuser + Bounce + Filter + HSS + Bellows`) from creative flash bias (`-1.3 EV Fill`, `-2.0 EV Catchlight`, and `±2.0 EV Bias`), guaranteeing 100% accurate inverse aperture/distance solving when flash power is locked.
* **Zero-Bounce 5-Parameter Grid & 3D Drum Wheel (including `1/3`-Stop EV Bias)**: All 5 parameter cards (`Distance`, `Aperture`, `Shutter`, `Power`, `EV Bias`) share a rock-solid `54pt` height and constant `19pt` typography so switching to `EV Bias` never bounces or shifts the UI.
* **Instant Stationary Tap-Spot LiDAR/AF Distance & `❄️ HOLD` Freeze**: Tapping any spot on the viewfinder dynamically samples the LiDAR depth map at the exact tapped coordinate, triggers an immediate active `.autoFocus` + `.autoExpose` sweep (even when the phone is held completely still), and bypasses smoothing inertia for instant distance & EV lock.
* **Slow-Sync Shutter Speeds (`15"`–`1"`) & Film Reciprocity Compensation**: Supports multi-second slow-sync exposures (`15"`, `8"`, `4"`, `2"`, `1"`) and automatically computes brand-specific Schwarzschild film reciprocity compensation seconds for Kodak, Fujifilm, CineStill, and Ilford/Lomo stocks.
* **100% Synchronized Home Screen Widgets**: Syncs effective pushed/pulled `EI`, zoom-adjusted `GN`, flash role bias, and ambient auto-sum factors via `127.0.0.1` UDP so Home Screen widgets match the main app's power readout to the exact `1/3` stop.
* **Segmented Tab 2 (`🎛️ Optical Modifiers` / `🎞️ GPS Roll Log`) & Auto Frame Rollback**: Switch between the 2×2 modifier grid and GPS roll logger without long scrolling; deleting the latest logged frame automatically rolls back the next frame counter.

### 🚀 1-Minute Installation via Sideloadly (No Mac Required)
1. Download `LumiFilm-Unsigned.ipa` from [Releases](https://www.google.com/search?q=https://github.com/TobyLi007/LumiFilm-iOS/releases/latest).
2. Open [Sideloadly](https://sideloadly.io/) on Windows or macOS, connect your iPhone via USB, drag `LumiFilm-Unsigned.ipa` in, and click **Start**.
3. Trust your Apple ID under **Settings → General → VPN & Device Management** on your iPhone, then add the **LumiFilm** widget to your Home Screen.

## 🇨🇳 中文说明文档 (Chinese Documentation)

**LumiFilm** 是一款专为 **135 全画幅 (36张)** 与 **120 中画幅（645 16张 / 6×6 12张 / 6×7 10张 / 6×9 8张）** 机械胶片相机与手动闪光灯打造的 iOS 原生测光与手账工具。从 `v1.0.0` 到 `v10.6.2` 的完整历史记录请查阅 [**`WHATS_NEW.md`**](WHATS_NEW.md)。

### 🌟 v10.6.2 核心亮点
* **实景相机「静止点击即时精准测距」+「❄️ HOLD 读数锁定」**：点击画面任意位置时，LiDAR 深度图自动映射并采样点击处坐标，同时强制触发硬件单次主动对焦（`.autoFocus`）与零惯性即时采样，无需晃动手机即可瞬间测准点击处物距与 `EV100`。
* **零跳动定高 5 卡片参数阵 + 3D 滚轮调曝光补偿**：统一锁定 5 张参数卡片（距离、光圈、快门、功率、曝光补偿）为固定 `54pt` 高度与 `19pt` 恒定字号，并锁定快捷胶囊条 `28pt` 高度，点击切换至「曝光补偿 EV」时界面稳如磐石、绝不弹跳错位。
* **物理光损与创意闪光偏置解耦算法 + 小组件 100% 同步**：彻底修复锁定功率反推光圈/距离时的耦合偏差，并实时将迫冲折算 `EI`、灯头变焦有效 `GN`、闪光模式偏置与环境光扣减同步至桌面小组件。
* **夜景慢门同步档位 (`15"`～`1"`) 与胶卷倒易律失效提示**：支持多秒慢门同步并按胶卷品牌自动提示背景倒易律补偿秒数。
* **第二页「🎛️ 光学附件 / 🎞️ 胶片手账」分段切换 + 删帧自动回退帧号**。

### 🎞️ 135 / 120 画幅联动表

| 胶片画幅选项 | 常见代表机型 | 手账每卷张数上限 | 自动近摄皮腔补偿阈值与系数 | 标头等效 135 灯头变焦提示 |
| :--- | :--- | :--- | :--- | :--- |
| **`135 (36张)`** | Leica M6 / Nikon FM2 / Contax G2 | **36 张/卷** | `< 1.0m` 按 `0.35 × (1.0 - d) EV` 补偿 | 1.0× 标准视角 |
| **`645 (16张)`** | Contax 645 / Pentax 645 / Fuji GA645 | **16 张/卷** | `< 1.2m` 按 `0.50 × (1.2 - d) EV` 补偿 | 75/80mm 镜头等效 50mm |
| **`6x6 (12张)`** | Hasselblad 500C/M / Rolleiflex 2.8F | **12 张/卷** | `< 1.2m` 按 `0.60 × (1.2 - d) EV` 补偿 | 80mm 镜头等效 44mm |
| **`6x7 (10张)`** | Pentax 67 / Mamiya RB67 · RZ67 · 7 | **10 张/卷** | `< 1.3m` 按 `0.75 × (1.3 - d) EV` 补偿 | 105mm 镜头等效 50mm |
| **`6x9 (8张)`** | Fujifilm GW690 / GSW690 | **8 张/卷** | `< 1.3m` 按 `0.75 × (1.3 - d) EV` 补偿 | 90mm 镜头等效 39mm |

### 📐 核心光学计算公式
```text
GN_eff = GN_100_zoom × sqrt(EI / 100) × 2^(-ΔEV_optical_loss / 2)
P_flash = (Aperture / (GN_eff / Distance))^2 × Factor_ambient × 2^(ΔEV_role_bias + ΔEV_comp)
```

## 📄 License / 开源协议
Released under the [MIT License](https://www.google.com/search?q=LICENSE).