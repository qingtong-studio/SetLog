import SwiftData
import SwiftUI
import UIKit

// MARK: - WorkoutRecordEditView
// 训练记录编辑页：复制自 CurrentWorkoutView，去除所有计时器/休息相关逻辑。
// 用于从历史记录中编辑已完成训练，或为指定日期手动添加训练记录。

struct WorkoutRecordEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [AppPreferences]

    @State private var isPresentingAddExercise = false
    @State private var exerciseToReplace: WorkoutExercise?
    @State private var draggingExerciseID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var cardHeights: [UUID: CGFloat] = [:]
    @State private var focusedSetRowID: UUID?

    let workout: WorkoutSession

    init(workout: WorkoutSession) {
        self.workout = workout
    }

    private var weightUnit: WeightUnit {
        preferences.first?.weightUnit ?? .kilogram
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        let exercises = workout.orderedExercises
                        let draggingIndex = exercises.firstIndex(where: { $0.id == draggingExerciseID }) ?? -1
                        let targetIndex = draggingIndex >= 0 ? computeTargetIndex(from: draggingIndex, offset: dragTranslation, exercises: exercises) : -1
                        let draggedHeight = draggingIndex >= 0 ? (cardHeights[exercises[draggingIndex].id] ?? 220) : 220

                        VStack(spacing: 14) {
                            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                                let isDragging = draggingExerciseID == exercise.id
                                let yOffset = isDragging ? dragTranslation : cardDisplacement(for: index, draggingIndex: draggingIndex, targetIndex: targetIndex, draggedHeight: draggedHeight)

                                makeCard(for: exercise, exercises: exercises)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: RecordCardHeightKey.self,
                                            value: [exercise.id: geo.size.height]
                                        )
                                    }
                                )
                                .offset(y: yOffset)
                                .zIndex(isDragging ? 10 : 0)
                                .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8), value: yOffset)
                            }
                            .onPreferenceChange(RecordCardHeightKey.self) { heights in
                                cardHeights.merge(heights) { $1 }
                            }

                            addExerciseButton
                            footerText
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 28)
                    }
                }
                .onChange(of: focusedSetRowID) { _, rowID in
                    guard let rowID else { return }
                    withAnimation(.easeInOut(duration: 0.22)) {
                        proxy.scrollTo(rowID, anchor: .center)
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationBarHidden(true)
                .ignoresSafeArea(edges: .bottom)
                .toolbar(.hidden, for: .tabBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    stickyHeader
                }
                .sheet(isPresented: $isPresentingAddExercise) {
                    NavigationStack {
                        AddExerciseView(session: workout)
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
                .sheet(item: $exerciseToReplace) { exercise in
                    ExerciseReplacePickerView(exercise: exercise, workout: workout)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        })
    }

    // MARK: - Card Builder (拆分避免编译器类型推断超时)

    private func makeCard(for exercise: WorkoutExercise, exercises: [WorkoutExercise]) -> ExerciseEditorCard {
        let onToggle: (WorkoutSet) -> Void      = { [self] set in toggle(set: set) }
        let onWeight: (WorkoutSet, String) -> Void = { [self] set, v in updateWeight(for: set, value: v) }
        let onReps:   (WorkoutSet, String) -> Void = { [self] set, v in updateReps(for: set, value: v) }
        let onRest:   (WorkoutSet, String) -> Void = { [self] set, v in updateRest(for: set, value: v) }
        let onBegin:  (WorkoutSet) -> Void      = { [self] set in focusedSetRowID = set.id }
        let onWRight: (WorkoutSet) -> Void      = { [self] set in copyWeightRight(for: set, in: exercise) }
        let onWDown:  (WorkoutSet) -> Void      = { [self] set in copyWeightDown(for: set, in: exercise) }
        let onRDown:  (WorkoutSet) -> Void      = { [self] set in copyRepsDown(for: set, in: exercise) }
        let onAdd:    () -> Void                = { [self] in addSet(to: exercise) }
        let onWMode:  () -> Void                = { [self] in toggleWeightMode(for: exercise) }
        let onSType:  (WorkoutSet) -> Void      = { [self] set in toggleSetType(for: set) }
        let onWarmup: () -> Void                = { [self] in addWarmupSet(to: exercise) }
        let onRepl:   () -> Void                = { [self] in exerciseToReplace = exercise }
        let onDel:    () -> Void                = { [self] in delete(exercise: exercise) }
        let onActivated: () -> Void = { [self] in
            if draggingExerciseID == nil {
                draggingExerciseID = exercise.id
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
        let onChanged: (CGFloat) -> Void = { [self] offset in
            if draggingExerciseID == exercise.id { dragTranslation = offset }
        }
        let onEnded: () -> Void = { [self] in
            if draggingExerciseID != nil {
                let fromIdx = exercises.firstIndex(where: { $0.id == draggingExerciseID }) ?? 0
                let toIdx   = computeTargetIndex(from: fromIdx, offset: dragTranslation, exercises: exercises)
                if fromIdx != toIdx { moveExercise(from: fromIdx, to: toIdx) }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    draggingExerciseID = nil
                    dragTranslation = 0
                }
            }
        }
        return ExerciseEditorCard(
            exercise: exercise, weightUnit: weightUnit,
            isDragging: draggingExerciseID == exercise.id,
            onToggleSet: onToggle, onUpdateWeight: onWeight, onUpdateReps: onReps,
            onUpdateRest: onRest, onBeginEditingSet: onBegin,
            onCopyWeightRight: onWRight, onCopyWeightDown: onWDown, onCopyRepsDown: onRDown,
            onAddSet: onAdd, onToggleWeightMode: onWMode, onToggleSetType: onSType,
            onAddWarmupSet: onWarmup, onReplaceExercise: onRepl, onDelete: onDel,
            onDragActivated: onActivated, onDragChanged: onChanged, onDragEnded: onEnded
        )
    }

    // MARK: - Sticky Header

    private var stickyHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color(uiColor: .label))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.title)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(dateText(for: workout.dateStarted))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: saveAndDismiss) {
                Text("保存")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            Color(uiColor: .systemGroupedBackground)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        )
    }

    // MARK: - Save

    private func saveAndDismiss() {
        workout.isCompleted = true
        if workout.dateEnded == nil {
            workout.dateEnded = workout.dateStarted
        }
        workout.updatedAt = Date.now
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Add Exercise Button

    private var addExerciseButton: some View {
        Button(action: { isPresentingAddExercise = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("增加训练动作")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1.2)
            )
        }
    }

    private var footerText: some View {
        Text("END OF WORKOUT PLAN")
            .font(.system(size: 10, weight: .bold))
            .tracking(2)
            .foregroundStyle(Color(red: 0.62, green: 0.64, blue: 0.68))
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    // MARK: - Editing Functions (no timer/rest side effects)

    private func toggle(set: WorkoutSet) {
        set.isCompleted.toggle()
        set.actualReps = set.actualReps ?? set.targetReps
        set.completedAt = set.isCompleted ? Date.now : nil
        set.recordedRestSeconds = nil
        workout.updatedAt = Date.now
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func addSet(to exercise: WorkoutExercise) {
        let sourceSet = exercise.orderedSets.last
        let newSet = WorkoutSet(
            index: exercise.orderedSets.count + 1,
            targetReps: sourceSet?.targetReps,
            actualReps: nil,
            weightKg: sourceSet?.weightKg ?? 0,
            restAfter: sourceSet?.restAfter ?? 90,
            exercise: exercise
        )
        exercise.sets.append(newSet)
        workout.updatedAt = Date.now
        try? modelContext.save()
    }

    private func delete(exercise: WorkoutExercise) {
        if let index = workout.exercises.firstIndex(where: { $0.id == exercise.id }) {
            workout.exercises.remove(at: index)
        }
        for (index, item) in workout.orderedExercises.enumerated() {
            item.order = index
        }
        modelContext.delete(exercise)
        workout.updatedAt = Date.now
        try? modelContext.save()
    }

    private func updateWeight(for set: WorkoutSet, value: String) {
        let normalized = value.replacingOccurrences(of: ",", with: ".")
        set.weightKg = Double(normalized) ?? set.weightKg
        workout.updatedAt = Date.now
        try? modelContext.save()
    }

    private func updateReps(for set: WorkoutSet, value: String) {
        set.actualReps = Int(value) ?? set.actualReps
        set.targetReps = Int(value) ?? set.targetReps
        workout.updatedAt = Date.now
        try? modelContext.save()
    }

    private func updateRest(for set: WorkoutSet, value: String) {
        set.restAfter = TimeInterval(value) ?? set.restAfter
        workout.updatedAt = Date.now
        try? modelContext.save()
    }

    private func copyWeightRight(for set: WorkoutSet, in exercise: WorkoutExercise) {
        let orderedSets = exercise.orderedSets
        guard let currentIndex = orderedSets.firstIndex(where: { $0.id == set.id }),
              currentIndex + 1 < orderedSets.count else { return }
        let nextSet = orderedSets[currentIndex + 1]
        guard !nextSet.isCompleted else { return }
        nextSet.weightKg = set.weightKg
        workout.updatedAt = Date.now
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func copyWeightDown(for set: WorkoutSet, in exercise: WorkoutExercise) {
        let orderedSets = exercise.orderedSets
        guard let currentIndex = orderedSets.firstIndex(where: { $0.id == set.id }) else { return }
        for i in (currentIndex + 1)..<orderedSets.count {
            let targetSet = orderedSets[i]
            guard !targetSet.isCompleted else { continue }
            targetSet.weightKg = set.weightKg
        }
        workout.updatedAt = Date.now
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func copyRepsDown(for set: WorkoutSet, in exercise: WorkoutExercise) {
        let orderedSets = exercise.orderedSets
        guard let currentIndex = orderedSets.firstIndex(where: { $0.id == set.id }) else { return }
        let reps = set.actualReps ?? set.targetReps
        for i in (currentIndex + 1)..<orderedSets.count {
            let targetSet = orderedSets[i]
            guard !targetSet.isCompleted else { continue }
            if let reps {
                targetSet.actualReps = reps
                targetSet.targetReps = reps
            }
        }
        workout.updatedAt = Date.now
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func toggleWeightMode(for exercise: WorkoutExercise) {
        exercise.weightMode = exercise.weightMode == .standard ? .singleHand : .standard
        try? modelContext.save()
    }

    private func toggleSetType(for set: WorkoutSet) {
        set.setType = set.setType == .working ? .warmup : .working
        if set.isWarmup {
            set.restAfter = min(set.restAfter, 60)
        }
        workout.updatedAt = Date.now
        try? modelContext.save()
    }

    private func addWarmupSet(to exercise: WorkoutExercise) {
        let newSet = WorkoutSet(
            index: 0,
            targetReps: exercise.orderedSets.first?.targetReps ?? 10,
            weightKg: (exercise.orderedSets.first?.weightKg ?? 20) * 0.5,
            restAfter: 45,
            setTypeRawValue: SetType.warmup.rawValue,
            exercise: exercise
        )
        exercise.sets.append(newSet)
        // Reindex: warmup sets first, then working sets
        let warmups = exercise.orderedSets.filter { $0.isWarmup }
        let workings = exercise.orderedSets.filter { !$0.isWarmup }
        for (i, s) in (warmups + workings).enumerated() { s.index = i + 1 }
        workout.updatedAt = Date.now
        try? modelContext.save()
    }

    private func moveExercise(from sourceIndex: Int, to destinationIndex: Int) {
        var exercises = workout.orderedExercises
        let exercise = exercises.remove(at: sourceIndex)
        exercises.insert(exercise, at: destinationIndex)
        for (index, item) in exercises.enumerated() { item.order = index }
        workout.updatedAt = Date.now
        try? modelContext.save()
    }

    // MARK: - Drag Helpers

    private func computeTargetIndex(from draggingIndex: Int, offset: CGFloat, exercises: [WorkoutExercise]) -> Int {
        let draggedHeight = cardHeights[exercises[draggingIndex].id] ?? 220
        var target = draggingIndex
        if offset > 0 {
            var accumulated: CGFloat = 0
            for i in (draggingIndex + 1)..<exercises.count {
                let h = cardHeights[exercises[i].id] ?? 220
                accumulated += h + 14
                if offset > accumulated - h / 2 { target = i } else { break }
            }
        } else if offset < 0 {
            var accumulated: CGFloat = 0
            for i in stride(from: draggingIndex - 1, through: 0, by: -1) {
                let h = cardHeights[exercises[i].id] ?? 220
                accumulated -= h + 14
                if offset < accumulated + draggedHeight / 2 { target = i } else { break }
            }
        }
        return target
    }

    private func cardDisplacement(for index: Int, draggingIndex: Int, targetIndex: Int, draggedHeight: CGFloat) -> CGFloat {
        guard draggingIndex >= 0, index != draggingIndex else { return 0 }
        let low = min(draggingIndex, targetIndex)
        let high = max(draggingIndex, targetIndex)
        guard index >= low && index <= high else { return 0 }
        return draggingIndex < targetIndex ? -(draggedHeight + 14) : (draggedHeight + 14)
    }

    // MARK: - Helpers

    private func dateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
}

// MARK: - PreferenceKey (避免与 CurrentWorkoutView 中的 CardHeightKey 冲突)

private struct RecordCardHeightKey: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}
