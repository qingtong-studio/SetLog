<div align="center">

<img src="logo.svg" alt="SetLog" width="120" />

# SetLog

**面向力量训练者的 SwiftUI + SwiftData 训练日志。**
组级别记录，支持 RPE、休息计时、周期化与模板 — 完全离线。

**简体中文** · [日本語](README.ja.md) · [English](README.md)

[![Platform](https://img.shields.io/badge/platform-iOS%2026.2%2B-blue.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-%E2%9C%93-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![SwiftData](https://img.shields.io/badge/SwiftData-%E2%9C%93-blue.svg)](https://developer.apple.com/documentation/swiftdata)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

</div>

---

## 项目简介

**SetLog** 是一款严肃训练者用的 iOS 训练日志，围绕力量训练的真实工作流构建：热身渐进、按 RPE 评估的正式组、有意识的组间休息，以及结构化的分化周。基于 SwiftData 的离线优先架构，配有为录数据优化的自定义键盘，开箱即用一个完整的五日分化周期。

<!-- TODO: 替换为发布用的 hero 图。可直接用 `screenshots/light/01-home-dashboard.png`。 -->
<p align="center">
  <img src="screenshots/light/01-home-dashboard.png" alt="主屏" width="280" />
</p>

---

## 功能特性

### 训练记录
- **实时训练计时器**：可暂停 / 继续，记录总时长以及每个组的完成时间戳。
- **组级别追踪**：目标次数 vs 实际次数、重量（KG / LB）、RPE 6–10、组间休息秒数、完成时间。
- **组类型区分**：`warmup`（热身组）与 `working`（正式组）独立着色，4 组热身渐进不会污染容量统计。
- **训练备注**：每个 session 单独的备注栏（例如：_"深蹲状态不错，下次把第三组提升到 102.5kg。"_）。
- **减载模式**：可将一次训练标记为减载 — 不更新动作偏好重量、不回写模板，保证轻量日不影响默认配置。

### 周期化（Macrocycle / Mesocycle）
- 在一个 **macrocycle 计划** 内堆叠多个 **mesocycle**（增肌、力量、耐力…）。
- 每周的负荷倍率、是否减载周、RPE 上限、目标次数区间均可单独配置。
- 内置 setup 向导生成 4–6 周的标准 mesocycle 结构。

### 模板与每日计划
- 内置 **v4 五日分化**：周一·腿、周二·推（力量）、周三·拉、周四·手臂+肩、周五·平衡调和。
- **DailyPlan** 允许只为某一天覆盖模板，不必修改模板本身。
- 每个动作的"偏好重量"会在完成一次后自动学习并继承到下次训练。

### 动作库
- 内置 **60+ 动作**，覆盖六个肌群分类：胸 / 背 / 腿 / 肩 / 手臂 / 核心。
- 支持自定义动作，可挑 SF Symbols 图标 + 主题色。
- 每个动作支持：
  - **重量模式**：`standard`（杠铃 / 器械总重）或 `singleHand`（哑铃单侧重；容量计算自动 ×2）。
  - **计入体重**：负重引体 / 双杠臂屈伸可把自身体重折算进容量。

### 自定义数字键盘
4×4 的自定义键盘替代系统键盘录入重量 / 次数，含轻触震动反馈，提供四个动作键：

| 键位 | 行为 |
|---|---|
| 收起 | 收起键盘 |
| 复制 → | 把当前值复制到右侧下一组 |
| 填充 ↓ | 把当前值灌入下方所有空格 |
| 确定 | 提交并跳到下一个焦点 |

### 历史与统计
- **日历视图**、**列表视图**、**单次详情视图**三种切换。
- 聚合数据：总训练日、累计容量（自动 KG/LB 换算）、累计完成组数、最近一次训练日期。
- 单次 session 的动作分布、组数、RPE 分布与容量图表。

### 数据导出（Markdown / CSV / JSON）
- 三种格式 × 四种时间范围（全部 / 最近 7 天 / 最近 30 天 / 自定义）。
- **JSON** 是可回环的 — 演示数据就是用同一套 schema。
- **CSV** 写入了 UTF‑8 BOM，Excel 直接识别中文。
- **Markdown** 可一键分享到备忘录、Bear、Obsidian、GitHub。

### 组间休息计时与通知
- 完成一组自动启动，可暂停，可单独设置时长。
- 倒计时结束发本地通知（`rest-timer-complete`），可以放下手机继续休息。

### 界面细节
- 完整 **深色模式**（橙色作为主色调贯穿两套主题）。
- 动作图标使用 **SF Symbols**。
- 训练中支持拖拽重排动作顺序。
- iPad 友好（Universal device family）。

---

## 演示数据

首次启动时会从 `SetLog/DemoSessions.json` 自动导入 **14 次真实训练**（2026‑04‑24 → 2026‑05‑14，覆盖 v4 五日分化的完整一个 mesocycle）：

| 指标 | 数值 |
|---|---|
| Session 数 | 14 |
| 总组数 | 260 |
| 总容量 | **89,017 kg** |
| 时间跨度 | 3 周 |
| 覆盖部位 | 胸 · 背 · 腿 · 肩 · 手臂 · 核心 |
| 涵盖能力 | 热身渐进、RPE 6–10、自定义休息、负重引体 & 双杠、单边哑铃模式、未完成中的 session |

最后一次 session（2026‑05‑14，_v4‑周四·手臂+肩_）**故意留作未完成** — 打开"训练"标签即可立即继续这次训练。

> 演示数据就是普通 JSON，把 `SetLog/DemoSessions.json` 换成你自己导出的文件，下次干净安装就会用你的数据。

---

## 应用截图

<details open>
<summary><strong>浅色模式</strong></summary>

| 主屏 | 模板库 | 模板详情 | 添加动作 |
|---|---|---|---|
| <img src="screenshots/light/01-home-dashboard.png" width="180"/> | <img src="screenshots/light/02-templates.png" width="180"/> | <img src="screenshots/light/03-template-detail.png" width="180"/> | <img src="screenshots/light/05-add-exercise.png" width="180"/> |

| 当前训练 | 训练进行中 | 训练总结 | 我的 |
|---|---|---|---|
| <img src="screenshots/light/04-current-workout.png" width="180"/> | <img src="screenshots/light/04-current-workout-running.png" width="180"/> | <img src="screenshots/light/04d-workout-summary.png" width="180"/> | <img src="screenshots/light/13-profile.png" width="180"/> |

| 历史日历 | 历史列表 | 历史详情 |
|---|---|---|
| <img src="screenshots/light/08-history-calendar.png" width="180"/> | <img src="screenshots/light/09-history-list.png" width="180"/> | <img src="screenshots/light/10-history-detail.png" width="180"/> |

</details>

<details>
<summary><strong>深色模式</strong></summary>

| 主屏 | 历史日历 | 历史列表 | 历史详情 |
|---|---|---|---|
| <img src="screenshots/dark/01-home-dashboard.png" width="180"/> | <img src="screenshots/dark/08-history-calendar.png" width="180"/> | <img src="screenshots/dark/09-history-list.png" width="180"/> | <img src="screenshots/dark/10-history-detail.png" width="180"/> |

</details>

<!-- TODO: 新版 14-session 演示数据落地后，重新拍一组主屏 / 日历 / 详情截图。 -->

---

## 技术栈

| 层级 | 技术 |
|---|---|
| UI | SwiftUI（声明式，默认 MainActor 隔离） |
| 持久化 | SwiftData (`@Model`)，已为 iCloud 同步预留 |
| 通知 | `UserNotifications`（本地休息计时器提醒） |
| 图标 | SF Symbols |
| 最低系统 | iOS 26.2 |
| 工具链 | Swift 5.0 · Xcode 16+ |

---

## 快速开始

```bash
git clone https://github.com/<your-org>/SetLog.git
cd SetLog
open SetLog.xcodeproj
```

选一个 iOS 模拟器，按 **⌘ Cmd + R** 运行。14 个演示 session 会在首次启动自动种子化，无需额外操作。

清空本地数据并重新种子：
- **模拟器**：长按 app 图标 → 删除 App → 重新运行。
- **真机**：删除 app 后重新从 Xcode 安装。

> 已有 iCloud 真实数据的用户**不会**被注入演示数据。Seeder 检测到非空 session 表会自动跳过，把当前安装视为"恢复安装"。

---

## 项目结构

```
SetLog/
├── SetLog/
│   ├── SetLogApp.swift             // App 入口 — 装配 SwiftData ModelContainer + SampleDataSeeder
│   ├── ContentView.swift           // 三个 Tab：训练 · 记录 · 我的
│   ├── Item.swift                  // 所有 @Model + Export/Seed DTO + SampleDataSeeder
│   ├── CurrentWorkoutView.swift    // 训练中界面（计时器、组、休息）
│   ├── WorkoutTemplatesView.swift  // 模板浏览
│   ├── TemplateDetailView.swift    // 模板编辑 / 开始训练
│   ├── AddExerciseView.swift       // 动作库 + 自定义动作编辑
│   ├── HistoryView.swift           // 历史日历 + 列表
│   ├── HistoryDetailView.swift     // 单次详情 + 图表
│   ├── MacrocycleHomeView.swift    // 周期化首页
│   ├── MacrocycleSetupView.swift   // 新建计划向导
│   ├── MesocycleEditorView.swift   // 各阶段配置
│   ├── MesocycleEngine.swift       // 周 / 天索引解析
│   ├── ProfileView.swift           // 统计 + 导出面板
│   ├── NumericKeyboard.swift       // 自定义 4×4 键盘（UIViewRepresentable）
│   ├── AppTheme.swift              // 颜色 tokens
│   └── DemoSessions.json           // 演示数据（可替换）
└── screenshots/                    // App Store 用截图
```

---

## Roadmap 与已知限制

- **UI 文案目前只有简体中文**，迁移到 String Catalog 在规划中。
- **暂无 JSON 导入界面**。当前只能通过替换 `DemoSessions.json` 后重装来导入；个人页面里的导入入口在 roadmap。
- **动作库的本地修改尚未跨设备 iCloud 同步**，仍按本机种子处理。

欢迎 PR — 详见 issues。

---

## 许可证

基于 [MIT License](LICENSE) 发布。演示数据、截图与模板使用相同的许可。
