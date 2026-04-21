//
//  ProfileView.swift
//  SetLog
//
//  Created by toka on 2026/03/13.
//

import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [AppPreferences]
    @Query(sort: [SortDescriptor(\WorkoutSession.dateStarted, order: .reverse)]) private var sessions: [WorkoutSession]

    @State private var showExportShare = false
    @State private var exportFileURL: URL?
    @State private var showNoDataAlert = false
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
        .navigationBarHidden(true)
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
        Button(action: exportTrainingRecords) {
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
                    Text("导出为 Markdown 格式，适合 Claude 等 AI 分析")
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
        .sheet(isPresented: $showExportShare) {
            if let url = exportFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("暂无训练记录", isPresented: $showNoDataAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("完成至少一次训练后即可导出记录。")
        }
    }

    private func exportTrainingRecords() {
        let completed = completedSessions
        guard !completed.isEmpty else {
            showNoDataAlert = true
            return
        }
        let unit = appPreferences?.weightUnit ?? .kilogram
        let content = completed.generateExportContent(unit: unit)
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("SetLog_训练记录.md")
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        exportFileURL = fileURL
        showExportShare = true
    }

    private var syncNoticeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("未登录模式说明", systemImage: "lock.open")
                .font(.system(size: 14, weight: .bold))

            Text("当前训练记录、历史记录和设置均可正常使用，但数据只保存在这台设备上。后续接入账号系统后，可在这里完成登录并开启同步。")
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

#Preview {
    NavigationStack {
        ProfileView()
    }
    .modelContainer(PreviewModelContainer.shared)
}
