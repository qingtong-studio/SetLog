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
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarHidden(true)
    }

    private var topBar: some View {
        Text("训练模板")
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private var discoverHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("发现模板")
                .font(.system(size: 34, weight: .black))
            Text("根据你的目标选择合适的计划")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
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
                            .foregroundStyle(selectedCategory == category ? .white : .secondary)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(selectedCategory == category ? Color.black : Color(.systemGray5).opacity(0.4))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var templateList: some View {
        VStack(spacing: 14) {
            if filteredTemplates.isEmpty {
                noTemplateState
            } else {
                ForEach(filteredTemplates) { template in
                    WorkoutTemplateCard(template: template, onApply: onApplyTemplate)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            detailTemplate = template
                        }
                }
            }
        }
        .navigationDestination(item: $detailTemplate) { template in
            TemplateDetailView(template: template, onApply: onApplyTemplate)
        }
    }

    private var noTemplateState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
            Text("暂无模板")
                .font(.system(size: 15, weight: .semibold))
            Text("先在训练中沉淀几次动作组合，再整理成模板。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    private var createTemplateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "play")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color(.systemGray3))

            Text("模板创建入口")
                .font(.system(size: 18, weight: .bold))

            Text("下一步会开放自定义新模板")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                .foregroundStyle(Color(.systemGray3))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct WorkoutTemplateCard: View {
    let template: WorkoutTemplate
    let onApply: (WorkoutTemplate) -> Void

    private var orderedExercises: [TemplateExercise] {
        template.exercises.sorted { $0.order < $1.order }
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
                    .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Spacer()

                Text(template.category)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Color(.systemGray6))
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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        WorkoutTemplatesView()
            .modelContainer(PreviewModelContainer.shared)
    }
}

private enum PreviewModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            AppPreferences.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            WorkoutSet.self,
            ExerciseCatalogItem.self,
            WorkoutTemplate.self,
            TemplateExercise.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            try SampleDataSeeder.seedIfNeeded(in: container.mainContext)
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()
}
