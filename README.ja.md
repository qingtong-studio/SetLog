<div align="center">

<img src="logo.svg" alt="SetLog" width="120" />

# SetLog

**本気のリフター向け SwiftUI + SwiftData ワークアウトロガー。**
セット単位の記録、RPE、レストタイマー、ピリオダイゼーション、テンプレート — すべてオフラインで。

[简体中文](README.zh-CN.md) · **日本語** · [English](README.md)

[![Platform](https://img.shields.io/badge/platform-iOS%2026.2%2B-blue.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-%E2%9C%93-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![SwiftData](https://img.shields.io/badge/SwiftData-%E2%9C%93-blue.svg)](https://developer.apple.com/documentation/swiftdata)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

</div>

---

## 概要

**SetLog** はストレングス・トレーニングの実際のワークフロー — ウォームアップのランプアップ、RPE で評価する本セット、意図的なインターバル、構造化された週分割 — を中心に設計された iOS ワークアウトロガーです。SwiftData によるオフラインファースト、カスタム数字キーパッドでデータ入力に最適化、5 日分割プログラムが標準搭載されています。

<!-- TODO: ヒーロー画像を差し替え。`screenshots/light/01-home-dashboard.png` がそのまま使えます。 -->
<p align="center">
  <img src="screenshots/light/01-home-dashboard.png" alt="ホーム画面" width="280" />
</p>

---

## 機能

### ワークアウト記録
- **リアルタイム・セッションタイマー**：一時停止 / 再開可能。総経過時間とセット単位の完了タイムスタンプを記録。
- **セット単位の記録**：目標レップ vs 実際レップ、重量（kg / lb）、RPE 6–10、レスト秒数、完了時刻。
- **セット種別**：`warmup`（ウォームアップ）と `working`（本セット）を別スタイルで表示。ランプアップが容量指標を希釈しません。
- **セッションごとのメモ**（例：_"スクワットの感覚が良い、次回は 3 セット目を 102.5kg に上げる"_）。
- **減量モード（Deload）**：このセッションは減量と明示でき、推奨重量の更新やテンプレート逆書き戻しをスキップ。軽い日でデフォルトが汚れません。

### ピリオダイゼーション（マクロサイクル / メゾサイクル）
- ひとつの **マクロサイクル** に複数の **メゾサイクル**（ハイパートロフィー / ストレングス / etc.）をスタック。
- 週ごとの負荷倍率、減量週フラグ、RPE 上限、目標レップ範囲を個別設定。
- セットアップウィザードで標準的な 4–6 週メゾサイクル構造を雛形生成。

### テンプレート & デイリープラン
- **v4 5 日分割** をデフォルト搭載：周一·腿（月・脚）、周二·推（火・押し・ストレングス）、周三·拉（水・引き）、周四·手臂+肩（木・腕+肩）、周五·平衡调和（金・バランス）。
- **DailyPlan**：その日だけテンプレートを上書きでき、テンプレート本体は触らなくてOK。
- 完了済みセッションから "推奨重量" を自動学習し、次回に継承。

### エクササイズカタログ
- **60+ 種のプリセットエクササイズ**、6 カテゴリ：胸 / 背中 / 脚 / 肩 / 腕 / コア。
- SF Symbols アイコンとカラーティントでカスタムエクササイズを追加可能。
- 各エクササイズで設定可能：
  - **重量モード**：`standard`（バーベル/マシン合計）または `singleHand`（ダンベル片側；ボリューム計算では自動で ×2）。
  - **自重を含める**：加重懸垂やディップスで自身の体重を容量計算に組み込み可能。

### カスタム数字キーパッド
4×4 のキーパッドがシステムキーボードを置き換え、重量・レップ入力を加速。ハプティクスとアクションキー 4 個付き：

| キー | 動作 |
|---|---|
| 閉じる | キーパッドを収納 |
| コピー → | 現在の値を右隣のセットへコピー |
| 埋める ↓ | 現在の値を下方の空セル全てに流し込む |
| 確定 | コミットしてフォーカスを次へ |

### 履歴 & 分析
- **カレンダー** ビュー、**リスト** ビュー、**セッション詳細** ビューを切替可能。
- 集計指標：累計トレーニング日数、累計ボリューム（KG/LB 自動換算）、累計完了セット数、最終トレーニング日。
- セッション単位のエクササイズ内訳、セット数、RPE 分布、ボリュームチャート。

### エクスポート（Markdown / CSV / JSON）
- 3 フォーマット × 4 期間（全期間 / 直近 7 日 / 直近 30 日 / カスタム）。
- **JSON** はラウンドトリップ可能 — デモデータも同じスキーマを使用。
- **CSV** は UTF‑8 BOM 付きなので Excel が自動認識。
- **Markdown** は メモ / Bear / Obsidian / GitHub にそのまま共有可能。

### レストタイマー & 通知
- セット完了で自動スタート、一時停止可、セット毎にカスタム時間。
- 終了時にローカル通知（`rest-timer-complete`）を発火。インターバル中はスマホを置けます。

### UI の細部
- 完全な **ダークモード** 対応（オレンジ系アクセントが両テーマを貫通）。
- エクササイズアイコンに **SF Symbols** を使用。
- セッション中にドラッグでエクササイズ並び替え可。
- iPad 対応（Universal device family）。

---

## デモデータ

初回起動時に `SetLog/DemoSessions.json` から **実トレーニング 14 セッション** を自動シード（2026‑04‑24 〜 2026‑05‑14、v4 5 日分割の完全な 1 メゾサイクル）：

| 指標 | 値 |
|---|---|
| セッション数 | 14 |
| 合計セット数 | 260 |
| 合計ボリューム | **89,017 kg** |
| 期間 | 3 週間 |
| カバー部位 | 胸 · 背中 · 脚 · 肩 · 腕 · コア |
| 触れる機能 | ウォームアップランプ、RPE 6–10、カスタムレスト、加重懸垂 & ディップス、片側ダンベルモード、進行中セッション |

最後のセッション（2026‑05‑14、_v4‑周四·手臂+肩_）はあえて **未完了** で残しています — トレーニングタブを開けばそのまま続行可能。

> シードデータは普通の JSON です。`SetLog/DemoSessions.json` を自分のエクスポートで置き換えれば、次のクリーンインストールでそのデータが使われます。

---

## スクリーンショット

<details open>
<summary><strong>ライトモード</strong></summary>

| ホーム | テンプレート | テンプレート詳細 | エクササイズ追加 |
|---|---|---|---|
| <img src="screenshots/light/01-home-dashboard.png" width="180"/> | <img src="screenshots/light/02-templates.png" width="180"/> | <img src="screenshots/light/03-template-detail.png" width="180"/> | <img src="screenshots/light/05-add-exercise.png" width="180"/> |

| 現在のワークアウト | 進行中 | サマリー | プロフィール |
|---|---|---|---|
| <img src="screenshots/light/04-current-workout.png" width="180"/> | <img src="screenshots/light/04-current-workout-running.png" width="180"/> | <img src="screenshots/light/04d-workout-summary.png" width="180"/> | <img src="screenshots/light/13-profile.png" width="180"/> |

| 履歴カレンダー | 履歴リスト | 履歴詳細 |
|---|---|---|
| <img src="screenshots/light/08-history-calendar.png" width="180"/> | <img src="screenshots/light/09-history-list.png" width="180"/> | <img src="screenshots/light/10-history-detail.png" width="180"/> |

</details>

<details>
<summary><strong>ダークモード</strong></summary>

| ホーム | 履歴カレンダー | 履歴リスト | 履歴詳細 |
|---|---|---|---|
| <img src="screenshots/dark/01-home-dashboard.png" width="180"/> | <img src="screenshots/dark/08-history-calendar.png" width="180"/> | <img src="screenshots/dark/09-history-list.png" width="180"/> | <img src="screenshots/dark/10-history-detail.png" width="180"/> |

</details>

<!-- TODO: 新しい 14-session シードが反映された状態でホーム/カレンダー/詳細を撮り直し。 -->

---

## 技術スタック

| レイヤー | 技術 |
|---|---|
| UI | SwiftUI（宣言的、デフォルトで MainActor 隔離） |
| 永続化 | SwiftData (`@Model`)、iCloud 同期対応済み |
| 通知 | `UserNotifications`（ローカル・レストタイマー通知） |
| アイコン | SF Symbols |
| 最小 OS | iOS 26.2 |
| ツールチェーン | Swift 5.0 · Xcode 16+ |

---

## 始め方

```bash
git clone https://github.com/<your-org>/SetLog.git
cd SetLog
open SetLog.xcodeproj
```

iOS シミュレータを選んで **⌘ Cmd + R**。14 セッションのデモデータは初回起動時に自動シードされます — 追加手順は不要です。

ローカルストアをリセットして再シード：
- **シミュレータ**：アプリアイコンを長押し → アプリ削除 → 再実行。
- **実機**：アプリを削除 → Xcode から再インストール。

> iCloud 経由で既に実データを同期している既存ユーザーには、デモデータは注入されません。Seeder は非空のセッションテーブルを検出すると、当該インストールを "復元インストール" として扱います。

---

## プロジェクト構成

```
SetLog/
├── SetLog/
│   ├── SetLogApp.swift             // App エントリ — SwiftData ModelContainer + SampleDataSeeder を組み立て
│   ├── ContentView.swift           // タブルート：訓練 · 記録 · 設定
│   ├── Item.swift                  // 全 @Model 型 + Export/Seed DTO + SampleDataSeeder
│   ├── CurrentWorkoutView.swift    // ライブワークアウト UI（タイマー、セット、レスト）
│   ├── WorkoutTemplatesView.swift  // テンプレート一覧
│   ├── TemplateDetailView.swift    // テンプレート編集 / 開始
│   ├── AddExerciseView.swift       // カタログブラウザ + カスタムエクササイズ編集
│   ├── HistoryView.swift           // カレンダー + リスト
│   ├── HistoryDetailView.swift     // セッション詳細 + チャート
│   ├── MacrocycleHomeView.swift    // ピリオダイゼーション ホーム
│   ├── MacrocycleSetupView.swift   // 新規プログラム ウィザード
│   ├── MesocycleEditorView.swift   // フェーズ別設定
│   ├── MesocycleEngine.swift       // 週/日インデックス解決
│   ├── ProfileView.swift           // 統計 + エクスポートシート
│   ├── NumericKeyboard.swift       // カスタム 4×4 キーパッド（UIViewRepresentable）
│   ├── AppTheme.swift              // カラー トークン
│   └── DemoSessions.json           // シードデータ（差し替え可）
└── screenshots/                    // App Store 用キャプチャ
```

---

## ロードマップ & 既知の制限

- **UI 文言は現在簡体字中国語のみ**。String Catalog への移行はロードマップに記載。
- **JSON インポート UI は未実装**。現状は `DemoSessions.json` を置き換えて再インストールするのみ。プロフィール画面のインポーターを予定。
- **エクササイズカタログのローカル編集は iCloud 同期されません** — デバイス固有のシードとして扱われます。

PR 歓迎 — オープン issue を参照ください。

---

## ライセンス

[MIT License](LICENSE) の下でリリース。デモデータ、スクリーンショット、テンプレートも同じライセンスで提供されます。
