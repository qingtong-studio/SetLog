//
//  ProfileView.swift
//  SetLog
//
//  Created by toka on 2026/03/13.
//

import SwiftData
import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [AppPreferences]
    @Query(sort: [SortDescriptor(\WorkoutSession.dateStarted, order: .reverse)]) private var sessions: [WorkoutSession]

    @State private var showExportShare = false
    @State private var exportFileURL: URL?
    @State private var showNoDataAlert = false
    @State private var showExportOptions = false
    @State private var exportFormat: ExportFormat = .markdown
    @State private var exportRangeSelection: ExportRangeSelection = .all
    @State private var exportCustomStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var exportCustomEnd: Date = Date()
    @State private var showExportPreview = false
    @State private var previewContent: String = ""
    @State private var previewFormat: ExportFormat = .markdown
    @State private var previewSessionCount: Int = 0
    @State private var previewIsLoading = false
    @State private var previewProgress: Double = 0
    @State private var exportShareItems: [Any] = []
    @State private var exportErrorMessage: String?
    @State private var fileExportInProgress = false
    @State private var fileExportProgress: Double = 0
    @State private var previewTask: Task<Void, Never>?
    @State private var fileExportTask: Task<Void, Never>?
    private let accountState: AccountState = .guest
    private let regularSettings = SettingSection(
        title: "常规设置",
        rows: [
            .segmented(title: "单位切换", subtitle: "重量显示单位", leadingIcon: "scalemass"),
            .toggle(title: "消息通知", subtitle: "训练提醒与系统通知", leadingIcon: "bell", tint: AppTheme.orange),
            .navigation(title: "显示模式", subtitle: "界面风格与系统外观", leadingIcon: "circle.lefthalf.filled", trailingText: "跟随系统")
        ]
    )
    private let guestAccountSection = SettingSection(
        title: "账号与同步",
        rows: [
            .navigation(title: "登录与同步", subtitle: "登录后可同步训练记录与个人资料", leadingIcon: "person.badge.key", trailingText: "未登录"),
            .navigation(title: "本机使用说明", subtitle: "未登录也可正常记录训练，数据仅保存在当前设备", leadingIcon: "internaldrive")
        ]
    )
    private let supportSettings = SettingSection(
        title: "支持与关于",
        rows: [
            .navigation(title: "帮助中心", subtitle: "常见问题与使用说明", leadingIcon: "questionmark.circle"),
            .navigation(title: "关于 SetLog", subtitle: "当前版本 \(currentAppVersionText())", leadingIcon: "info.circle")
        ]
    )

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                profileTopBar
                accountSummaryCard
                localStatsCard
                exportCard
                syncNoticeCard
                settingsSection(regularSettings)
                settingsSection(guestAccountSection)
                settingsSection(supportSettings)
                if accountState == .signedIn {
                    logoutButton
                }
                brandFooter
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(AppTheme.bgPage)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            ensurePreferences()
        }
    }

    private var appPreferences: AppPreferences? {
        preferences.first
    }

    private var unitBinding: Binding<ProfileWeightUnit> {
        Binding(
            get: { ProfileWeightUnit(weightUnit: appPreferences?.weightUnit ?? .kilogram) },
            set: { newValue in
                ensurePreferences()
                appPreferences?.weightUnit = newValue.weightUnit
                try? modelContext.save()
            }
        )
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { appPreferences?.notificationsEnabled ?? true },
            set: { newValue in
                ensurePreferences()
                appPreferences?.notificationsEnabled = newValue
                appPreferences?.updatedAt = .now
                try? modelContext.save()
            }
        )
    }

    private var completedSessions: [WorkoutSession] {
        sessions.filter(\.isCompleted)
    }

    private var totalTrainingDays: Int {
        Set(completedSessions.map { Calendar.current.startOfDay(for: $0.dateStarted) }).count
    }

    private var totalVolumeKg: Double {
        completedSessions.reduce(0) { $0 + $1.totalVolumeKg }
    }

    private var totalCompletedSets: Int {
        completedSessions.reduce(0) { $0 + $1.completedSetCount }
    }

    private var lastWorkoutText: String {
        guard let lastDate = completedSessions.first?.dateStarted else {
            return "还没有完成训练"
        }

        return lastDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var accountSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.orange, AppTheme.orangeDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: accountState.avatarSymbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 6) {
                    Text(accountState.title)
                        .font(.system(size: 22, weight: .bold))

                    Text(accountState.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.fg2)

                    Text(accountState.badgeText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.fg2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.orangeTint)
                        .clipShape(Capsule())
                }

                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Label("当前可直接使用训练、历史与设置功能", systemImage: "checkmark.circle")
                Label("登录后再补同步、跨设备恢复与账号资料", systemImage: "icloud")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.fg2)

            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("登录与同步功能开发中")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("即将上线")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.fg2)
            }
            .foregroundStyle(AppTheme.fg1)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(AppTheme.fillMedium)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    private var localStatsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("本机训练数据")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text("未登录")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.fg2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.fillMedium)
                    .clipShape(Capsule())
            }

            HStack(spacing: 0) {
                ProfileStatView(stat: ProfileStat(icon: "calendar", value: "\(totalTrainingDays)", unit: "天", title: "训练天数"))
                Divider()
                    .frame(height: 42)
                ProfileStatView(stat: ProfileStat(icon: "scalemass", value: volumeText(totalVolumeKg), unit: nil, title: "累计容量"))
                Divider()
                    .frame(height: 42)
                ProfileStatView(stat: ProfileStat(icon: "list.number", value: "\(totalCompletedSets)", unit: "组", title: "完成组数"))
            }

            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.fg2)
                Text("最近一次完成训练：\(lastWorkoutText)")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.fg2)
            }
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    private var exportCard: some View {
        Button(action: openExportOptions) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.orange)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("导出训练记录")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.fg1)
                    Text("支持 Markdown / CSV / JSON，可直接复制文本或保存分享")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.fg2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 68)
        }
        .buttonStyle(.plain)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
        .sheet(isPresented: $showExportOptions) {
            ExportOptionsSheet(
                format: $exportFormat,
                rangeSelection: $exportRangeSelection,
                customStart: $exportCustomStart,
                customEnd: $exportCustomEnd,
                matchedSessionCount: matchedExportSessions.count,
                isWorking: fileExportInProgress,
                workingProgress: fileExportProgress,
                onPreview: { performPreview() },
                onShareFile: { performExportToFile() },
                onCancel: {
                    fileExportTask?.cancel()
                    fileExportInProgress = false
                    showExportOptions = false
                }
            )
            .presentationDetents([.medium, .large])
            .interactiveDismissDisabled(fileExportInProgress)
        }
        .sheet(isPresented: $showExportPreview, onDismiss: {
            previewTask?.cancel()
            previewTask = nil
            previewIsLoading = false
            previewContent = ""
        }) {
            ExportPreviewView(
                content: previewContent,
                format: previewFormat,
                sessionCount: previewSessionCount,
                isLoading: previewIsLoading,
                progress: previewProgress
            )
        }
        .sheet(isPresented: $showExportShare) {
            ShareSheet(activityItems: exportShareItems)
        }
        .alert("暂无训练记录", isPresented: $showNoDataAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("当前筛选范围内没有可导出的训练。")
        }
        .alert("导出失败", isPresented: errorBinding, presenting: exportErrorMessage) { _ in
            Button("好的", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )
    }

    private func openExportOptions() {
        guard !completedSessions.isEmpty else {
            showNoDataAlert = true
            return
        }
        showExportOptions = true
    }

    private var resolvedExportRange: ExportDateRange {
        switch exportRangeSelection {
        case .all: return .all
        case .last7: return .last7Days
        case .last30: return .last30Days
        case .custom: return .custom(start: exportCustomStart, end: exportCustomEnd)
        }
    }

    private var matchedExportSessions: [WorkoutSession] {
        resolvedExportRange.filter(completedSessions)
    }

    @MainActor
    private func renderExport(
        format: ExportFormat,
        sessions: [WorkoutSession],
        unit: WeightUnit,
        progress: ((Double) -> Void)?
    ) async -> String {
        // Yield once so SwiftUI can render the loading state before heavy work starts.
        await Task.yield()
        switch format {
        case .markdown:
            return sessions.generateExportContent(unit: unit, progress: progress)
        case .csv:
            return sessions.generateCSV(unit: unit, progress: progress)
        case .json:
            progress?(0.5)
            let data = sessions.generateJSON(unit: unit)
            progress?(1.0)
            return String(data: data, encoding: .utf8) ?? "{}"
        }
    }

    private func performPreview() {
        let filtered = matchedExportSessions
        guard !filtered.isEmpty else {
            showExportOptions = false
            showNoDataAlert = true
            return
        }
        let unit = appPreferences?.weightUnit ?? .kilogram
        let chosenFormat = exportFormat
        previewFormat = chosenFormat
        previewSessionCount = filtered.count
        previewContent = ""
        previewProgress = 0
        previewIsLoading = true
        showExportOptions = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showExportPreview = true
            previewTask?.cancel()
            previewTask = Task { @MainActor in
                let result = await renderExport(
                    format: chosenFormat,
                    sessions: filtered,
                    unit: unit,
                    progress: { p in
                        Task { @MainActor in previewProgress = p }
                    }
                )
                if Task.isCancelled { return }
                previewContent = result
                previewProgress = 1.0
                previewIsLoading = false
            }
        }
    }

    private func performExportToFile() {
        let filtered = matchedExportSessions
        guard !filtered.isEmpty else {
            showExportOptions = false
            showNoDataAlert = true
            return
        }
        let unit = appPreferences?.weightUnit ?? .kilogram
        let chosenFormat = exportFormat

        let stamp = DateFormatter.exportFilenameStamp.string(from: Date())
        let fileName = "SetLog_训练记录_\(stamp).\(chosenFormat.fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        fileExportProgress = 0
        fileExportInProgress = true
        fileExportTask?.cancel()
        fileExportTask = Task { @MainActor in
            // Let the progress UI render before crunching the data.
            await Task.yield()
            do {
                switch chosenFormat {
                case .markdown:
                    let content = filtered.generateExportContent(unit: unit) { p in
                        Task { @MainActor in fileExportProgress = p }
                    }
                    if Task.isCancelled { return }
                    try content.write(to: url, atomically: true, encoding: .utf8)
                case .csv:
                    let content = filtered.generateCSV(unit: unit) { p in
                        Task { @MainActor in fileExportProgress = p }
                    }
                    if Task.isCancelled { return }
                    try content.write(to: url, atomically: true, encoding: .utf8)
                case .json:
                    fileExportProgress = 0.5
                    let data = filtered.generateJSON(unit: unit)
                    if Task.isCancelled { return }
                    try data.write(to: url, options: .atomic)
                }
            } catch {
                fileExportInProgress = false
                exportErrorMessage = "无法写入文件：\(error.localizedDescription)"
                return
            }

            fileExportProgress = 1.0
            fileExportInProgress = false
            exportFileURL = url
            exportShareItems = [url]
            showExportOptions = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showExportShare = true
            }
        }
    }

    private var syncNoticeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("iCloud 同步", systemImage: "icloud")
                .font(.system(size: 14, weight: .bold))

            Text("训练记录、模板与设置会自动同步到你的 iCloud 私人空间。同一 Apple ID 登录的设备之间自动互通，App 卸载重装后数据也会自动恢复。")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.fg2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    private var profileTopBar: some View {
        Text("个人中心")
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func settingsSection(_ section: SettingSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.fg2)

            VStack(spacing: 0) {
                ForEach(section.rows) { row in
                    SettingRowView(
                        row: row,
                        unit: unitBinding,
                        notificationsEnabled: notificationsBinding
                    )

                    if row.id != section.rows.last?.id {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
            .background(AppTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.fillMedium, lineWidth: 1)
            )
        }
    }

    private var logoutButton: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .foregroundStyle(AppTheme.danger)
            Text("退出登录")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.danger)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    private var brandFooter: some View {
        VStack(spacing: 6) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.fg2)
            Text("SETLOG")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.fg2)
            Text("Guest mode supported. Sync comes later.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    private func volumeText(_ value: Double) -> String {
        value.formattedVolume(unit: appPreferences?.weightUnit ?? .kilogram)
    }

    private func ensurePreferences() {
        guard preferences.isEmpty else {
            return
        }

        modelContext.insert(AppPreferences())
        try? modelContext.save()
    }
}

private struct ProfileStatView: View {
    let stat: ProfileStat

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: stat.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.fg2)
                .frame(width: 28, height: 28)
                .background(AppTheme.fillMedium)
                .clipShape(Circle())

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(stat.value)
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let unit = stat.unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.fg2)
                }
            }

            Text(stat.title)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.fg2)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SettingRowView: View {
    let row: SettingRow
    @Binding var unit: ProfileWeightUnit
    @Binding var notificationsEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.leadingIcon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.fg2)
                .frame(width: 30, height: 30)
                .background(AppTheme.fillMedium)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 15, weight: .semibold))

                if let subtitle = row.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.fg2)
                }
            }

            Spacer()

            switch row.kind {
            case .segmented:
                Picker("", selection: $unit) {
                    ForEach(ProfileWeightUnit.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 92)
            case .toggle(let tint):
                Toggle("", isOn: $notificationsEnabled)
                    .labelsHidden()
                    .tint(tint)
            case .navigation(let trailingText):
                HStack(spacing: 8) {
                    if let trailingText {
                        Text(trailingText)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.fg2)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 68)
    }
}

private struct ProfileStat: Identifiable {
    let id = UUID()
    let icon: String
    let value: String
    let unit: String?
    let title: String
}

private struct SettingSection {
    let title: String
    let rows: [SettingRow]
}

private struct SettingRow: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let leadingIcon: String
    let kind: Kind

    enum Kind {
        case segmented
        case toggle(tint: Color)
        case navigation(trailingText: String?)
    }

    static func segmented(title: String, subtitle: String?, leadingIcon: String) -> SettingRow {
        SettingRow(title: title, subtitle: subtitle, leadingIcon: leadingIcon, kind: .segmented)
    }

    static func toggle(title: String, subtitle: String?, leadingIcon: String, tint: Color) -> SettingRow {
        SettingRow(title: title, subtitle: subtitle, leadingIcon: leadingIcon, kind: .toggle(tint: tint))
    }

    static func navigation(title: String, subtitle: String?, leadingIcon: String, trailingText: String? = nil) -> SettingRow {
        SettingRow(title: title, subtitle: subtitle, leadingIcon: leadingIcon, kind: .navigation(trailingText: trailingText))
    }
}

private enum ProfileWeightUnit: String, CaseIterable {
    case kilogram = "KG"
    case pound = "LB"

    init(weightUnit: WeightUnit) {
        self = weightUnit == .kilogram ? .kilogram : .pound
    }

    var weightUnit: WeightUnit {
        self == .kilogram ? .kilogram : .pound
    }
}

private enum AccountState {
    case guest
    case signedIn

    var title: String {
        switch self {
        case .guest:
            return "未登录"
        case .signedIn:
            return "已登录"
        }
    }

    var subtitle: String {
        switch self {
        case .guest:
            return "当前以本机模式使用。训练记录和设置可直接使用，后续可登录同步。"
        case .signedIn:
            return "账号数据已同步到云端。"
        }
    }

    var badgeText: String {
        switch self {
        case .guest:
            return "本机使用中"
        case .signedIn:
            return "已开启同步"
        }
    }

    var avatarSymbol: String {
        switch self {
        case .guest:
            return "person.crop.circle"
        case .signedIn:
            return "person.crop.circle.badge.checkmark"
        }
    }
}

private func currentAppVersionText() -> String {
    let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    return "v\(shortVersion) (\(buildNumber))"
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum ExportRangeSelection: String, CaseIterable, Identifiable {
    case all
    case last7
    case last30
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "全部"
        case .last7: return "近 7 天"
        case .last30: return "近 30 天"
        case .custom: return "自定义"
        }
    }
}

private struct ExportOptionsSheet: View {
    @Binding var format: ExportFormat
    @Binding var rangeSelection: ExportRangeSelection
    @Binding var customStart: Date
    @Binding var customEnd: Date
    let matchedSessionCount: Int
    let isWorking: Bool
    let workingProgress: Double
    let onPreview: () -> Void
    let onShareFile: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("导出格式") {
                    Picker("格式", selection: $format) {
                        ForEach(ExportFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(formatDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Section("时间范围") {
                    Picker("范围", selection: $rangeSelection) {
                        ForEach(ExportRangeSelection.allCases) { sel in
                            Text(sel.displayName).tag(sel)
                        }
                    }
                    .pickerStyle(.segmented)

                    if rangeSelection == .custom {
                        DatePicker("开始", selection: $customStart, displayedComponents: .date)
                        DatePicker("结束", selection: $customEnd, in: customStart..., displayedComponents: .date)
                    }

                    HStack {
                        Text("匹配训练数")
                        Spacer()
                        Text("\(matchedSessionCount)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(action: onPreview) {
                        Label("预览 & 复制文本", systemImage: "doc.text.magnifyingglass")
                    }
                    .disabled(matchedSessionCount == 0 || isWorking)

                    Button(action: onShareFile) {
                        if isWorking {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("正在生成… \(Int(workingProgress * 100))%")
                                    .fontWeight(.semibold)
                            }
                        } else {
                            Label("保存 / 分享文件", systemImage: "square.and.arrow.up")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(matchedSessionCount == 0 || isWorking)

                    if isWorking {
                        ProgressView(value: workingProgress)
                    }
                } footer: {
                    Text("「预览 & 复制」无需写入文件，可直接复制全文到 Claude / 微信等。")
                        .font(.system(size: 11))
                }
            }
            .navigationTitle("导出训练记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isWorking ? "停止" : "取消", action: onCancel)
                }
            }
        }
    }

    private var formatDescription: String {
        switch format {
        case .markdown: return "Markdown：可读性强，适合粘贴给 Claude 等 AI 分析。"
        case .csv: return "CSV：可在 Excel / Numbers 中打开做透视分析。"
        case .json: return "JSON：结构化数据，便于程序处理。"
        }
    }
}

private struct ExportPreviewView: View {
    let content: String
    let format: ExportFormat
    let sessionCount: Int
    let isLoading: Bool
    let progress: Double

    @Environment(\.dismiss) private var dismiss
    @State private var copyToastVisible = false
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView(value: progress) {
                            Text("正在生成 \(format.displayName) 内容…")
                                .font(.system(size: 14, weight: .semibold))
                        } currentValueLabel: {
                            Text("\(Int(progress * 100))% · \(sessionCount) 次训练")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .progressViewStyle(.linear)
                        .padding(.horizontal, 28)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.bgPage)
                } else {
                    previewScroll
                }
            }
            .overlay(alignment: .bottom) {
                if copyToastVisible {
                    Text("已复制到剪贴板")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.bottom, 28)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(isLoading)
                    Button {
                        copyAll()
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .disabled(isLoading)
                }
            }
            .sheet(isPresented: $showShare) {
                ShareSheet(activityItems: [content])
            }
        }
    }

    private var previewScroll: some View {
        ScrollView {
            Text(content)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(AppTheme.bgPage)
    }

    private var navTitle: String {
        if isLoading {
            return "\(format.displayName) · \(sessionCount) 次"
        }
        let bytes = content.utf8.count
        let sizeText: String
        if bytes < 1024 {
            sizeText = "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            sizeText = String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            sizeText = String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
        return "\(format.displayName) · \(sessionCount) 次 · \(sizeText)"
    }

    private func copyAll() {
        UIPasteboard.general.string = content
        withAnimation(.easeInOut(duration: 0.2)) {
            copyToastVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 0.25)) {
                copyToastVisible = false
            }
        }
    }
}

extension DateFormatter {
    static let exportFilenameStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd_HHmm"
        return f
    }()
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .modelContainer(PreviewModelContainer.shared)
}
