import SwiftData
import SwiftUI

struct MesocycleEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meso: Mesocycle
    @Query(sort: [SortDescriptor(\WorkoutTemplate.sortOrder), SortDescriptor(\WorkoutTemplate.createdAt, order: .reverse)])
    private var allTemplates: [WorkoutTemplate]

    var body: some View {
        Form {
            Section("阶段信息") {
                TextField("阶段名", text: $meso.phaseLabel)
                Stepper("\(meso.totalWeeks) 周", value: $meso.totalWeeks, in: 1...12)
                    .onChange(of: meso.totalWeeks) { _, newValue in
                        syncWeeks(to: newValue)
                    }
                Stepper("每周 \(meso.daysPerWeek) 天", value: $meso.daysPerWeek, in: 1...7)
                    .onChange(of: meso.daysPerWeek) { _, newValue in
                        syncDays(to: newValue)
                    }
            }

            Section("强度指标") {
                HStack {
                    Text("RPE 上限")
                    Spacer()
                    Text(String(format: "%.1f", meso.defaultRpeCap)).monospacedDigit()
                    Stepper("", value: $meso.defaultRpeCap, in: 5...10, step: 0.5).labelsHidden()
                }
                HStack {
                    Text("次数区间")
                    Spacer()
                    Stepper("\(meso.targetRepsLow)", value: $meso.targetRepsLow, in: 1...30)
                        .labelsHidden().frame(width: 110)
                    Text("–")
                    Stepper("\(meso.targetRepsHigh)", value: $meso.targetRepsHigh, in: max(1, meso.targetRepsLow)...50)
                        .labelsHidden().frame(width: 110)
                }
            }

            Section("每周倍数") {
                ForEach(meso.orderedWeeks, id: \.id) { week in
                    HStack {
                        Text("第 \(week.weekIndex + 1) 周")
                        Spacer()
                        TextField(
                            "1.0",
                            value: Binding(
                                get: { week.loadMultiplier },
                                set: { newValue in
                                    week.loadMultiplier = newValue
                                    week.isDeload = newValue < 0.85
                                }
                            ),
                            format: .number.precision(.fractionLength(0...3))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        if week.isDeload {
                            Text("减载").font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.danger)
                        }
                    }
                }
            }

            Section("训练日") {
                ForEach(meso.orderedDays, id: \.id) { day in
                    HStack {
                        TextField("标签", text: Binding(
                            get: { day.label },
                            set: { day.label = $0 }
                        ))
                        Spacer()
                        Menu {
                            Button("不绑定模板") { day.templateID = nil }
                            ForEach(allTemplates) { template in
                                Button(template.title) { day.templateID = template.id }
                            }
                        } label: {
                            Text(templateLabel(for: day.templateID))
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.fg2)
                        }
                    }
                }
            }
        }
        .navigationTitle(meso.phaseLabel)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            try? modelContext.save()
        }
    }

    private func templateLabel(for id: UUID?) -> String {
        guard let id, let t = allTemplates.first(where: { $0.id == id }) else { return "选择模板 ›" }
        return t.title
    }

    private func syncWeeks(to count: Int) {
        var weeks = meso.orderedWeeks
        if count > weeks.count {
            for i in weeks.count..<count {
                let week = MesocycleWeek(weekIndex: i, loadMultiplier: 1.0, isDeload: false, meso: meso)
                modelContext.insert(week)
            }
        } else if count < weeks.count {
            for week in weeks.suffix(weeks.count - count) {
                modelContext.delete(week)
            }
        }
    }

    private func syncDays(to count: Int) {
        var days = meso.orderedDays
        if count > days.count {
            for i in days.count..<count {
                let day = MesocycleDay(dayIndex: i, label: "Day \(i + 1)", meso: meso)
                modelContext.insert(day)
            }
        } else if count < days.count {
            for day in days.suffix(days.count - count) {
                modelContext.delete(day)
            }
        }
    }
}
