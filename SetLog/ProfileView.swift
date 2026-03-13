//
//  ProfileView.swift
//  SetLog
//
//  Created by toka on 2026/03/13.
//

import SwiftUI

struct ProfileView: View {
    @State private var notificationsEnabled = true
    @State private var unit: ProfileWeightUnit = .kilogram

    private let profile = UserProfile.mock
    private let regularSettings = SettingSection(
        title: "常规设置",
        rows: [
            .segmented(title: "单位切换", subtitle: "重量显示单位", leadingIcon: "globe"),
            .toggle(title: "消息通知", subtitle: "训练提醒与系统通知", leadingIcon: "bell", tint: .orange),
            .navigation(title: "深色模式", subtitle: "深色模式和沉浸", leadingIcon: "moon", trailingText: "跟随系统")
        ]
    )
    private let privacySettings = SettingSection(
        title: "账号与隐私",
        rows: [
            .navigation(title: "隐私权限", subtitle: "管理你的权限", leadingIcon: "shield"),
            .navigation(title: "账号安全", subtitle: "已绑定手机 138****8888", leadingIcon: "iphone")
        ]
    )
    private let supportSettings = SettingSection(
        title: "支持与关于",
        rows: [
            .navigation(title: "帮助中心", subtitle: nil, leadingIcon: "questionmark.circle"),
            .navigation(title: "关于 Lift Log", subtitle: "当前版本 v2.4.0", leadingIcon: "info.circle")
        ]
    )

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                profileTopBar
                profileCard
                settingsSection(regularSettings)
                settingsSection(privacySettings)
                settingsSection(supportSettings)
                logoutButton
                brandFooter
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGray6))
        .navigationBarHidden(true)
    }

    private var profileTopBar: some View {
        ZStack {
            Text("个人中心")
                .font(.system(size: 18, weight: .semibold))

            HStack {
                Spacer()
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.9), Color.red.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.system(size: 22, weight: .bold))

                    Text(profile.bio)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text(profile.level)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.47, blue: 0.22))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.96, green: 0.93, blue: 0.81))
                        .clipShape(Capsule())
                }

                Spacer()
            }

            Divider()

            HStack(spacing: 0) {
                ForEach(profile.stats) { stat in
                    ProfileStatView(stat: stat)

                    if stat.id != profile.stats.last?.id {
                        Divider()
                            .frame(height: 42)
                    }
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func settingsSection(_ section: SettingSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(section.rows) { row in
                    SettingRowView(
                        row: row,
                        unit: $unit,
                        notificationsEnabled: $notificationsEnabled
                    )

                    if row.id != section.rows.last?.id {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
        }
    }

    private var logoutButton: some View {
        Button(action: {}) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.red)
                Text("退出登录")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.red)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
        }
    }

    private var brandFooter: some View {
        VStack(spacing: 6) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            Text("LIFT LOG")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
            Text("Made with Passion for Gains")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }
}

private struct ProfileStatView: View {
    let stat: ProfileStat

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: stat.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color(.systemGray6))
                .clipShape(Circle())

            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(stat.value)
                    .font(.system(size: 20, weight: .bold))
                if let unit = stat.unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Text(stat.title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color(.systemGray6))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 15, weight: .semibold))

                if let subtitle = row.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 68)
    }
}

private struct UserProfile {
    let name: String
    let bio: String
    let level: String
    let stats: [ProfileStat]

    static let mock = UserProfile(
        name: "健身达人·阿强",
        bio: "每一块肌肉都是坚持的勋章",
        level: "LV.12",
        stats: [
            ProfileStat(icon: "calendar", value: "128", unit: "次", title: "训练天数"),
            ProfileStat(icon: "medal", value: "45.2", unit: "吨", title: "总训练量"),
            ProfileStat(icon: "link", value: "2,840", unit: "组", title: "历史组数")
        ]
    )
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
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
