//
//  WorkoutTemplatesView.swift
//  SetLog
//
//  Created by toka on 2026/03/13.
//

import SwiftData
import SwiftUI

struct WorkoutTemplatesView: View {
    @State private var selectedCategory = "全部"
    @State private var detailTemplate: WorkoutTemplate?
    @Query(sort: [SortDescriptor(\WorkoutTemplate.createdAt, order: .reverse)]) private var templates: [WorkoutTemplate]

    let onApplyTemplate: (WorkoutTemplate) -> Void

    init(onApplyTemplate: @escaping (WorkoutTemplate) -> Void = { _ in }) {
        self.onApplyTemplate = onApplyTemplate
    }

    private var categories: [String] {
        let dynamicCategories = Set(templates.map(\.category)).sorted()
        return ["全部"] + dynamicCategories
    }

    private var filteredTemplates: [WorkoutTemplate] {
        templates.filter { template in
            selectedCategory == "全部" || template.category == selectedCategory
        }
    }

    private struct TemplateGroup: Identifiable {
        let id: String
        let name: String
        let templates: [WorkoutTemplate]
    }

    private static let ungroupedLabel = "未分组"

    private var groupedTemplates: [TemplateGroup] {
        let grouped = Dictionary(grouping: filteredTemplates) { template -> String in
            let trimmed = template.groupName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? Self.ungroupedLabel : trimmed
        }

        return grouped.map { name, items in
            let sorted = items.sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.createdAt < rhs.createdAt
            }
            return TemplateGroup(id: name, name: name, templates: sorted)
        }
        .sorted { lhs, rhs in
            groupPriority(lhs.name) < groupPriority(rhs.name)
        }
    }

    private func groupPriority(_ name: String) -> Int {
        if name == Self.ungroupedLabel { return Int.max }
        if let index = SampleDataSeeder.groupDisplayOrder.firstIndex(of: name) {
            return index
        }
        return SampleDataSeeder.groupDisplayOrder.count
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    discoverHeader
                    categoryTabs
                    templateList
                    createTemplateCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .background(AppTheme.bgPage)
        .navigationBarHidden(true)
    }

    private var topBar: some View {
        Text("训练模板")
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppTheme.bgCard)
    }

    private var discoverHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("发现模板")
                .font(.system(size: 34, weight: .black))
            Text("根据你的目标选择合适的计划")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.fg2)
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        Text(category)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(selectedCategory == category ? Color.white : AppTheme.fg2)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(selectedCategory == category ? AppTheme.ctaFill : AppTheme.fillMedium.opacity(0.4))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var templateList: some View {
        VStack(alignment: .leading, spacing: 22) {
            if filteredTemplates.isEmpty {
                noTemplateState
            } else {
                ForEach(groupedTemplates) { group in
                    templateGroupSection(group)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationDestination(item: $detailTemplate) { template in
            TemplateDetailView(template: template, onApply: onApplyTemplate)
        }
    }

    private func templateGroupSection(_ group: TemplateGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(group.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.fg1)

                Text("\(group.templates.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.fg2)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(AppTheme.fillMedium)
                    .clipShape(Capsule())

                Spacer()
            }

            VStack(spacing: 14) {
                ForEach(group.templates) { template in
                    WorkoutTemplateCard(template: template, onApply: onApplyTemplate)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            detailTemplate = template
                        }
                }
            }
        }
    }

    private var noTemplateState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(AppTheme.fg2)
            Text("暂无模板")
                .font(.system(size: 15, weight: .semibold))
            Text("先在训练中沉淀几次动作组合，再整理成模板。")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.fg2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    private var createTemplateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "play")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(AppTheme.fg3)

            Text("模板创建入口")
                .font(.system(size: 18, weight: .bold))

            Text("下一步会开放自定义新模板")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.fg2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(AppTheme.bgCard)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                .foregroundStyle(AppTheme.fg3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct WorkoutTemplateCard: View {
    let template: WorkoutTemplate
    let onApply: (WorkoutTemplate) -> Void

    private var orderedExercises: [TemplateExercise] {
        (template.exercises ?? []).sorted { $0.order < $1.order }
    }

    private var exerciseSymbols: [String] {
        let symbols = orderedExercises.prefix(4).map(\.symbolName)
        return symbols.isEmpty ? ["figure.strengthtraining.traditional"] : symbols
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.title)
                        .font(.system(size: 24, weight: .bold))

                    HStack(spacing: 10) {
                        Label("\(template.estimatedDuration) 分钟", systemImage: "clock")
                        Label(template.level, systemImage: "flame")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.fg2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 10) {
                ForEach(exerciseSymbols, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.fg2)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.fillMedium)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Spacer()

                Text(template.category)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.fg2)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(AppTheme.fillMedium)
                    .clipShape(Capsule())
            }

            Button(action: {
                onApply(template)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play")
                        .font(.system(size: 12, weight: .bold))
                    Text("立即应用")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(AppTheme.ctaFill)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
}

#Preview {
    NavigationStack {
        WorkoutTemplatesView()
            .modelContainer(PreviewModelContainer.shared)
    }
}
