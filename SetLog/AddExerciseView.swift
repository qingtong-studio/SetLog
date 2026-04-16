import SwiftUI
import SwiftData

private struct ExerciseConfiguration {
    var sets: Int
    var reps: Int
    var weightText: String

    static let defaultValue = ExerciseConfiguration(sets: 4, reps: 10, weightText: "0")

    func parsedWeightKg(weightUnit: WeightUnit) -> Double? {
        guard let value = Double(weightText.replacingOccurrences(of: ",", with: ".")), value >= 0 else {
            return nil
        }
        return value.convertedWeight(from: weightUnit, to: .kilogram)
    }
}

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [AppPreferences]
    @Query(sort: [SortDescriptor(\ExerciseCatalogItem.createdAt)]) private var exercises: [ExerciseCatalogItem]

    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    @State private var selectedExerciseIDs: [UUID] = []
    @State private var activeConfiguredExerciseID: UUID?
    @State private var exerciseConfigurations: [UUID: ExerciseConfiguration] = [:]
    @State private var isPresentingCustomExerciseSheet = false
    @State private var draftCustomName = ""
    @State private var draftCustomCategory = "胸部"
    @State private var draftCustomTargetMuscle = ""
    @State private var draftCustomSets = 4
    @State private var draftCustomReps = 10
    @State private var draftCustomWeightText = "0"
    @State private var customValidationMessage: String?

    let session: WorkoutSession

    private let categories = ["全部", "胸部", "腿部", "背部", "肩部", "手臂"]

    private var filteredExercises: [ExerciseCatalogItem] {
        exercises.filter { exercise in
            let matchesCategory = selectedCategory == "全部" || exercise.category == selectedCategory
            let matchesSearch = searchText.isEmpty ||
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.targetMuscle.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    private var selectedExercise: ExerciseCatalogItem? {
        let selectedExerciseID = activeConfiguredExerciseID ?? selectedExerciseIDs.last
        guard let selectedExerciseID else {
            return filteredExercises.first ?? exercises.first
        }
        return exercises.first(where: { $0.id == selectedExerciseID }) ?? filteredExercises.first ?? exercises.first
    }

    private var weightUnit: WeightUnit {
        preferences.first?.weightUnit ?? .kilogram
    }

    private var selectedExercises: [ExerciseCatalogItem] {
        selectedExerciseIDs.compactMap { id in
            exercises.first(where: { $0.id == id })
        }
    }

    private var canConfirmSelection: Bool {
        !selectedExerciseIDs.isEmpty && selectedExerciseIDs.allSatisfy { configuration(for: $0).parsedWeightKg(weightUnit: weightUnit) != nil }
    }

    private var selectedExerciseConfiguration: ExerciseConfiguration {
        guard let selectedExercise else {
            return ExerciseConfiguration.defaultValue
        }
        return configuration(for: selectedExercise.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    searchBar
                    categoryTabs
                    exerciseList
                    defaultSettingsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            confirmButton
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .background(.white)
        }
        .background(Color(.systemGray6))
        .navigationBarHidden(true)
        .onAppear {
            syncSelectionState()
        }
        .onChange(of: selectedExerciseIDs) { _, _ in
            syncSelectionState()
        }
        .sheet(isPresented: $isPresentingCustomExerciseSheet) {
            NavigationStack {
                customExerciseSheet
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var topBar: some View {
        ZStack {
            Text("添加动作")
                .font(.system(size: 18, weight: .semibold))

            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button("自定义") {
                    prepareCustomExerciseDraft()
                    isPresentingCustomExerciseSheet = true
                }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(.white)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("搜索动作名称...", text: $searchText)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(Color(.systemGray5).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("常用动作")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                if !selectedExerciseIDs.isEmpty {
                    Text("已选 \(selectedExerciseIDs.count) 项")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            if filteredExercises.isEmpty {
                emptyExerciseState
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredExercises) { exercise in
                        Button(action: {
                            toggleSelection(for: exercise.id)
                        }) {
                            ExerciseOptionRow(
                                exercise: exercise,
                                selectionIndex: selectedExerciseIDs.firstIndex(of: exercise.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var defaultSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "figure.strengthtraining.traditional")
                    Text("默认参数设置")
                        .font(.system(size: 14, weight: .bold))
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(weightUnit.displaySymbol)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 26)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text(weightUnit == .pound ? "KG" : "LB")
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 26)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .font(.system(size: 11, weight: .bold))
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(summaryText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if !selectedExerciseIDs.isEmpty {
                selectedExerciseList
            }

            HStack(spacing: 12) {
                AdjustableParameterField(
                    title: "组数 (Sets)",
                    value: selectedExerciseConfiguration.sets,
                    range: 1...12
                ) { delta in
                    guard let selectedExercise else {
                        return
                    }
                    updateConfiguration(for: selectedExercise.id) { configuration in
                        configuration.sets = min(12, max(1, configuration.sets + delta))
                    }
                }
                AdjustableParameterField(
                    title: "次数 (Reps)",
                    value: selectedExerciseConfiguration.reps,
                    range: 1...30
                ) { delta in
                    guard let selectedExercise else {
                        return
                    }
                    updateConfiguration(for: selectedExercise.id) { configuration in
                        configuration.reps = min(30, max(1, configuration.reps + delta))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("初始重量 (\(weightUnit.displaySymbol))", systemImage: "scalemass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(weightUnit.displaySymbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                    TextField(
                        "0",
                        text: Binding(
                            get: { selectedExerciseConfiguration.weightText },
                            set: { newValue in
                                guard let selectedExercise else {
                                    return
                                }
                                updateConfiguration(for: selectedExercise.id) { configuration in
                                    configuration.weightText = newValue
                                }
                            }
                        )
                    )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 54)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if selectedExercise != nil, selectedExerciseConfiguration.parsedWeightKg(weightUnit: weightUnit) == nil {
                    Text("请输入有效重量")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red)
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

    private var confirmButton: some View {
        Button(action: addSelectedExercise) {
            HStack(spacing: 8) {
                Text(selectedExerciseIDs.isEmpty ? "请选择动作" : "确认添加动作")
                    .font(.system(size: 16, weight: .semibold))
                if !selectedExerciseIDs.isEmpty {
                    Text("(\(selectedExerciseIDs.count))")
                        .font(.system(size: 15, weight: .bold))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(canConfirmSelection ? Color.black : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!canConfirmSelection)
    }

    private var summaryText: String {
        guard selectedExercise != nil else {
            return "请选择一个或多个动作。"
        }
        return "已选择 \(selectedExerciseIDs.count) 个动作。可在下方调整顺序、删除动作，并切换当前编辑项。加入训练时会按这里的顺序写入。"
    }

    private var selectedExerciseList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("已选动作")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("拖前后逻辑用上下调整替代")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 8) {
                ForEach(Array(selectedExercises.enumerated()), id: \.element.id) { index, exercise in
                    SelectedExerciseRow(
                        title: exercise.name,
                        subtitle: configurationSummary(for: exercise.id),
                        index: index + 1,
                        isActive: exercise.id == (activeConfiguredExerciseID ?? selectedExerciseIDs.last),
                        canMoveUp: index > 0,
                        canMoveDown: index < selectedExerciseIDs.count - 1,
                        onSelect: {
                            activeConfiguredExerciseID = exercise.id
                        },
                        onMoveUp: {
                            moveSelectedExercise(exercise.id, direction: -1)
                        },
                        onMoveDown: {
                            moveSelectedExercise(exercise.id, direction: 1)
                        },
                        onRemove: {
                            removeSelectedExercise(exercise.id)
                        }
                    )
                }
            }
        }
    }

    private var emptyExerciseState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
            Text("没有找到匹配动作")
                .font(.system(size: 15, weight: .semibold))
            Text("可以调整搜索词，或者新建一个自定义动作。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("创建自定义动作") {
                prepareCustomExerciseDraft()
                isPresentingCustomExerciseSheet = true
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    private func addSelectedExercise() {
        guard !selectedExerciseIDs.isEmpty else {
            return
        }

        var nextOrder = (session.exercises.map(\.order).max() ?? -1) + 1

        for selectedExerciseID in selectedExerciseIDs {
            guard
                let selectedExercise = exercises.first(where: { $0.id == selectedExerciseID }),
                let configuredWeightKg = configuration(for: selectedExerciseID).parsedWeightKg(weightUnit: weightUnit)
            else {
                continue
            }

            let configuration = configuration(for: selectedExerciseID)

            let workoutExercise = WorkoutExercise(
                name: selectedExercise.name,
                category: selectedExercise.category,
                order: nextOrder,
                session: session
            )

            workoutExercise.sets = (1...configuration.sets).map { index in
                WorkoutSet(
                    index: index,
                    targetReps: configuration.reps,
                    weightKg: configuredWeightKg,
                    exercise: workoutExercise
                )
            }

            session.exercises.append(workoutExercise)
            nextOrder += 1
        }

        session.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }

    private func toggleSelection(for id: UUID) {
        if let index = selectedExerciseIDs.firstIndex(of: id) {
            selectedExerciseIDs.remove(at: index)
            exerciseConfigurations.removeValue(forKey: id)
            if activeConfiguredExerciseID == id {
                activeConfiguredExerciseID = selectedExerciseIDs.last
            }
        } else {
            selectedExerciseIDs.append(id)
            initializeConfigurationIfNeeded(for: id)
            activeConfiguredExerciseID = id
        }
    }

    private func removeSelectedExercise(_ id: UUID) {
        guard let index = selectedExerciseIDs.firstIndex(of: id) else {
            return
        }

        selectedExerciseIDs.remove(at: index)
        exerciseConfigurations.removeValue(forKey: id)

        if activeConfiguredExerciseID == id {
            activeConfiguredExerciseID = selectedExerciseIDs.indices.contains(index) ? selectedExerciseIDs[index] : selectedExerciseIDs.last
        }
    }

    private func moveSelectedExercise(_ id: UUID, direction: Int) {
        guard let currentIndex = selectedExerciseIDs.firstIndex(of: id) else {
            return
        }

        let targetIndex = currentIndex + direction
        guard selectedExerciseIDs.indices.contains(targetIndex) else {
            return
        }

        selectedExerciseIDs.swapAt(currentIndex, targetIndex)
    }

    private func syncSelectionState() {
        let selectedIDSet = Set(selectedExerciseIDs)
        exerciseConfigurations = exerciseConfigurations.filter { selectedIDSet.contains($0.key) }

        for id in selectedExerciseIDs {
            initializeConfigurationIfNeeded(for: id)
        }

        if let activeConfiguredExerciseID, selectedIDSet.contains(activeConfiguredExerciseID) {
            return
        }

        activeConfiguredExerciseID = selectedExerciseIDs.last
    }

    private func parseWeight(from text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value >= 0 else {
            return nil
        }
        return value.convertedWeight(from: weightUnit, to: .kilogram)
    }

    private func prepareCustomExerciseDraft() {
        draftCustomName = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        draftCustomCategory = selectedCategory == "全部" ? "胸部" : selectedCategory
        draftCustomTargetMuscle = ""
        draftCustomSets = selectedExerciseConfiguration.sets
        draftCustomReps = selectedExerciseConfiguration.reps
        draftCustomWeightText = selectedExerciseConfiguration.weightText
        customValidationMessage = nil
    }

    private func createCustomExercise() {
        let trimmedName = draftCustomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTargetMuscle = draftCustomTargetMuscle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            customValidationMessage = "请输入动作名称"
            return
        }

        guard !trimmedTargetMuscle.isEmpty else {
            customValidationMessage = "请输入目标肌群"
            return
        }

        guard let defaultWeightKg = parseWeight(from: draftCustomWeightText) else {
            customValidationMessage = "请输入有效重量"
            return
        }

        let customExercise = ExerciseCatalogItem(
            name: trimmedName,
            category: draftCustomCategory,
            targetMuscle: trimmedTargetMuscle,
            defaultSets: draftCustomSets,
            defaultReps: draftCustomReps,
            defaultWeightKg: defaultWeightKg,
            symbolName: symbolName(for: draftCustomCategory),
            tintName: tintName(for: draftCustomCategory)
        )

        modelContext.insert(customExercise)
        try? modelContext.save()

        selectedCategory = draftCustomCategory
        searchText = ""
        selectedExerciseIDs = [customExercise.id]
        exerciseConfigurations[customExercise.id] = ExerciseConfiguration(
            sets: draftCustomSets,
            reps: draftCustomReps,
            weightText: draftCustomWeightText
        )
        activeConfiguredExerciseID = customExercise.id
        isPresentingCustomExerciseSheet = false
    }

    private func configuration(for exerciseID: UUID) -> ExerciseConfiguration {
        exerciseConfigurations[exerciseID] ?? .defaultValue
    }

    private func updateConfiguration(for exerciseID: UUID, _ update: (inout ExerciseConfiguration) -> Void) {
        var configuration = configuration(for: exerciseID)
        update(&configuration)
        exerciseConfigurations[exerciseID] = configuration
    }

    private func initializeConfigurationIfNeeded(for exerciseID: UUID) {
        guard exerciseConfigurations[exerciseID] == nil,
              let exercise = exercises.first(where: { $0.id == exerciseID }) else {
            return
        }

        exerciseConfigurations[exerciseID] = ExerciseConfiguration(
            sets: exercise.defaultSets,
            reps: exercise.defaultReps,
            weightText: exercise.defaultWeightKg.formattedWeight(unit: weightUnit)
        )
    }

    private func configurationSummary(for exerciseID: UUID) -> String {
        let configuration = configuration(for: exerciseID)
        let weightText = configuration.parsedWeightKg(weightUnit: weightUnit)?.formattedWeight(unit: weightUnit) ?? "--"
        return "\(configuration.sets) 组 · \(configuration.reps) 次 · \(weightText) \(weightUnit.displaySymbol)"
    }

    private func symbolName(for category: String) -> String {
        switch category {
        case "胸部":
            return "flame.fill"
        case "腿部":
            return "figure.strengthtraining.traditional"
        case "背部":
            return "figure.pull.up"
        case "肩部":
            return "triangle.fill"
        case "手臂":
            return "bolt.fill"
        default:
            return "figure.mixed.cardio"
        }
    }

    private func tintName(for category: String) -> String {
        switch category {
        case "胸部":
            return "orange"
        case "腿部":
            return "blue"
        case "背部":
            return "mint"
        case "肩部":
            return "gray"
        case "手臂":
            return "purple"
        default:
            return "gray"
        }
    }

    private var customExerciseSheet: some View {
        Form {
            Section("基础信息") {
                TextField("动作名称", text: $draftCustomName)
                Picker("分类", selection: $draftCustomCategory) {
                    ForEach(categories.filter { $0 != "全部" }, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                TextField("目标肌群", text: $draftCustomTargetMuscle)
            }

            Section("默认参数") {
                Stepper("组数 \(draftCustomSets)", value: $draftCustomSets, in: 1...12)
                Stepper("次数 \(draftCustomReps)", value: $draftCustomReps, in: 1...30)
                HStack {
                    Text("重量")
                    Spacer()
                    TextField("0", text: $draftCustomWeightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text(weightUnit.displaySymbol)
                        .foregroundStyle(.secondary)
                }
            }

            if let customValidationMessage {
                Section {
                    Text(customValidationMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("自定义动作")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    isPresentingCustomExerciseSheet = false
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    createCustomExercise()
                }
            }
        }
    }
}

private struct ExerciseOptionRow: View {
    let exercise: ExerciseCatalogItem
    let selectionIndex: Int?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.16))
                Image(systemName: exercise.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .bold))
                Text(exercise.targetMuscle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let selectionIndex {
                ZStack {
                    Circle()
                        .fill(Color.black)
                    Text("\(selectionIndex + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 22, height: 22)
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selectionIndex != nil ? Color.black : Color(.systemGray5), lineWidth: selectionIndex != nil ? 1.5 : 1)
        )
    }

    private var color: Color {
        switch exercise.tintName {
        case "orange":
            return .orange
        case "blue":
            return .blue
        case "gray":
            return .gray
        case "mint":
            return .mint
        case "purple":
            return .purple
        default:
            return .secondary
        }
    }
}

private struct SelectedExerciseRow: View {
    let title: String
    let subtitle: String
    let index: Int
    let isActive: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onSelect: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.black : Color(.systemGray5))
                    Text("\(index)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isActive ? .white : .secondary)
                }
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    reorderButton(symbol: "arrow.up", disabled: !canMoveUp, action: onMoveUp)
                    reorderButton(symbol: "arrow.down", disabled: !canMoveDown, action: onMoveDown)
                    reorderButton(symbol: "xmark", tint: .red, action: onRemove)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 58)
            .background(isActive ? Color(.systemGray6) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? Color.black : Color(.systemGray5), lineWidth: isActive ? 1.2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func reorderButton(
        symbol: String,
        disabled: Bool = false,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(disabled ? Color.secondary.opacity(0.45) : tint)
                .frame(width: 26, height: 26)
                .background(Color(.systemGray6))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

private struct AdjustableParameterField: View {
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    let onAdjust: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button(action: {
                    onAdjust(-1)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(value > range.lowerBound ? .primary : .secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.white)
                        .clipShape(Circle())
                }

                Text("\(value)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity)

                Button(action: {
                    onAdjust(1)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(value < range.upperBound ? .primary : .secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.white)
                        .clipShape(Circle())
                }
            }
                .frame(height: 54)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        AddExerciseView(session: WorkoutSession(title: "Preview"))
    }
    .modelContainer(PreviewModelContainer.shared)
}
