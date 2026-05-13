import SwiftUI
import SwiftData

struct TemplateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [AppPreferences]
    @Query private var allDailyPlans: [DailyPlan]

    let template: WorkoutTemplate
    let onApply: (WorkoutTemplate, WorkoutStartMode) -> Void

    @State private var isEditing = false
    @State private var draftSets: [UUID: String] = [:]
    @State private var draftReps: [UUID: String] = [:]
    @State private var draftWeight: [UUID: String] = [:]
    @State private var showSaveDialog = false

    private var weightUnit: WeightUnit {
        preferences.first?.weightUnit ?? .kilogram
    }

    private var orderedExercises: [TemplateExercise] {
        (template.exercises ?? []).sorted { $0.order < $1.order }
    }

    private var todayPlan: DailyPlan? {
        let templateID = template.id
        return allDailyPlans.first { plan in
            plan.templateID == templateID && Calendar.current.isDateInToday(plan.date)
        }
    }

    private func todayPlanExercise(named name: String) -> DailyPlanExercise? {
        todayPlan?.orderedExercises.first { $0.exerciseName == name }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    metaInfoSection
                    exerciseListSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            bottomBar
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .background(AppTheme.bgCard)
        }
        .background(AppTheme.bgPage)
        .navigationBarHidden(true)
        .confirmationDialog(
            "保存方式",
            isPresented: $showSaveDialog,
            titleVisibility: .visible
        ) {
            Button("仅用于今日训练") { saveAsDailyPlan() }
            Button("保存到模板") { saveAsTemplate() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("把改动写到模板默认值,还是仅作为今日训练的一次性计划?")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.fg1)
                }
                Spacer()
                if isEditing {
                    Button(action: cancelEditing) {
                        Text("取消")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.fg2)
                    }
                } else {
                    Button(action: enterEditing) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .semibold))
                            Text("编辑")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.fg1)
                    }
                }
            }

            Text(template.title)
                .font(.system(size: 28, weight: .bold))

            HStack(spacing: 8) {
                Text(template.category)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.fg2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.fillMedium)
                    .clipShape(Capsule())

                if todayPlan != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("今日已计划")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.orange)
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var metaInfoSection: some View {
        HStack(spacing: 0) {
            metaItem(icon: "clock", title: "预计时长", value: "\(template.estimatedDuration) 分钟")
            Divider().frame(height: 40)
            metaItem(icon: "flame", title: "难度", value: template.level)
            Divider().frame(height: 40)
            metaItem(icon: "list.number", title: "动作数", value: "\(orderedExercises.count)")
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    private func metaItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.fg2)
            Text(value)
                .font(.system(size: 16, weight: .bold))
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.fg2)
        }
        .frame(maxWidth: .infinity)
    }

    private var exerciseListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("训练动作")
                    .font(.system(size: 17, weight: .bold))
                if isEditing {
                    Spacer()
                    Text("组 · 次 · 重量")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.fg2)
                }
            }

            VStack(spacing: 10) {
                ForEach(Array(orderedExercises.enumerated()), id: \.element.id) { index, exercise in
                    if isEditing {
                        editableExerciseRow(exercise: exercise, index: index + 1)
                    } else {
                        templateExerciseRow(exercise: exercise, index: index + 1)
                    }
                }
            }
        }
    }

    private func templateExerciseRow(exercise: TemplateExercise, index: Int) -> some View {
        let plan = todayPlanExercise(named: exercise.name)
        let setsValue = plan?.sets ?? exercise.defaultSets
        let repsValue = plan?.reps ?? exercise.defaultReps
        let weightValue = plan?.weightKg ?? exercise.defaultWeightKg

        return HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.invertedStrong)
                .frame(width: 28, height: 28)
                .background(AppTheme.ctaFill)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .semibold))

                HStack(spacing: 8) {
                    Label("\(setsValue) 组", systemImage: "square.stack")
                    Label("\(repsValue) 次", systemImage: "repeat")
                    Label(
                        weightValue > 0
                            ? weightValue.formattedWeightWithUnit(unit: weightUnit)
                            : "按历史",
                        systemImage: "scalemass"
                    )
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(plan != nil ? AppTheme.orange : AppTheme.fg2)
            }

            Spacer()

            Image(systemName: exercise.symbolName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.fg2)
                .frame(width: 36, height: 36)
                .background(AppTheme.fillMedium)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(plan != nil ? AppTheme.orange.opacity(0.4) : AppTheme.fillMedium, lineWidth: 1)
        )
    }

    private func editableExerciseRow(exercise: TemplateExercise, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("\(index)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.invertedStrong)
                    .frame(width: 24, height: 24)
                    .background(AppTheme.ctaFill)
                    .clipShape(Circle())

                Text(exercise.name)
                    .font(.system(size: 15, weight: .semibold))

                Spacer()
            }

            HStack(spacing: 8) {
                draftField(
                    title: "组",
                    text: Binding(
                        get: { draftSets[exercise.id] ?? "" },
                        set: { draftSets[exercise.id] = $0 }
                    ),
                    keyboard: .numberPad
                )
                draftField(
                    title: "次",
                    text: Binding(
                        get: { draftReps[exercise.id] ?? "" },
                        set: { draftReps[exercise.id] = $0 }
                    ),
                    keyboard: .numberPad
                )
                draftField(
                    title: "重量(\(weightUnit.displaySymbol))",
                    text: Binding(
                        get: { draftWeight[exercise.id] ?? "" },
                        set: { draftWeight[exercise.id] = $0 }
                    ),
                    keyboard: .decimalPad
                )
            }
        }
        .padding(14)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    private func draftField(title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.fg2)
            TextField("0", text: text)
                .keyboardType(keyboard)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(AppTheme.fillMedium.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if isEditing {
            editingButtons
        } else {
            applyButton
        }
    }

    private var applyButton: some View {
        HStack(spacing: 10) {
            Button {
                onApply(template, .deload)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 12, weight: .bold))
                    Text("减载模式")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(AppTheme.fg1)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.fillMedium)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                onApply(template, .normal)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play")
                        .font(.system(size: 12, weight: .bold))
                    Text("立即应用")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(AppTheme.invertedStrong)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.ctaFill)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var editingButtons: some View {
        HStack(spacing: 10) {
            Button {
                cancelEditing()
            } label: {
                Text("取消")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.fg1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.fillMedium)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                showSaveDialog = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                    Text("保存")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(AppTheme.invertedStrong)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.ctaFill)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: - Edit lifecycle

    private func enterEditing() {
        prefillDrafts()
        withAnimation(.easeOut(duration: 0.18)) {
            isEditing = true
        }
    }

    private func cancelEditing() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        withAnimation(.easeOut(duration: 0.18)) {
            isEditing = false
        }
    }

    private func prefillDrafts() {
        let plan = todayPlan
        for ex in orderedExercises {
            let dpe = plan?.orderedExercises.first { $0.exerciseName == ex.name }
            let sets = dpe?.sets ?? ex.defaultSets
            let reps = dpe?.reps ?? ex.defaultReps
            let weightKg = dpe?.weightKg ?? ex.defaultWeightKg
            draftSets[ex.id] = "\(sets)"
            draftReps[ex.id] = "\(reps)"
            draftWeight[ex.id] = formatWeightInput(weightKg)
        }
    }

    private func formatWeightInput(_ kg: Double) -> String {
        let converted = kg.convertedWeight(from: .kilogram, to: weightUnit)
        if abs(converted - converted.rounded()) < 0.05 {
            return "\(Int(converted.rounded()))"
        }
        return String(format: "%.1f", converted)
    }

    private func parsedSets(for exercise: TemplateExercise) -> Int {
        Int(draftSets[exercise.id] ?? "") ?? exercise.defaultSets
    }

    private func parsedReps(for exercise: TemplateExercise) -> Int {
        Int(draftReps[exercise.id] ?? "") ?? exercise.defaultReps
    }

    private func parsedWeightKg(for exercise: TemplateExercise) -> Double {
        guard let raw = draftWeight[exercise.id], let display = Double(raw) else {
            return exercise.defaultWeightKg
        }
        return display.convertedWeight(from: weightUnit, to: .kilogram)
    }

    // MARK: - Save

    private func saveAsTemplate() {
        for ex in orderedExercises {
            ex.defaultSets = max(1, parsedSets(for: ex))
            ex.defaultReps = max(0, parsedReps(for: ex))
            ex.defaultWeightKg = max(0, parsedWeightKg(for: ex))
        }
        if let plan = todayPlan {
            modelContext.delete(plan)
        }
        try? modelContext.save()
        finishEditing()
    }

    private func saveAsDailyPlan() {
        let plan: DailyPlan
        if let existing = todayPlan {
            plan = existing
            (plan.exercises ?? []).forEach(modelContext.delete)
            plan.exercises = []
        } else {
            plan = DailyPlan(date: DailyPlan.startOfToday(), templateID: template.id)
            modelContext.insert(plan)
        }

        var rebuilt: [DailyPlanExercise] = []
        for (i, ex) in orderedExercises.enumerated() {
            let dpe = DailyPlanExercise(
                exerciseName: ex.name,
                order: i,
                sets: max(1, parsedSets(for: ex)),
                reps: max(0, parsedReps(for: ex)),
                weightKg: max(0, parsedWeightKg(for: ex)),
                plan: plan
            )
            modelContext.insert(dpe)
            rebuilt.append(dpe)
        }
        plan.exercises = rebuilt
        plan.updatedAt = .now
        try? modelContext.save()
        finishEditing()
    }

    private func finishEditing() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        withAnimation(.easeOut(duration: 0.18)) {
            isEditing = false
        }
    }
}
