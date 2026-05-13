import SwiftData
import SwiftUI

enum CycleSetupMode: String, Identifiable {
    case macro
    case singleMeso

    var id: String { rawValue }

    var navTitle: String {
        switch self {
        case .macro:      return "新建大周期"
        case .singleMeso: return "新建小周期"
        }
    }

    var defaultTitle: String {
        switch self {
        case .macro:      return "新的大周期"
        case .singleMeso: return "新的小周期"
        }
    }
}

struct MacrocycleSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\WorkoutTemplate.sortOrder), SortDescriptor(\WorkoutTemplate.createdAt, order: .reverse)])
    private var allTemplates: [WorkoutTemplate]
    @Query private var existingMacros: [MacrocycleProgram]

    let mode: CycleSetupMode
    @State private var title: String
    @State private var startDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var presetKind: MacroPresetKind
    @State private var daysPerWeek: Int = 4
    @State private var draftPhases: [DraftPhase] = []
    @State private var phasesVary: Bool = false
    @State private var sharedDays: [DraftDay] = []

    init(mode: CycleSetupMode = .macro) {
        self.mode = mode
        _title = State(initialValue: mode.defaultTitle)
        _presetKind = State(initialValue: mode == .macro ? .classic16 : .empty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("名称", text: $title)
                    DatePicker("起始日期", selection: $startDate, displayedComponents: .date)
                    if mode == .macro {
                        Picker("预设", selection: $presetKind) {
                            ForEach(MacroPresetKind.allCases) { kind in
                                Text(kind.label).tag(kind)
                            }
                        }
                        .onChange(of: presetKind) { _, newValue in
                            applyPreset(newValue)
                        }
                    }
                    Stepper("每周训练 \(daysPerWeek) 天", value: $daysPerWeek, in: 1...7)
                        .onChange(of: daysPerWeek) { _, newValue in
                            syncDays(to: newValue)
                        }

                    if mode == .macro {
                        Toggle("各阶段动作变化", isOn: $phasesVary)
                            .tint(AppTheme.orange)
                    }
                }

                if showSharedDaysSection {
                    Section("训练日（所有阶段共用）") {
                        ForEach(sharedDays.indices, id: \.self) { idx in
                            HStack {
                                TextField("训练日标签", text: Binding(
                                    get: { sharedDays[idx].label },
                                    set: { sharedDays[idx].label = $0 }
                                ))
                                Spacer()
                                Menu {
                                    Button("不绑定模板") {
                                        sharedDays[idx].templateID = nil
                                    }
                                    ForEach(allTemplates) { template in
                                        Button(template.title) {
                                            sharedDays[idx].templateID = template.id
                                        }
                                    }
                                } label: {
                                    Text(templateLabel(for: sharedDays[idx].templateID))
                                        .font(.system(size: 13))
                                        .foregroundStyle(AppTheme.fg2)
                                }
                            }
                        }
                    }
                }

                ForEach($draftPhases) { $phase in
                    Section(phase.label.isEmpty ? "小周期" : phase.label) {
                        TextField("阶段名", text: $phase.label)
                        Stepper("\(phase.totalWeeks) 周", value: $phase.totalWeeks, in: 1...12)
                            .onChange(of: phase.totalWeeks) { _, newValue in
                                phase.weekMultipliers = adjustMultipliers(phase.weekMultipliers, to: newValue)
                            }

                        HStack {
                            Text("RPE 上限").foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f", phase.rpeCap))
                                .monospacedDigit()
                            Stepper("", value: $phase.rpeCap, in: 5...10, step: 0.5)
                                .labelsHidden()
                        }

                        HStack {
                            Text("次数区间").foregroundStyle(.secondary)
                            Spacer()
                            Stepper("\(phase.repsLow)", value: $phase.repsLow, in: 1...30)
                                .labelsHidden()
                                .frame(width: 110)
                            Text("–")
                            Stepper("\(phase.repsHigh)", value: $phase.repsHigh, in: max(1, phase.repsLow)...50)
                                .labelsHidden()
                                .frame(width: 110)
                        }

                        DisclosureGroup("每周倍数") {
                            ForEach(phase.weekMultipliers.indices, id: \.self) { idx in
                                HStack {
                                    Text("第 \(idx + 1) 周")
                                    Spacer()
                                    TextField(
                                        "1.0",
                                        value: Binding(
                                            get: { phase.weekMultipliers[idx] },
                                            set: { phase.weekMultipliers[idx] = $0 }
                                        ),
                                        format: .number.precision(.fractionLength(0...3))
                                    )
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                }
                            }
                        }

                        if !showSharedDaysSection {
                            ForEach(phase.days.indices, id: \.self) { idx in
                                HStack {
                                    TextField("训练日标签", text: Binding(
                                        get: { phase.days[idx].label },
                                        set: { phase.days[idx].label = $0 }
                                    ))
                                    Spacer()
                                    Menu {
                                        Button("不绑定模板") {
                                            phase.days[idx].templateID = nil
                                        }
                                        ForEach(allTemplates) { template in
                                            Button(template.title) {
                                                phase.days[idx].templateID = template.id
                                            }
                                        }
                                    } label: {
                                        Text(templateLabel(for: phase.days[idx].templateID))
                                            .font(.system(size: 13))
                                            .foregroundStyle(AppTheme.fg2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(mode.navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始") { commit() }
                        .disabled(draftPhases.isEmpty)
                }
            }
            .onAppear {
                if draftPhases.isEmpty {
                    applyPreset(presetKind)
                }
            }
        }
    }

    /// True when there is a single shared days list (default for macro,
    /// always for singleMeso since it has only one phase).
    private var showSharedDaysSection: Bool {
        switch mode {
        case .macro:      return !phasesVary
        case .singleMeso: return false   // single phase: per-phase editor is enough
        }
    }

    private func templateLabel(for id: UUID?) -> String {
        guard let id, let t = allTemplates.first(where: { $0.id == id }) else { return "选择模板 ›" }
        return t.title
    }

    private func applyPreset(_ kind: MacroPresetKind) {
        let phases = kind.phases
        draftPhases = phases.enumerated().map { idx, p in
            DraftPhase(
                order: idx,
                phase: p.phase,
                label: p.label,
                totalWeeks: p.totalWeeks,
                weekMultipliers: p.weekMultipliers,
                rpeCap: p.rpeCap,
                repsLow: p.repsLow,
                repsHigh: p.repsHigh,
                days: defaultDays(count: daysPerWeek)
            )
        }
        if draftPhases.isEmpty && kind == .empty {
            draftPhases = [
                DraftPhase(
                    order: 0,
                    phase: "custom",
                    label: "自定义阶段",
                    totalWeeks: 4,
                    weekMultipliers: [1.0, 1.025, 1.05, 0.6],
                    rpeCap: 8.0,
                    repsLow: 6,
                    repsHigh: 10,
                    days: defaultDays(count: daysPerWeek)
                )
            ]
        }
        if sharedDays.isEmpty {
            sharedDays = defaultDays(count: daysPerWeek)
        }
    }

    private func syncDays(to count: Int) {
        sharedDays = adjustDays(sharedDays, to: count)
        for idx in draftPhases.indices {
            draftPhases[idx].days = adjustDays(draftPhases[idx].days, to: count)
        }
    }

    private func adjustDays(_ current: [DraftDay], to count: Int) -> [DraftDay] {
        if count > current.count {
            let extra = (current.count..<count).map { i in
                DraftDay(dayIndex: i, label: "Day \(i + 1)", templateID: nil)
            }
            return current + extra
        } else if count < current.count {
            return Array(current.prefix(count))
        }
        return current
    }

    private func defaultDays(count: Int) -> [DraftDay] {
        (0..<count).map { DraftDay(dayIndex: $0, label: "Day \($0 + 1)", templateID: nil) }
    }

    private func adjustMultipliers(_ current: [Double], to count: Int) -> [Double] {
        if count <= current.count { return Array(current.prefix(count)) }
        return current + Array(repeating: 1.0, count: count - current.count)
    }

    private func commit() {
        for old in existingMacros where old.isActive {
            old.isActive = false
            old.endedAt = .now
        }

        let macro = MacrocycleProgram(
            title: title.trimmingCharacters(in: .whitespaces).isEmpty ? "大周期" : title,
            startDate: Calendar.current.startOfDay(for: startDate),
            isActive: true
        )
        modelContext.insert(macro)

        for draft in draftPhases {
            let meso = Mesocycle(
                order: draft.order,
                phase: draft.phase,
                phaseLabel: draft.label,
                totalWeeks: draft.totalWeeks,
                daysPerWeek: daysPerWeek,
                defaultRpeCap: draft.rpeCap,
                targetRepsLow: draft.repsLow,
                targetRepsHigh: draft.repsHigh,
                macro: macro
            )
            modelContext.insert(meso)

            for (i, mult) in draft.weekMultipliers.enumerated() {
                let isDeload = mult < 0.85
                let week = MesocycleWeek(
                    weekIndex: i,
                    loadMultiplier: mult,
                    isDeload: isDeload,
                    meso: meso
                )
                modelContext.insert(week)
            }

            let daysSource = showSharedDaysSection ? sharedDays : draft.days
            for d in daysSource {
                let day = MesocycleDay(
                    dayIndex: d.dayIndex,
                    label: d.label,
                    templateID: d.templateID,
                    meso: meso
                )
                modelContext.insert(day)
            }
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct DraftPhase: Identifiable {
    let id = UUID()
    var order: Int
    var phase: String
    var label: String
    var totalWeeks: Int
    var weekMultipliers: [Double]
    var rpeCap: Double
    var repsLow: Int
    var repsHigh: Int
    var days: [DraftDay]
}

private struct DraftDay: Identifiable {
    let id = UUID()
    var dayIndex: Int
    var label: String
    var templateID: UUID?
}
