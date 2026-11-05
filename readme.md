# ⚡ LumiFilm — Pro Analog Flash & Ambient Meter for iOS

**专业胶片摄影闪光测光表 · 机顶桌面小组件 · 实时环境光比 · GPS 胶片手账**

[Build Unsigned IPA](https://www.google.com/search?q=https://github.com/TobyLi007/LumiFilm-iOS/actions)
[Latest Release](https://www.google.com/search?q=https://github.com/TobyLi007/LumiFilm-iOS/releases/latest)
[](https://swift.org)
[](https://developer.apple.com/ios/)
[License: MIT](https://www.google.com/search?q=LICENSE)

专为机械胶片相机（Leica M / Hasselblad / Contax / Nikon FM / Canon FD 等）与手动热靴闪光灯打造的 iOS 原生测光与手账工具。  
*A native SwiftUI companion engineered for analog film photographers to master manual flash power output, ambient-flash ratio, optical modifier compensation, and 36-frame GPS roll logging.*

* **一键下载最新安装包**：[⬇️ 下载 LumiFilm-Unsigned.ipa (v9.3.0)](https://www.google.com/search?q=https://github.com/TobyLi007/LumiFilm-iOS/releases/latest/download/LumiFilm-Unsigned.ipa)
* **快速导航**：[📱 真机界面预览](#-真机界面与桌面小组件预览-app--widget-gallery) · [🌟 核心功能亮点](#-核心功能亮点-key-features) · [📐 核心光学算法](#-核心光学算法与曝光模型) · [🚀 Sideloadly 安装指南](#-免-mac-一键安装指南-sideloadly)

## 📱 真机界面与桌面小组件预览 (App & Widget Gallery)

| 1. 机械转盘测光主界面 | 2. 光学附件 2×2 四宫格 & GPS 手账 | 3. 桌面机顶液晶小组件 |
| :---: | :---: | :---: |
|  |  |  |
| **主光联动 · 实时相机测光 · 锁定功率反推** | **一键光损补偿 · GPS 街道定位胶片手账** | **机顶 LCD 功率窗 · 语音输入相机快门键** |

## 🌟 核心功能亮点 (Key Features)

### 1. 精准闪光输出档位与 1/3 档微调计算 (`1/1` ~ `1/256`)
* **整档 + 1/3 档微调双指示**：自动将所需闪光能量换算为标准手动档位（`1/1`、`1/2`、`1/4`、`1/8`、`1/16`、`1/32`、`1/64`、`1/128`）与独立 `±0.3 EV` 微调徽章。
* **全参数反向锁定求解 (Locked-Power Solver)**：支持锁死闪光灯功率档位、光圈（`f/1` ~ `f/22`）、快门（`1/1s` ~ `1/4000s`）或拍摄距离（`0.5m` ~ `15m`）中的任意维度，转动机械拨盘即可反向推算其余最佳曝光组合。
* **HSS 高速同步光损预警**：当快门速度超出机身最高闪光同步速度（X-Sync，如 `1/125s`）时，自动计入高速同步光损并给出橙色高亮提示。

### 2. 主光联动防过曝算法 & iPhone 镜头实时环境光测光 (`Live EV100`)
* **四种闪光补光策略**：支持 **主光联动 (防过曝自动扣减环境光贡献)**、**纯闪光暗室**、**自然逆光补光 (-1.3 EV)** 与 **柔和眼神光 (-2.0 EV)**。
* **iPhone 传感器实时环境光测光**：基于 `AVCaptureSession` 实时读取镜头光圈、快门积分时间与 ISO 元数据，动态解算现场环境光 `EV100` 并提供大画幅取景框与 `±1.0 EV` 校准微调。

### 3. 三尺寸桌面与锁屏小组件 (`WidgetKit` + `AppIntents`)
* **小号 (2×2) & 中号 (4×2) 机顶液晶贴**：采用复古相机机顶屏 + 快门微动按键设计，只读显示当前 **闪光输出功率、ISO、快门速度、拍摄距离与光圈**，底部配备一键 **「🎙️ 语音输入」** 相机快门键。
* **大号 (4×4) 全功能桌面测光工作台**：无需打开 App，直接在 iPhone 桌面点击 `−` / `+` 调节 **光圈、快门速度、拍摄距离、曝光补偿 (`±0.3 EV` 步进) 与感光度 ISO**，并支持一键语音调参与语音播报。
* **本地回环毫秒级主题互通 (`127.0.0.1:49188` UDP Bridge)**：即使在免费 Apple ID 侧载（无付费 App Group 权限）环境下，桌面小组件也能与主 App 实时同步三套自定义相机主题配色。

### 4. 二级「胶片厂商 → 胶卷型号」数据库 & 主流闪光灯硬件库
* **5 大胶片厂商 · 37 款真实胶卷**：采用「第一步选厂商 → 第二步选胶卷」二级交互，涵盖 **Kodak 柯达**（Portra 160/400/800、Gold 200、UltraMax 400、Ektar 100、Vision3 50D/250D/500T、Tri-X 400 等）、**Fujifilm 富士**（C200、Superia 400、Pro 400H、Natura 1600、Velvia 50、Acros 100 II 等）、**CineStill**（800T、400D、50D、BwXX）、**Ilford 伊尔福**（HP5+ 400、FP4+ 125、Delta 3200 等）与 **Harman Phoenix / Lomo / Fomapan**。
* **主流热靴闪光灯内置参数**：内置 **Godox 神牛**（Lux Junior / Senior / Cadet / Elf、V350 / TT350、V860III、V1）、**Contax TLA 140 / 200 / 280**、**Leica SF 20 / 24D / 40 / 60**、**Fujifilm EF-X20**、**Nikon SB** 与 **Canon Speedlite** 系列标称 GN 指数。

### 5. 免提语音口令识别 & 36 张 GPS 胶片手账
* **自然语音识别调参 + 场景口令**：支持直接说出“*光圈 4，快门 125，距离 2 米*”或场景关键词（如“*大太阳天*”、“*树荫逆光*”、“*室内咖啡馆*”、“*白顶跳闪*”），自动完成参数设定并语音播报建议闪光功率。
* **GPS 自动定位胶片手账**：基于 `CoreLocation` + `CLGeocoder` 一键反地理编码获取当前拍摄城市与街道名称，完整记录每卷 36 张的 **胶卷型号、闪光功率、光圈、快门、距离、附件光损、📍拍摄地址与📝画面备注**，支持一键导出 Markdown 表格。

## 🎨 三套内置相机主题风格 (Built-in Camera Themes)

| 主题名称 | 视觉灵感与质感表现 | 适用场景 |
| :--- | :--- | :--- |
| **Film Brass (黑漆露铜)** | 复古徕卡黑漆机身搭配温润黄铜露铜拨盘与暖琥珀液晶字符 | 经典机械旁轴与复古街拍 |
| **Sakura Mist (雾粉微光)** | 清新淡雅的莫兰迪樱花雾粉搭配温润香槟米白与柔雾灰底色 | 日系清新、人像与柔和光影 |
| **Threads Obsidian (曜石纯黑)** | 极简高对比度纯黑阳极氧化机身与钛银色机械刻度 | 夜间暗光街拍与暗房环境 |

## 📐 核心光学算法与曝光模型

LumiFilm 遵循国际标准胶片闪光摄影光学定律，综合解算以下 5 项修正因子：

1. **有效闪光指数 (`GN_eff`) 计算公式**：
   ```text
   GN_eff = GN_100_zoom × sqrt(EI / 100) × 2^(-ΔEV_total / 2)
   其中有效感光度 EI = ISO_box × 2^(ΔEV_push_pull)
   ```
2. **灯头焦距变焦折算 (`GN_100_zoom`)**：根据菲涅尔透镜聚光特性，按 `GN_zoom = GN_rated × (Focal_mm / Rated_mm)^0.35` 动态折算不同镜头焦段下的有效指数。
3. **近摄反平方律衰减修正**：当拍摄距离 `d < 1.0 m` 时，按 `0.35 × (1.0 - d) EV` 自动补偿近摄皮腔延伸与灯头视差引起的额外光损。
4. **光学附件与滤镜累计损耗 (`ΔEV_total`)**：叠加柔光罩（肥皂盒 `-1.0 EV` / 球形柔光 `-1.5 EV` / 柔光箱 `-2.0 EV`）、跳闪角度（60°眼神板 `-1.5 EV` / 90°白顶 `-2.0 EV` / 反跳白墙 `-2.5 EV`）、镜头滤镜（黑柔 `-0.3 EV` / CPL `-1.0 EV` / ND4 `-2.0 EV` / ND8 `-3.0 EV`）、HSS 高速同步损耗及用户曝光补偿。
5. **主光联动环境光合成模型**：根据相机当前光圈 `N`、快门分母 `S` 与有效感光度 `EI` 计算相机接收本底曝光值 `EV_cam = log2(N² × S) - log2(EI / 100)`；当现场环境光接近目标曝光时，自动按线性光能量守恒扣减闪光输出比例，防止背景与主体叠加过曝。

## 🚀 免 Mac 一键安装指南 (Sideloadly)

本项目已配置全自动 **GitHub Actions 云端编译与自动 Release 流水线**，无需本地拥有 Mac 电脑或安装 Xcode，即可直接下载安装：

1. **下载最新 `.ipa` 安装包**：
   直接点击右侧 **[Releases](https://www.google.com/search?q=https://github.com/TobyLi007/LumiFilm-iOS/releases/latest)** 下载最新版本的 `LumiFilm-Unsigned.ipa`。
2. **使用 Sideloadly 签名安装到 iPhone**：
   在 Windows 或 macOS 电脑上下载并打开 [Sideloadly](https://sideloadly.io/)，使用数据线连接 iPhone，将 `LumiFilm-Unsigned.ipa` 拖入 Sideloadly 窗口，输入你的 Apple ID 账号点击 **Start**。
3. **信任开发者证书并添加桌面小组件**：
   * 安装完成后，在 iPhone 上依次进入 **设置 → 通用 → VPN 与设备管理**，点击你的 Apple ID 并选择「信任」（如在 iOS 16+ 首次侧载，请同时开启 **设置 → 隐私与安全性 → 开发者模式**）。
   * 打开 **LumiFilm** 完成 10 秒首次器材设定，随后长按 iPhone 桌面空白处点击左上角 **「编辑 → 添加小组件」**，搜索 **LumiFilm** 即可添加小号、中号或大号（4×4）桌面测光组件。

## 🛠️ 本地开发与构建 (Local Xcode Build)

仓库根目录下的 `LumiFilm/`、`LumiFilmWidget/` 与 `project.yml` 由 GitHub Actions 在每次构建后自动同步保持最新。如果你使用 macOS 并希望在本地 Xcode 中调试：

```bash
# 1. 克隆仓库
git clone https://github.com/TobyLi007/LumiFilm-iOS.git
cd LumiFilm-iOS

# 2. 安装 XcodeGen 并生成 Xcode 工程
brew install xcodegen
xcodegen generate

# 3. 使用 Xcode 打开工程
open LumiFilm.xcodeproj
```

## 📄 开源协议 (License)

本项目基于 [MIT License](https://www.google.com/search?q=LICENSE) 开源。所有语音识别、相机实时测光与 GPS 胶片手账数据均 100% 存储于设备本地，不上传任何云端服务器。