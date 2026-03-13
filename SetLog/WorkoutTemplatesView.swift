//
//  WorkoutTemplatesView.swift
//  SetLog
//
//  Created by toka on 2026/03/13.
//

import SwiftUI

struct WorkoutTemplatesView: View {
    @State private var selectedCategory = "全部"

    private let categories = ["全部", "力量", "减脂", "塑形", "居家"]
    private let templates = WorkoutTemplateCardData.mockData
    let onApplyTemplate: () -> Void

    init(onApplyTemplate: @escaping () -> Void = {}) {
        self.onApplyTemplate = onApplyTemplate
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
        .background(Color(.systemGray6))
        .navigationBarHidden(true)
    }

    private var topBar: some View {
        ZStack {
            Text("训练模板")
                .font(.system(size: 18, weight: .semibold))

            HStack {
                Spacer()
                Button(action: {}) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(.white)
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
            ForEach(templates) { template in
                WorkoutTemplateCard(template: template, onApply: onApplyTemplate)
            }
        }
    }

    private var createTemplateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "play")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color(.systemGray3))

            Text("自定义新模板")
                .font(.system(size: 18, weight: .bold))

            Text("创建属于你的专属训练序列")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                .foregroundStyle(Color(.systemGray3))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct WorkoutTemplateCard: View {
    let template: WorkoutTemplateCardData
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.title)
                        .font(.system(size: 24, weight: .bold))

                    HStack(spacing: 10) {
                        Label(template.duration, systemImage: "clock")
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
                ForEach(template.exerciseSymbols, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Spacer()

                Text(template.tag)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
            }

            Button(action: onApply) {
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
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

private struct WorkoutTemplateCardData: Identifiable {
    let id = UUID()
    let title: String
    let duration: String
    let level: String
    let exerciseSymbols: [String]
    let tag: String

    static let mockData: [WorkoutTemplateCardData] = [
        WorkoutTemplateCardData(
            title: "经典胸肌与肱三头肌训练",
            duration: "65 分钟",
            level: "进阶",
            exerciseSymbols: ["figure.strengthtraining.traditional", "bolt.heart", "flame", "figure.cooldown"],
            tag: "胸部"
        ),
        WorkoutTemplateCardData(
            title: "硬核腿部轰炸 (Leg Day)",
            duration: "75 分钟",
            level: "专业",
            exerciseSymbols: ["figure.strengthtraining.traditional", "figure.run", "figure.walk"],
            tag: "股四头肌"
        ),
        WorkoutTemplateCardData(
            title: "居家弹力带塑形",
            duration: "30 分钟",
            level: "入门",
            exerciseSymbols: ["figure.mind.and.body", "figure.flexibility"],
            tag: "全身"
        )
    ]
}

#Preview {
    NavigationStack {
        WorkoutTemplatesView()
    }
}
