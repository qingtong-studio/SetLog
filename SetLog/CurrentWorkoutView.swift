import AudioToolbox
import Combine
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

// MARK: - Toast environment

private struct ShowToastKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    fileprivate var showToast: (String) -> Void {
        get { self[ShowToastKey.self] }
        set { self[ShowToastKey.self] = newValue }
    }
}

private struct CardHeightKey: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Constants

private enum CurrentWorkoutLayout {
    static let cardSpacing: CGFloat = 14
    static let defaultCardHeight: CGFloat = 220
    static let restNotificationID = "rest-timer-complete"
}

private enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

private enum WorkoutAnimation {
    static let trayToggle = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let cardCollapse = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let dragRelease = Animation.spring(response: 0.35, dampingFraction: 0.7)
    static let summaryFade = Animation.easeOut(duration: 0.3)
}

// MARK: - CurrentWorkoutView

struct CurrentWorkoutView: View {
    enum SummaryDisplayMode {
        case fullscreen
        case collapsed
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var preferences: [AppPreferences]

    @State private var isPresentingAddExercise = false
    @State private var exerciseToReplace: WorkoutExercise?
    @State private var draggingExerciseID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var cardHeights: [UUID: CGFloat] = [:]
    @State private var now = Date.now
    @State private var focusedSetRowID: UUID?
    @State private var lastVibrationSecond: Int?
    @State private var summaryDisplayMode: SummaryDisplayMode?
    @State private var toastMessage = ""
    @State private var toastVisible = false

    let workout: WorkoutSession
    let onFinish: (() -> Void)?

    init(workout: WorkoutSession, onFinish: (() -> Void)? = nil) {
        self.workout = workout
        self.onFinish = onFinish
    }

    private var weightUnit: WeightUnit {
        preferences.first?.weightUnit ?? .kilogram
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            scrollContent
            bottomOverlay
        }
        .background(WindowKeyboardDismiss())
        .environment(\.showToast, presentToast)
        .animation(.easeOut(duration: 0.24), value: workout.hasActiveRest)
        .animation(WorkoutAnimation.summaryFade, value: summaryDisplayMode != nil)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { value in
            now = value
            handleRestTick()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    // MARK: - Top-level layout pieces

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            exerciseStack
        }
        .background(AppTheme.bgPage)
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .bottom)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) { stickyHeader }
        .sheet(isPresented: $isPresentingAddExercise) {
            NavigationStack { AddExerciseView(session: workout) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $exerciseToReplace) { exercise in
            ExerciseReplacePickerView(exercise: exercise, workout: workout)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var exerciseStack: some View {
        let exercises = workout.orderedExercises
        let draggingIndex = exercises.firstIndex { $0.id == draggingExerciseID } ?? -1
        let targetIndex = draggingIndex >= 0
            ? computeTargetIndex(from: draggingIndex, offset: dragTranslation, exercises: exercises)
            : -1
        let draggedHeight = draggingIndex >= 0
            ? (cardHeights[exercises[draggingIndex].id] ?? CurrentWorkoutLayout.defaultCardHeight)
            : CurrentWorkoutLayout.defaultCardHeight
        let currentExerciseID = exercises.first { !$0.isFinished }?.id

        return VStack(spacing: 0) {
            VStack(spacing: CurrentWorkoutLayout.cardSpacing) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    let isDragging = draggingExerciseID == exercise.id
                    let yOffset = isDragging
                        ? dragTranslation
                        : cardDisplacement(
                            for: index,
                            draggingIndex: draggingIndex,
                            targetIndex: targetIndex,
                            draggedHeight: draggedHeight
                        )

                    exerciseCard(for: exercise, exercises: exercises, currentExerciseID: currentExerciseID)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: CardHeightKey.self,
                                    value: [exercise.id: geo.size.height]
                                )
                            }
                        )
                        .offset(y: yOffset)
                        .zIndex(isDragging ? 10 : 0)
                        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8), value: yOffset)
                }
                .onPreferenceChange(CardHeightKey.self) { heights in
                    cardHeights.merge(heights) { $1 }
                }

                addExerciseButton
                footerText
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, workout.hasActiveRest ? 112 : 28)
        }
    }

    private func exerciseCard(
        for exercise: WorkoutExercise,
        exercises: [WorkoutExercise],
        currentExerciseID: UUID?
    ) -> some View {
        ExerciseEditorCard(
            exercise: exercise,
            weightUnit: weightUnit,
            isDragging: draggingExerciseID == exercise.id,
            isRestActive: workout.hasActiveRest,
            restSourceSetID: workout.restSourceSetID,
            onToggleSet: { toggle(set: $0) },
            onUpdateWeight: { updateWeight(for: $0, value: $1) },
            onUpdateReps: { updateReps(for: $0, value: $1) },
            onUpdateRest: { updateRest(for: $0, value: $1) },
            onBeginEditingSet: { focusedSetRowID = $0.id },
            onCopyWeightRight: { copyWeightRight(for: $0, in: exercise) },
            onCopyWeightDown: { copyWeightDown(for: $0, in: exercise) },
            onCopyRepsDown: { copyRepsDown(for: $0, in: exercise) },
            onAddSet: { addSet(to: exercise) },
            onToggleWeightMode: { toggleWeightMode(for: exercise) },
            onToggleBodyweight: { toggleIncludesBodyweight(for: exercise) },
            onUpdateBodyweight: { updateBodyweight(for: exercise, kg: $0) },
            onToggleSetType: { toggleSetType(for: $0) },
            onDeleteSet: { deleteSet($0, from: exercise) },
            onAddWarmupSet: { addWarmupSet(to: exercise) },
            onUpdateDefaultRest: { updateDefaultRest(for: exercise, seconds: $0) },
            onReplaceExercise: { exerciseToReplace = exercise },
            onDelete: { delete(exercise: exercise) },
            onDragActivated: { activateDrag(for: exercise) },
            onDragChanged: { handleDragChange(for: exercise, offset: $0) },
            onDragEnded: { endDrag(in: exercises) },
            onUpdateRPE: { updateRPE(for: $0, value: $1) },
            isCurrent: exercise.id == currentExerciseID,
            lastSummary: lastSetSummary(forExerciseNamed: exercise.name),
            savedBodyweightKg: preferences.first?.bodyweightKg
        )
    }

    @ViewBuilder
    private var bottomOverlay: some View {
        if workout.hasActiveRest && summaryDisplayMode == nil {
            floatingBar(zIndex: 1) { collapsedRestCard }
        }

        if summaryDisplayMode == .collapsed {
            floatingBar(zIndex: 2) { collapsedSummaryBar }
        }

        if summaryDisplayMode == .fullscreen {
            WorkoutSummaryOverlay(
                workout: workout,
                weightUnit: weightUnit,
                onCollapse: {
                    withAnimation(WorkoutAnimation.summaryFade) { summaryDisplayMode = .collapsed }
                },
                onDismiss: dismissSummaryAndFinish
            )
            .transition(.opacity)
            .zIndex(3)
        }

        if toastVisible {
            Text(toastMessage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(AppTheme.fg1.opacity(0.9))
                .clipShape(Capsule())
                .padding(.bottom, workout.hasActiveRest ? 116 : 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
                .zIndex(4)
        }
    }

    private func floatingBar<Content: View>(
        zIndex: Double,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(zIndex)
    }

    // MARK: - Sticky header

    private var stickyHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(AppTheme.fg1)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text(elapsedTimeText)
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.fg1)

                Text("进度: \(workout.completedSetCount)/\(max(workout.totalSetCount, 1)) 组  容量: \(workout.totalVolumeKg.formattedVolume(unit: weightUnit))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.fg2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                Menu {
                    Button(role: .destructive, action: deleteWorkout) {
                        Label("删除该训练", systemImage: "trash")
                    }
                    if canSaveBackToTemplate {
                        Button(action: saveChangesToTemplate) {
                            Label("保存并返回", systemImage: "square.and.arrow.down")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(AppTheme.fg2)
                        .frame(width: 29, height: 32)
                }

                Button(action: handlePrimaryAction) {
                    Text(primaryActionTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 32)
                        .background(primaryActionColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(3)
            .background(AppTheme.bgPage)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.fg4, lineWidth: 1))
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background(AppTheme.bgCard)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }

    private var addExerciseButton: some View {
        Button(action: { isPresentingAddExercise = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                Text("增加训练动作").font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppTheme.bgCard)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.fg4, lineWidth: 1.2)
            )
        }
    }

    private var footerText: some View {
        Text("END OF WORKOUT PLAN")
            .font(.system(size: 10, weight: .bold))
            .tracking(2)
            .foregroundStyle(AppTheme.fg3)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    // MARK: - Rest card / summary bar

    private var collapsedRestCard: some View {
        let remainingSeconds = workout.restRemainingSeconds(at: now)
        let progress = workout.restProgress(at: now)

        return HStack(spacing: 14) {
            ZStack {
                Circle().stroke(AppTheme.orange.opacity(0.18), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: max(0.08, 1 - progress))
                    .stroke(AppTheme.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                Text(restSecondsText(remainingSeconds))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.orange)
            }
            .frame(width: 56, height: 56)

            Text("/ \(restSecondsText(workout.restTargetSeconds))")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppTheme.fg3)
                .accessibilityLabel("休息总时长 \(workout.restTargetSeconds) 秒")

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                HStack(spacing: 0) {
                    RestAdjustButton(symbol: "+10s", accessibilityLabel: "增加十秒") {
                        adjustRest(delta: 10)
                    }
                    Rectangle().fill(AppTheme.fg4).frame(width: 1, height: 18)
                    RestAdjustButton(symbol: "-10s", accessibilityLabel: "减少十秒") {
                        adjustRest(delta: -10)
                    }
                }
                .frame(width: 103, height: 44)
                .background(AppTheme.fillSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("跳过") { finishRest() }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 44)
                    .background(AppTheme.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: AppTheme.orange.opacity(0.25), radius: 10, y: 4)
                    .accessibilityLabel("提前完成休息")
                    .accessibilityHint("立即结束当前休息倒计时")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 88)
        .floatingCardStyle()
        .accessibilityElement(children: .contain)
    }

    private var collapsedSummaryBar: some View {
        Button(action: {
            withAnimation(WorkoutAnimation.summaryFade) { summaryDisplayMode = .fullscreen }
        }) {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.confirm)

                VStack(alignment: .leading, spacing: 2) {
                    Text("训练已完成").font(.system(size: 14, weight: .bold))
                    Text(workout.title + " · " + elapsedTimeText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.fg2)
                }

                Spacer()

                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.fg2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .floatingCardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Display helpers

    private var elapsedTimeText: String {
        let totalSeconds = max(0, Int(workout.workoutElapsed(at: now)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func restSecondsText(_ seconds: Int) -> String {
        "\(min(max(0, seconds), 999))s"
    }

    private var primaryActionTitle: String {
        if workout.workoutIsRunning { return "结束" }
        return workout.workoutHasStarted ? "继续" : "开始"
    }

    private var primaryActionColor: Color {
        workout.workoutIsRunning ? AppTheme.orange : AppTheme.confirm
    }

    // MARK: - Persistence helpers

    /// Stamps `updatedAt` and saves. Use for any mutation that changes session data.
    private func commit(touchUpdatedAt: Bool = true) {
        if touchUpdatedAt { workout.updatedAt = now }
        try? modelContext.save()
    }

    // MARK: - Set mutations

    private func toggle(set: WorkoutSet) {
        // Block completing other sets while rest timer is active
        if workout.hasActiveRest && !set.isCompleted && set.id != workout.restSourceSetID {
            Haptics.notify(.warning)
            return
        }

        let toggledSetID = set.id
        set.isCompleted.toggle()
        set.actualReps = set.actualReps ?? set.targetReps
        set.completedAt = set.isCompleted ? now : nil

        if set.isCompleted {
            set.recordedRestSeconds = nil
            if !workout.workoutIsRunning {
                resumeIfCompleted()
                startWorkoutTimer()
            }
            startRest(for: set)
            Haptics.notify(.success)
        } else {
            set.recordedRestSeconds = nil
            set.rpe = nil
            if workout.restSourceSetID == toggledSetID {
                clearRest()
            }
        }

        commit()
    }

    private func resumeIfCompleted() {
        guard workout.isCompleted else { return }
        workout.isCompleted = false
        workout.dateEnded = nil
    }

    private func updateRPE(for set: WorkoutSet, value: Int?) {
        guard set.isCompleted, !set.isWarmup else { return }
        set.rpe = value
        commit()
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
        if exercise.sets == nil { exercise.sets = [] }
        exercise.sets?.append(newSet)
        commit()
    }

    private func deleteSet(_ set: WorkoutSet, from exercise: WorkoutExercise) {
        if workout.restSourceSetID == set.id { clearRest() }
        exercise.sets?.removeAll { $0.id == set.id }
        modelContext.delete(set)
        reindexSets(in: exercise)
        commit()
    }

    private func reindexSets(in exercise: WorkoutExercise) {
        for (i, s) in (exercise.warmupSets + exercise.workingSets).enumerated() {
            s.index = i + 1
        }
    }

    private func delete(exercise: WorkoutExercise) {
        if exercise.orderedSets.contains(where: { $0.id == workout.restSourceSetID }) {
            clearRest()
        }

        if let index = workout.exercises?.firstIndex(where: { $0.id == exercise.id }) {
            workout.exercises?.remove(at: index)
        }

        for (index, item) in workout.orderedExercises.enumerated() {
            item.order = index
        }

        modelContext.delete(exercise)
        commit()
    }

    private func updateWeight(for set: WorkoutSet, value: String) {
        guard let parsedValue = InputValueSanitizer.parseWeight(value) else { return }
        set.weightKg = parsedValue.convertedWeight(from: weightUnit, to: .kilogram)
        commit()
    }

    private func updateReps(for set: WorkoutSet, value: String) {
        guard let parsedValue = InputValueSanitizer.parseInteger(value) else { return }
        set.actualReps = parsedValue
        commit()
    }

    private func updateRest(for set: WorkoutSet, value: String) {
        guard set.canEditRecordedRest, let parsedValue = InputValueSanitizer.parseInteger(value) else {
            return
        }
        set.recordedRestSeconds = parsedValue
        set.restAfter = TimeInterval(parsedValue)
        commit()
    }

    private func toggleSetType(for set: WorkoutSet) {
        set.setType = set.setType == .working ? .warmup : .working
        if set.isWarmup {
            set.restAfter = min(set.restAfter, 60)
        }
        commit()
    }

    private func addWarmupSet(to exercise: WorkoutExercise) {
        let existingWarmups = exercise.warmupSets
        let firstWorking = exercise.workingSets.first
        let source = existingWarmups.last
        let newSet = WorkoutSet(
            index: existingWarmups.count + 1,
            targetReps: source?.targetReps ?? firstWorking?.targetReps ?? 10,
            weightKg: source?.weightKg ?? (firstWorking?.weightKg ?? 20) * 0.5,
            restAfter: source?.restAfter ?? 60,
            setTypeRawValue: SetType.warmup.rawValue,
            exercise: exercise
        )
        if exercise.sets == nil { exercise.sets = [] }
        exercise.sets?.append(newSet)
        reindexSets(in: exercise)
        commit()
    }

    // MARK: - Copy helpers

    private func copyWeightRight(for set: WorkoutSet, in exercise: WorkoutExercise) {
        let sets = exercise.orderedSets
        guard let idx = sets.firstIndex(where: { $0.id == set.id }),
              idx + 1 < sets.count else { return }
        let next = sets[idx + 1]
        guard !next.isCompleted else { return }
        next.weightKg = set.weightKg
        commit()
        Haptics.impact(.light)
    }

    private func copyWeightDown(for set: WorkoutSet, in exercise: WorkoutExercise) {
        applyToFollowingSets(after: set, in: exercise) { $0.weightKg = set.weightKg }
    }

    private func copyRepsDown(for set: WorkoutSet, in exercise: WorkoutExercise) {
        guard let reps = set.actualReps ?? set.targetReps else { return }
        applyToFollowingSets(after: set, in: exercise) {
            $0.actualReps = reps
            $0.targetReps = reps
        }
    }

    private func applyToFollowingSets(
        after set: WorkoutSet,
        in exercise: WorkoutExercise,
        update: (WorkoutSet) -> Void
    ) {
        let sets = exercise.orderedSets
        guard let idx = sets.firstIndex(where: { $0.id == set.id }) else { return }
        for i in (idx + 1)..<sets.count where !sets[i].isCompleted {
            update(sets[i])
        }
        commit()
        Haptics.impact(.light)
    }

    // MARK: - Exercise mode toggles

    private func toggleWeightMode(for exercise: WorkoutExercise) {
        exercise.weightMode = exercise.weightMode == .standard ? .singleHand : .standard
        commit(touchUpdatedAt: false)
    }

    private func toggleIncludesBodyweight(for exercise: WorkoutExercise) {
        exercise.includesBodyweight.toggle()
        commit(touchUpdatedAt: false)
    }

    private func updateBodyweight(for exercise: WorkoutExercise, kg: Double) {
        exercise.bodyweightKg = kg
        exercise.includesBodyweight = true
        // Mirror to user-level preferences so it can be reused across exercises
        // and edited from Profile without re-entering each time.
        ensurePreferencesExist()
        if let prefs = preferences.first {
            prefs.bodyweightKg = kg
            prefs.updatedAt = .now
        }
        commit(touchUpdatedAt: false)
    }

    private func ensurePreferencesExist() {
        guard preferences.isEmpty else { return }
        modelContext.insert(AppPreferences())
    }

    private func updateDefaultRest(for exercise: WorkoutExercise, seconds: Int) {
        for set in exercise.workingSets {
            set.restAfter = TimeInterval(seconds)
        }
        commit()
    }

    // MARK: - Drag & reorder

    private func activateDrag(for exercise: WorkoutExercise) {
        guard draggingExerciseID == nil else { return }
        draggingExerciseID = exercise.id
        Haptics.impact(.medium)
    }

    private func handleDragChange(for exercise: WorkoutExercise, offset: CGFloat) {
        guard draggingExerciseID == exercise.id else { return }
        dragTranslation = offset
    }

    private func endDrag(in exercises: [WorkoutExercise]) {
        guard draggingExerciseID != nil else { return }
        let fromIdx = exercises.firstIndex { $0.id == draggingExerciseID } ?? 0
        let toIdx = computeTargetIndex(from: fromIdx, offset: dragTranslation, exercises: exercises)
        if fromIdx != toIdx {
            moveExercise(from: fromIdx, to: toIdx)
        }
        withAnimation(WorkoutAnimation.dragRelease) {
            draggingExerciseID = nil
            dragTranslation = 0
        }
    }

    private func moveExercise(from sourceIndex: Int, to destinationIndex: Int) {
        var exercises = workout.orderedExercises
        let exercise = exercises.remove(at: sourceIndex)
        exercises.insert(exercise, at: destinationIndex)
        for (i, ex) in exercises.enumerated() { ex.order = i }
        commit()
    }

    private func computeTargetIndex(
        from startIndex: Int,
        offset: CGFloat,
        exercises: [WorkoutExercise]
    ) -> Int {
        let spacing = CurrentWorkoutLayout.cardSpacing
        var positions: [CGFloat] = [0]
        for i in 0..<max(0, exercises.count - 1) {
            let h = cardHeights[exercises[i].id] ?? CurrentWorkoutLayout.defaultCardHeight
            positions.append(positions.last! + h + spacing)
        }
        guard startIndex < exercises.count else { return startIndex }
        let draggedHeight = cardHeights[exercises[startIndex].id] ?? CurrentWorkoutLayout.defaultCardHeight
        let newCenter = positions[startIndex] + draggedHeight / 2 + offset

        var bestIndex = startIndex
        var bestDist = CGFloat.infinity
        for i in 0..<exercises.count {
            let h = cardHeights[exercises[i].id] ?? CurrentWorkoutLayout.defaultCardHeight
            let center = positions[i] + h / 2
            let dist = abs(newCenter - center)
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }
        return bestIndex
    }

    private func cardDisplacement(
        for index: Int,
        draggingIndex: Int,
        targetIndex: Int,
        draggedHeight: CGFloat
    ) -> CGFloat {
        guard draggingIndex >= 0, index != draggingIndex else { return 0 }
        let shift = draggedHeight + CurrentWorkoutLayout.cardSpacing
        if targetIndex > draggingIndex, index > draggingIndex, index <= targetIndex {
            return -shift
        }
        if targetIndex < draggingIndex, index >= targetIndex, index < draggingIndex {
            return shift
        }
        return 0
    }

    // MARK: - Workout lifecycle

    private func deleteWorkout() {
        clearRest()
        modelContext.delete(workout)
        try? modelContext.save()
        finishOrDismiss()
    }

    /// Visible only when the session was started from a named template and the
    /// active mode permits writing back (e.g. deload mode is read-only).
    private var canSaveBackToTemplate: Bool {
        guard workout.startModeBehavior.allowsTemplateSaveBack else { return false }
        guard let name = workout.templateName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return false
        }
        return matchingTemplate(named: name) != nil
    }

    private func matchingTemplate(named name: String) -> WorkoutTemplate? {
        var descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.title == name }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// Persist current exercise/set edits back to the source template, then
    /// dismiss the workout view without ending the session.
    private func saveChangesToTemplate() {
        guard let name = workout.templateName, let template = matchingTemplate(named: name) else { return }

        let workoutExercises = workout.orderedExercises
        let existingTemplateExercises = (template.exercises ?? []).sorted { $0.order < $1.order }
        var byName: [String: TemplateExercise] = [:]
        for te in existingTemplateExercises { byName[te.name] = te }

        var rebuilt: [TemplateExercise] = []
        for (order, we) in workoutExercises.enumerated() {
            let workingSets = we.workingSets
            let setCount = max(workingSets.count, 1)
            let topWeight = workingSets.map(\.weightKg).max() ?? 0
            let reps = workingSets.compactMap { $0.actualReps ?? $0.targetReps }.first ?? 0
            let symbol = byName[we.name]?.symbolName
                ?? (existingTemplateExercises.first { $0.name == we.name }?.symbolName)
                ?? "figure.strengthtraining.traditional"

            if let existing = byName[we.name] {
                existing.order = order
                existing.category = we.category
                existing.defaultSets = setCount
                existing.defaultReps = reps
                existing.defaultWeightKg = topWeight
                rebuilt.append(existing)
                byName.removeValue(forKey: we.name)
            } else {
                let new = TemplateExercise(
                    name: we.name,
                    category: we.category,
                    order: order,
                    defaultSets: setCount,
                    defaultReps: reps,
                    defaultWeightKg: topWeight,
                    symbolName: symbol,
                    template: template
                )
                modelContext.insert(new)
                rebuilt.append(new)
            }
        }

        // Drop template exercises no longer in the session.
        for orphan in byName.values {
            modelContext.delete(orphan)
        }

        template.exercises = rebuilt
        try? modelContext.save()
        finishOrDismiss()
    }

    private func handlePrimaryAction() {
        if workout.workoutIsRunning {
            completeWorkout()
            withAnimation(WorkoutAnimation.summaryFade) { summaryDisplayMode = .fullscreen }
        } else {
            resumeIfCompleted()
            startWorkoutTimer()
        }
    }

    private func startWorkoutTimer() {
        guard !workout.workoutIsRunning else { return }
        workout.workoutTimerStartedAt = now
        workout.workoutIsRunning = true
        commit()
    }

    private func pauseWorkoutTimerAccumulating() {
        if workout.workoutIsRunning, let startedAt = workout.workoutTimerStartedAt {
            workout.workoutElapsedOffset += max(0, now.timeIntervalSince(startedAt))
        }
        workout.workoutTimerStartedAt = nil
        workout.workoutIsRunning = false
    }

    private func completeWorkout() {
        clearRest()
        workout.restTargetSeconds = 0
        pauseWorkoutTimerAccumulating()
        workout.isCompleted = true
        workout.dateEnded = now
        ExercisePreferences.apply(from: workout, in: modelContext)
        consumeDailyPlanIfMatching()
        commit()
    }

    /// Once today's training is finished, the matching DailyPlan has fulfilled
    /// its purpose. Drop it so tomorrow's session falls back to the template
    /// defaults again.
    private func consumeDailyPlanIfMatching() {
        guard let templateName = workout.templateName, !templateName.isEmpty else { return }
        guard let template = matchingTemplate(named: templateName) else { return }
        guard let plan = DailyPlan.findTodayPlan(templateID: template.id, in: modelContext) else { return }
        modelContext.delete(plan)
    }

    private func dismissSummaryAndFinish() {
        summaryDisplayMode = nil
        finishOrDismiss()
    }

    private func finishOrDismiss() {
        if let onFinish { onFinish() } else { dismiss() }
    }

    // MARK: - Rest timer

    private func startRest(for set: WorkoutSet) {
        workout.restStartTime = now
        workout.restSourceSetID = set.id
        workout.restTargetSeconds = max(0, Int(set.restAfter))
        workout.restElapsedOffset = 0
        workout.restIsPaused = false
        workout.restLastUpdatedAt = now
        workout.restActualSeconds = nil
        scheduleRestNotification(seconds: workout.restTargetSeconds)
    }

    private func clearRest() {
        workout.restStartTime = nil
        workout.restSourceSetID = nil
        workout.restElapsedOffset = 0
        workout.restIsPaused = false
        workout.restLastUpdatedAt = now
        workout.restActualSeconds = nil
        cancelRestNotification()
    }

    private func finishRest(natural: Bool = false) {
        let actualSeconds = Int(workout.restElapsed(at: now))
        let targetSeconds = workout.restTargetSeconds
        workout.restActualSeconds = actualSeconds

        if let sourceSetID = workout.restSourceSetID, let sourceSet = findSet(id: sourceSetID) {
            // Natural end: record configured target. Skipped: record elapsed seconds (capped at target).
            sourceSet.recordedRestSeconds = natural ? targetSeconds : min(actualSeconds, targetSeconds)
            // If rest duration was adjusted, propagate the new target to subsequent uncompleted sets
            if Int(sourceSet.restAfter) != targetSeconds {
                propagateRestAfter(from: sourceSet, seconds: targetSeconds)
            }
        }

        clearRest()
        try? modelContext.save()
        Haptics.notify(.success)
    }

    private func findSet(id: UUID) -> WorkoutSet? {
        workout.orderedExercises.flatMap(\.orderedSets).first { $0.id == id }
    }

    private func propagateRestAfter(from sourceSet: WorkoutSet, seconds: Int) {
        guard let exercise = sourceSet.exercise else { return }
        let sets = exercise.orderedSets
        guard let idx = sets.firstIndex(where: { $0.id == sourceSet.id }) else { return }
        for i in (idx + 1)..<sets.count where !sets[i].isCompleted {
            sets[i].restAfter = TimeInterval(seconds)
        }
    }

    private func adjustRest(delta: Int) {
        workout.restTargetSeconds = max(0, workout.restTargetSeconds + delta)
        workout.restLastUpdatedAt = now
        if workout.restTargetSeconds == 0 {
            finishRest()
        } else {
            scheduleRestNotification(seconds: workout.restRemainingSeconds(at: now))
            try? modelContext.save()
            Haptics.impact(.light)
        }
    }

    private func handleRestTick() {
        guard workout.hasActiveRest else {
            lastVibrationSecond = nil
            return
        }

        let remaining = workout.restRemainingSeconds(at: now)

        if remaining == 0 {
            AudioServicesPlaySystemSound(SystemSoundID(1007))
            finishRest(natural: true)
            lastVibrationSecond = nil
            return
        }

        if (1...10).contains(remaining), lastVibrationSecond != remaining {
            lastVibrationSecond = remaining
            Haptics.impact(remaining <= 3 ? .heavy : .light)
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard workout.hasActiveRest else { return }
        switch newPhase {
        case .background, .inactive:
            persistRestSnapshot()
        case .active:
            restoreRestSnapshot()
        @unknown default:
            break
        }
    }

    private func persistRestSnapshot() {
        guard workout.hasActiveRest else { return }
        if !workout.restIsPaused {
            workout.restElapsedOffset = workout.restElapsed(at: now)
            workout.restStartTime = now
        }
        workout.restLastUpdatedAt = now
        try? modelContext.save()
    }

    private func restoreRestSnapshot() {
        guard workout.hasActiveRest else { return }
        // Sync now to real time since the Timer may not have fired yet
        now = Date.now
        if workout.restRemainingSeconds(at: now) <= 0 {
            finishRest(natural: true)
            return
        }
        workout.restLastUpdatedAt = now
        try? modelContext.save()
    }

    // MARK: - Notifications

    private func scheduleRestNotification(seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [CurrentWorkoutLayout.restNotificationID])
        guard seconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "休息结束"
        content.body = "该开始下一组了"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: CurrentWorkoutLayout.restNotificationID,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    private func cancelRestNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [CurrentWorkoutLayout.restNotificationID])
    }

    // MARK: - Toast

    private func presentToast(_ message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { toastVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.25)) { toastVisible = false }
        }
    }

    // MARK: - History lookup

    private func lastSetSummary(forExerciseNamed name: String) -> String? {
        let descriptor = FetchDescriptor<WorkoutExercise>(predicate: #Predicate { $0.name == name })
        guard let exercises = try? modelContext.fetch(descriptor) else { return nil }
        let excludeID = workout.id
        let mostRecent = exercises
            .filter { $0.session?.id != excludeID }
            .flatMap { $0.sets ?? [] }
            .filter { $0.isCompleted && !$0.isWarmup && $0.weightKg > 0 }
            .max { lhs, rhs in setSortDate(lhs) < setSortDate(rhs) }
        guard let mostRecent else { return nil }

        let reps = mostRecent.actualReps ?? mostRecent.targetReps ?? 0
        let weightStr = mostRecent.weightKg.formattedWeight(unit: weightUnit)
        let unit = weightUnit.displaySymbol.lowercased()
        return "\(weightStr)\(unit) × \(reps)"
    }

    private func setSortDate(_ set: WorkoutSet) -> Date {
        set.completedAt ?? set.exercise?.session?.dateStarted ?? .distantPast
    }
}

// MARK: - Floating card style

extension View {
    fileprivate func floatingCardStyle(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(AppTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 18, y: 10)
    }
}

// MARK: - ExerciseEditorCard

private struct CardAppearance {
    let strokeColor: Color
    let strokeWidth: CGFloat
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowOffsetY: CGFloat

    static let dragging = CardAppearance(
        strokeColor: AppTheme.orange.opacity(0.3),
        strokeWidth: 2,
        shadowColor: Color.black.opacity(0.15),
        shadowRadius: 16,
        shadowOffsetY: 6
    )

    static let highlighted = CardAppearance(
        strokeColor: AppTheme.orange.opacity(0.45),
        strokeWidth: 1.5,
        shadowColor: AppTheme.orange.opacity(0.18),
        shadowRadius: 14,
        shadowOffsetY: 6
    )

    static let normal = CardAppearance(
        strokeColor: Color.black.opacity(0.04),
        strokeWidth: 0.5,
        shadowColor: Color.black.opacity(0.03),
        shadowRadius: 8,
        shadowOffsetY: 3
    )
}

struct ExerciseEditorCard: View {
    let exercise: WorkoutExercise
    let weightUnit: WeightUnit
    let isDragging: Bool
    var isRestActive: Bool = false
    var restSourceSetID: UUID? = nil
    let onToggleSet: (WorkoutSet) -> Void
    let onUpdateWeight: (WorkoutSet, String) -> Void
    let onUpdateReps: (WorkoutSet, String) -> Void
    let onUpdateRest: (WorkoutSet, String) -> Void
    let onBeginEditingSet: (WorkoutSet) -> Void
    let onCopyWeightRight: (WorkoutSet) -> Void
    let onCopyWeightDown: (WorkoutSet) -> Void
    let onCopyRepsDown: (WorkoutSet) -> Void
    let onAddSet: () -> Void
    let onToggleWeightMode: () -> Void
    let onToggleBodyweight: () -> Void
    let onUpdateBodyweight: (Double) -> Void
    let onToggleSetType: (WorkoutSet) -> Void
    let onDeleteSet: (WorkoutSet) -> Void
    let onAddWarmupSet: () -> Void
    let onUpdateDefaultRest: (Int) -> Void
    let onReplaceExercise: () -> Void
    let onDelete: () -> Void
    let onDragActivated: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: () -> Void
    var onUpdateRPE: (WorkoutSet, Int?) -> Void = { _, _ in }
    var forceEditableRest: Bool = false
    var isCurrent: Bool = false
    var lastSummary: String? = nil
    /// User-level saved bodyweight (from AppPreferences). When the exercise
    /// hasn't been given an explicit bodyweight yet, tapping the pill applies
    /// this value directly instead of prompting.
    var savedBodyweightKg: Double? = nil

    @State private var isShowingEditRestSheet = false
    @State private var isShowingBodyweightSheet = false
    @State private var isCollapsed = true
    @State private var rpeTrayExpandedSetID: UUID?

    private var weightColumnTitle: String {
        exercise.weightMode == .singleHand ? "单边" : "重量"
    }

    private var isHighlighted: Bool { isCollapsed && isCurrent }

    private var appearance: CardAppearance {
        if isDragging { return .dragging }
        if isHighlighted { return .highlighted }
        return .normal
    }

    private func toggleCollapsed() {
        withAnimation(WorkoutAnimation.cardCollapse) {
            isCollapsed.toggle()
        }
    }

    var body: some View {
        let style = appearance
        return VStack(alignment: .leading, spacing: isCollapsed ? 8 : 14) {
            headerRow
            actionRow
            if isCollapsed { collapsedDots }
            if !isCollapsed { expandedSetsSection }
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 14)
        .background(AppTheme.bgCard)
        .contentShape(Rectangle())
        .onTapGesture {
            if isCollapsed { toggleCollapsed() }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(style.strokeColor, lineWidth: style.strokeWidth)
        )
        .shadow(color: style.shadowColor, radius: style.shadowRadius, y: style.shadowOffsetY)
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .sheet(isPresented: $isShowingEditRestSheet) {
            EditDefaultRestSheet(
                currentSeconds: Int(exercise.workingSets.first?.restAfter ?? 90),
                onConfirm: onUpdateDefaultRest
            )
        }
        .sheet(isPresented: $isShowingBodyweightSheet) {
            BodyweightInputSheet(
                currentKg: exercise.bodyweightKg,
                onConfirm: onUpdateBodyweight
            )
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 10) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .bold))
                    .kerning(-0.2)
                    .foregroundStyle(AppTheme.fg1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if isCurrent {
                    Text("当前")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.orange)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(AppTheme.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { toggleCollapsed() }

            Menu {
                Button(action: { isShowingEditRestSheet = true }) {
                    Label("修改计时", systemImage: "timer")
                }
                Button(action: onReplaceExercise) {
                    Label("替换动作", systemImage: "arrow.2.squarepath")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.fg2)
                    .frame(width: 32, height: 32)
            }
        }
    }

    // MARK: - Action row (pill buttons)

    @ViewBuilder
    private var actionRow: some View {
        if !isCollapsed || lastSummary != nil {
            HStack(alignment: .center, spacing: 8) {
                if !isCollapsed {
                    bodyweightPill
                    weightModePill
                    warmupPill
                }
            }
            .frame(height: isCollapsed ? 16 : 26)
        }
    }

    private var bodyweightPill: some View {
        let isActive = exercise.includesBodyweight && exercise.bodyweightKg != nil
        return PillToggleButton(
            icon: "figure.stand",
            title: "自重",
            isActive: isActive,
            action: {
                if exercise.bodyweightKg == nil {
                    if let saved = savedBodyweightKg, saved > 0 {
                        onUpdateBodyweight(saved)
                    } else {
                        isShowingBodyweightSheet = true
                    }
                } else {
                    onToggleBodyweight()
                }
            }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                isShowingBodyweightSheet = true
            }
        )
        .animation(.easeInOut(duration: 0.2), value: exercise.includesBodyweight)
    }

    private var weightModePill: some View {
        PillToggleButton(
            icon: "hand.raised.fill",
            title: "单边",
            isActive: exercise.weightMode == .singleHand,
            action: onToggleWeightMode
        )
        .animation(.easeInOut(duration: 0.2), value: exercise.weightMode)
    }

    private var warmupPill: some View {
        PillToggleButton(
            icon: "flame.fill",
            title: "热身",
            isActive: false,
            action: onAddWarmupSet
        )
    }

    // MARK: - Collapsed dots row

    private var collapsedDots: some View {
        HStack(spacing: 5) {
            ForEach(exercise.orderedSets) { set in
                if set.isWarmup {
                    Text("w")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(set.isCompleted ? AppTheme.orange : AppTheme.fg4)
                        .frame(width: 7, height: 7)
                } else {
                    Circle()
                        .fill(set.isCompleted ? AppTheme.orange : AppTheme.fg4.opacity(0.4))
                        .frame(width: 7, height: 7)
                }
            }
        }
        .padding(.top, -4)
        .contentShape(Rectangle())
        .onTapGesture { toggleCollapsed() }
    }

    // MARK: - Expanded sets section

    private var expandedSetsSection: some View {
        VStack(spacing: 10) {
            VStack(spacing: 10) {
                columnHeaderRow
                setRows
            }
            addSetButton
        }
    }

    private var columnHeaderRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: WorkoutCardLayout.columnSpacing) {
                Text("组").frame(width: WorkoutCardLayout.setIndexWidth, alignment: .center)

                HStack(spacing: 2) {
                    Text(weightColumnTitle)
                    if exercise.weightMode == .singleHand {
                        Text("×2").foregroundStyle(AppTheme.orange)
                    }
                }
                .frame(width: WorkoutCardLayout.weightCellWidth, alignment: .center)

                Text("次数").frame(width: WorkoutCardLayout.repsCellWidth, alignment: .center)
                Text("休息").frame(width: WorkoutCardLayout.restCellWidth, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("状态").frame(width: WorkoutCardLayout.statusWidth, alignment: .center)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(AppTheme.fg3)
        .textCase(.uppercase)
    }

    private var setRows: some View {
        let workingSetIDs = exercise.workingSets.map(\.id)
        return ForEach(exercise.orderedSets) { item in
            VStack(spacing: 0) {
                WorkoutSetRow(
                    set: item,
                    displayIndex: item.isWarmup ? 0 : ((workingSetIDs.firstIndex(of: item.id) ?? -1) + 1),
                    weightUnit: weightUnit,
                    weightMode: exercise.weightMode,
                    canDelete: exercise.orderedSets.count > 1,
                    isRestActive: isRestActive,
                    restSourceSetID: restSourceSetID,
                    onToggle: {
                        let wasCompleted = item.isCompleted
                        onToggleSet(item)
                        setTray(to: (!wasCompleted && !item.isWarmup) ? item.id : nil)
                    },
                    onUpdateWeight: { onUpdateWeight(item, $0) },
                    onUpdateReps: { onUpdateReps(item, $0) },
                    onUpdateRest: { onUpdateRest(item, $0) },
                    onBeginEditing: {
                        onBeginEditingSet(item)
                        if rpeTrayExpandedSetID != nil { setTray(to: nil) }
                    },
                    onCopyRight: { onCopyWeightRight(item) },
                    onCopyDown: { onCopyWeightDown(item) },
                    onCopyRepsDown: { onCopyRepsDown(item) },
                    onToggleSetType: { onToggleSetType(item) },
                    onDeleteSet: { onDeleteSet(item) },
                    onRequestRPEEdit: {
                        setTray(to: rpeTrayExpandedSetID == item.id ? nil : item.id)
                    },
                    forceEditableRest: forceEditableRest
                )

                if rpeTrayExpandedSetID == item.id && !item.isWarmup {
                    RPEInlineTray(
                        currentValue: item.rpe,
                        onSelect: { value in
                            onUpdateRPE(item, value)
                            setTray(to: nil)
                        },
                        onDismiss: { setTray(to: nil) }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: -6)),
                        removal: .opacity.combined(with: .offset(y: -6))
                    ))
                }
            }
        }
    }

    private func setTray(to id: UUID?) {
        withAnimation(WorkoutAnimation.trayToggle) {
            rpeTrayExpandedSetID = id
        }
    }

    private var addSetButton: some View {
        Button(action: onAddSet) {
            HStack(spacing: 0) {
                HStack(spacing: WorkoutCardLayout.columnSpacing) {
                    Text("\(exercise.workingSets.count + 1)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.fg3)
                        .frame(width: WorkoutCardLayout.setIndexWidth, alignment: .center)

                    AddPlaceholderCell(width: WorkoutCardLayout.weightCellWidth)
                    AddPlaceholderCell(width: WorkoutCardLayout.repsCellWidth)
                    AddPlaceholderCell(width: WorkoutCardLayout.restCellWidth)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Circle()
                    .stroke(AppTheme.fg4, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(width: 26, height: 26)
                    .frame(width: WorkoutCardLayout.statusWidth, alignment: .center)
            }
        }
        .buttonStyle(.plain)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(y: -8)),
            removal: .opacity.combined(with: .offset(y: -8))
        ))
    }
}

// MARK: - Pill toggle button

private struct PillToggleButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isActive ? .white : AppTheme.fg2)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(isActive ? AppTheme.orange : AppTheme.fillSubtle)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isActive ? Color.clear : AppTheme.fg4, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WorkoutSetRow

struct WorkoutSetRow: View {
    let set: WorkoutSet
    var displayIndex: Int = 0
    let weightUnit: WeightUnit
    let weightMode: ExerciseWeightMode
    var canDelete: Bool = false
    var isRestActive: Bool = false
    var restSourceSetID: UUID? = nil
    let onToggle: () -> Void
    let onUpdateWeight: (String) -> Void
    let onUpdateReps: (String) -> Void
    let onUpdateRest: (String) -> Void
    let onBeginEditing: () -> Void
    let onCopyRight: () -> Void
    let onCopyDown: () -> Void
    let onCopyRepsDown: () -> Void
    let onToggleSetType: () -> Void
    var onDeleteSet: (() -> Void)? = nil
    var onRequestRPEEdit: () -> Void = {}
    var forceEditableRest: Bool = false

    @State private var restIsLongPressEditable = false
    @Environment(\.showToast) private var showToast

    private var weightDisplayValue: String {
        self.set.weightKg.formattedWeight(unit: weightUnit, fractionDigits: 2)
    }

    private var indexLabel: String {
        self.set.isWarmup ? "W" : "\(displayIndex)"
    }

    private var indexColor: Color {
        self.set.isWarmup ? AppTheme.orange : AppTheme.fg1
    }

    private var isToggleLocked: Bool {
        isRestActive && !set.isCompleted && set.id != restSourceSetID
    }

    private var statusCircleFill: Color {
        guard set.isCompleted else { return Color.clear }
        if set.isWarmup {
            return AppTheme.confirm
        }
        if let rpe = set.rpe {
            return AppTheme.rpeColor(rpe)
        }
        return AppTheme.orange
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: WorkoutCardLayout.columnSpacing) {
                indexMenu
                weightCell
                repsCell
                restCell
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusCircle
        }
        .padding(.vertical, set.isWarmup ? 2 : 0)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .id(set.id)
    }

    private var indexMenu: some View {
        Menu {
            Button(action: onToggleSetType) {
                Label(
                    set.isWarmup ? "切换为正式组" : "切换为热身组",
                    systemImage: set.isWarmup ? "flame" : "flame.fill"
                )
            }
            if canDelete {
                Button(role: .destructive, action: { onDeleteSet?() }) {
                    Label("删除此组", systemImage: "trash")
                }
            }
        } label: {
            Text(indexLabel)
                .font(.system(size: 14, weight: set.isWarmup ? .bold : .regular))
                .foregroundStyle(indexColor)
                .frame(width: WorkoutCardLayout.setIndexWidth, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var weightCell: some View {
        EditableInputCell(
            value: weightDisplayValue,
            valueKind: .weight,
            keyboardType: .decimalPad,
            width: WorkoutCardLayout.weightCellWidth,
            isEditable: true,
            activeTextColor: AppTheme.fg1,
            inactiveTextColor: AppTheme.fg1,
            onBeginEditing: onBeginEditing,
            onCommit: onUpdateWeight,
            onCopyRight: onCopyRight,
            onCopyDown: onCopyDown
        )
    }

    private var repsCell: some View {
        EditableInputCell(
            value: set.repsDisplay,
            valueKind: .reps,
            keyboardType: .numberPad,
            width: WorkoutCardLayout.repsCellWidth,
            isEditable: true,
            activeTextColor: AppTheme.fg1,
            inactiveTextColor: AppTheme.fg1,
            onBeginEditing: onBeginEditing,
            onCommit: onUpdateReps,
            onCopyDown: onCopyRepsDown
        )
    }

    private var restCell: some View {
        let isRestSource = isRestActive && set.id == restSourceSetID
        let restEditable = forceEditableRest || restIsLongPressEditable
        let restLocked = set.canEditRecordedRest && !restEditable
        let restValue: String
        if restEditable {
            restValue = set.recordedRestSeconds.map { "\($0)" } ?? "\(Int(set.restAfter))"
        } else {
            restValue = isRestSource ? "..." : set.completedRestDisplay
        }

        return ZStack {
            EditableInputCell(
                value: restValue,
                valueKind: .rest,
                keyboardType: .numberPad,
                width: WorkoutCardLayout.restCellWidth,
                isEditable: restEditable,
                activeTextColor: AppTheme.orange,
                inactiveTextColor: isRestSource ? AppTheme.orange : AppTheme.fg3,
                onBeginEditing: onBeginEditing,
                onCommit: onUpdateRest,
                onEndEditing: { restIsLongPressEditable = false }
            )
            if restLocked {
                Color.clear
                    .frame(width: WorkoutCardLayout.restCellWidth, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showToast("长按修改休息时间")
                        Haptics.impact(.light)
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                            restIsLongPressEditable = true
                            Haptics.impact(.medium)
                        }
                    )
            }
        }
    }

    // Status circle — tap to complete; tap completed opens RPE tray (or toast for warmup); long press cancels
    private var statusCircle: some View {
        Circle()
            .fill(statusCircleFill)
            .background(
                Circle().stroke(set.isCompleted ? Color.clear : AppTheme.fg3, lineWidth: 2)
            )
            .overlay {
                if set.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 28, height: 28)
            .frame(width: WorkoutCardLayout.statusWidth, height: 40)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isToggleLocked else { return }
                if set.isCompleted {
                    if set.isWarmup {
                        showToast("长按取消完成状态")
                    } else {
                        onRequestRPEEdit()
                    }
                    Haptics.impact(.light)
                } else {
                    onToggle()
                }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    guard set.isCompleted, !isToggleLocked else { return }
                    onToggle()
                    Haptics.impact(.medium)
                }
            )
            .opacity(isToggleLocked ? 0.3 : 1.0)
    }
}

// MARK: - RPE tray

struct RPEInlineTray: View {
    let currentValue: Int?
    let onSelect: (Int) -> Void
    let onDismiss: () -> Void

    private let values: [Int] = [6, 7, 8, 9, 10]

    var body: some View {
        HStack(spacing: 6) {
            Text("RPE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(AppTheme.fg3)
                .padding(.trailing, 2)

            ForEach(values, id: \.self) { value in
                RPEButton(
                    value: value,
                    isSelected: currentValue == value,
                    onTap: {
                        onSelect(value)
                        Haptics.impact(.light)
                    }
                )
            }

            Button(action: {
                onDismiss()
                Haptics.impact(.light)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.fg3)
                    .frame(width: 26, height: 26)
                    .background(AppTheme.fillSubtle)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct RPEButton: View {
    let value: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("\(value)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white : AppTheme.rpeColor(value))
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? AppTheme.rpeColor(value) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.rpeColor(value).opacity(isSelected ? 0 : 0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Input sanitation

private enum InputValueKind {
    case weight
    case reps
    case rest
}

private enum InputValueSanitizer {
    private static let maxWeightIntegerDigits = 3
    private static let maxWeightFractionDigits = 2
    private static let maxIntegerDigits = 3
    private static let maxWeightValue = 999.99
    private static let maxIntegerValue = 999

    static func sanitize(_ text: String, kind: InputValueKind) -> String {
        switch kind {
        case .weight: return sanitizeWeight(text)
        case .reps, .rest: return sanitizeInteger(text)
        }
    }

    static func parseWeight(_ text: String) -> Double? {
        let sanitized = sanitizeWeight(text)
        let normalized = sanitized.hasSuffix(".") ? String(sanitized.dropLast()) : sanitized
        guard !normalized.isEmpty,
              let value = Double(normalized),
              value >= 0, value <= maxWeightValue else {
            return nil
        }
        return value
    }

    static func parseInteger(_ text: String) -> Int? {
        let sanitized = sanitizeInteger(text)
        guard !sanitized.isEmpty,
              let value = Int(sanitized),
              value >= 0, value <= maxIntegerValue else {
            return nil
        }
        return value
    }

    private static func sanitizeWeight(_ text: String) -> String {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        var integerPart = ""
        var fractionPart = ""
        var hasDot = false

        for char in normalized {
            if char.isNumber {
                if hasDot {
                    if fractionPart.count < maxWeightFractionDigits {
                        fractionPart.append(char)
                    }
                } else if integerPart.count < maxWeightIntegerDigits {
                    integerPart.append(char)
                }
            } else if char == "." && !hasDot {
                hasDot = true
            }
        }

        if hasDot {
            let safeIntegerPart = integerPart.isEmpty ? "0" : integerPart
            return "\(safeIntegerPart).\(fractionPart)"
        }
        return integerPart
    }

    private static func sanitizeInteger(_ text: String) -> String {
        String(text.filter(\.isNumber).prefix(maxIntegerDigits))
    }
}

// MARK: - Editable input cell

private struct EditableInputCell: View {
    let value: String
    let valueKind: InputValueKind
    let keyboardType: UIKeyboardType
    let width: CGFloat
    let isEditable: Bool
    let activeTextColor: Color
    let inactiveTextColor: Color
    let onBeginEditing: () -> Void
    let onCommit: (String) -> Void
    var onCopyRight: (() -> Void)?
    var onCopyDown: (() -> Void)?
    var onEndEditing: (() -> Void)?

    var body: some View {
        SelectAllTextField(
            value: value,
            valueKind: valueKind,
            keyboardType: keyboardType,
            isEditable: isEditable,
            textColor: UIColor(isEditable ? activeTextColor : inactiveTextColor),
            onBeginEditing: onBeginEditing,
            onCommit: onCommit,
            onEndEditing: onEndEditing,
            onCopyRight: onCopyRight,
            onCopyDown: onCopyDown
        )
        .frame(width: width)
        .frame(height: 36)
        .background(AppTheme.fillSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SelectAllTextField: UIViewRepresentable {
    let value: String
    let valueKind: InputValueKind
    let keyboardType: UIKeyboardType
    let isEditable: Bool
    let textColor: UIColor
    let onBeginEditing: () -> Void
    let onCommit: (String) -> Void
    var onEndEditing: (() -> Void)?
    var onCopyRight: (() -> Void)?
    var onCopyDown: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onBeginEditing: onBeginEditing,
            onCommit: onCommit,
            onEndEditing: onEndEditing,
            valueKind: valueKind
        )
    }

    func makeUIView(context: Context) -> HiddenCaretTextField {
        let textField = HiddenCaretTextField()
        textField.delegate = context.coordinator
        textField.textAlignment = .center
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.font = .systemFont(ofSize: WorkoutCardLayout.inputFontSize, weight: .regular)
        textField.adjustsFontSizeToFitWidth = false
        textField.keyboardType = keyboardType
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )

        let keyboard = NumericKeyboardInputView(frame: CGRect(x: 0, y: 0, width: 0, height: 224))
        keyboard.targetTextField = textField
        keyboard.onDismiss = { [weak textField, weak coordinator = context.coordinator] in
            coordinator?.suppressNextCommit = true
            textField?.resignFirstResponder()
        }
        keyboard.onConfirm = { [weak textField, weak coordinator = context.coordinator] in
            if let tf = textField { coordinator?.commit(tf) }
            textField?.resignFirstResponder()
        }
        textField.inputView = keyboard
        context.coordinator.keyboard = keyboard

        return textField
    }

    func updateUIView(_ textField: HiddenCaretTextField, context: Context) {
        if textField.text != value, !textField.isFirstResponder {
            textField.text = value
        }
        textField.textColor = textColor
        let wasEditable = textField.isUserInteractionEnabled
        textField.isUserInteractionEnabled = isEditable
        if isEditable && !wasEditable {
            DispatchQueue.main.async { _ = textField.becomeFirstResponder() }
        }
        context.coordinator.onBeginEditing = onBeginEditing
        context.coordinator.onCommit = onCommit
        context.coordinator.onEndEditing = onEndEditing
        context.coordinator.valueKind = valueKind

        if let keyboard = context.coordinator.keyboard {
            keyboard.onCopyRight = onCopyRight
            // Commit the current typed value first so the latest input is used when copying down
            if let onCopyDown {
                keyboard.onCopyDown = { [weak textField] in
                    if let tf = textField {
                        context.coordinator.commit(tf)
                    }
                    onCopyDown()
                }
            } else {
                keyboard.onCopyDown = nil
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var onBeginEditing: () -> Void
        var onCommit: (String) -> Void
        var onEndEditing: (() -> Void)?
        var valueKind: InputValueKind
        weak var keyboard: NumericKeyboardInputView?
        var suppressNextCommit = false
        var originalValue: String?

        init(
            onBeginEditing: @escaping () -> Void,
            onCommit: @escaping (String) -> Void,
            onEndEditing: (() -> Void)?,
            valueKind: InputValueKind
        ) {
            self.onBeginEditing = onBeginEditing
            self.onCommit = onCommit
            self.onEndEditing = onEndEditing
            self.valueKind = valueKind
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            originalValue = textField.text
            onBeginEditing()
            // Select all so typing immediately replaces the existing value
            DispatchQueue.main.async { textField.selectAll(nil) }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if suppressNextCommit {
                textField.text = originalValue
                suppressNextCommit = false
            } else {
                commit(textField)
            }
            onEndEditing?()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            commit(textField)
            textField.resignFirstResponder()
            return true
        }

        @objc func textDidChange(_ textField: UITextField) {
            let current = textField.text ?? ""
            let sanitized = InputValueSanitizer.sanitize(current, kind: valueKind)
            if current != sanitized {
                textField.text = sanitized
            }
        }

        func commit(_ textField: UITextField) {
            let sanitized = InputValueSanitizer.sanitize(textField.text ?? "", kind: valueKind)
            guard !sanitized.isEmpty else { return }
            textField.text = sanitized
            onCommit(sanitized)
        }
    }
}

// Plain vertical bar cursor; suppress copy/paste menu
private final class HiddenCaretTextField: UITextField {
    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] { [] }
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { false }
}

// Attach a window-level tap recognizer that dismisses the keyboard on any tap
// outside a text field. cancelsTouchesInView=false keeps button/textfield taps working.
private struct WindowKeyboardDismiss: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> HostView {
        let v = HostView()
        v.coordinator = context.coordinator
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: HostView, context: Context) {}

    static func dismantleUIView(_ uiView: HostView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var gesture: UITapGestureRecognizer?
        private weak var attachedWindow: UIWindow?

        func attach(to window: UIWindow) {
            if gesture != nil && attachedWindow === window { return }
            detach()
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            gesture = tap
            attachedWindow = window
        }

        func detach() {
            if let g = gesture, let w = attachedWindow {
                w.removeGestureRecognizer(g)
            }
            gesture = nil
            attachedWindow = nil
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            if let hit = view.hitTest(location, with: nil) {
                var current: UIView? = hit
                while let v = current {
                    if v is UITextField || v is UITextView { return }
                    current = v.superview
                }
            }
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }

    final class HostView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window = self.window {
                coordinator?.attach(to: window)
            } else {
                coordinator?.detach()
            }
        }
    }
}

private struct AddPlaceholderCell: View {
    let width: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.fg4, style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                .frame(width: width, height: 36)

            Image(systemName: "plus")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppTheme.fg3)
        }
        .frame(width: width, height: 36)
    }
}

// MARK: - Layout constants

private enum WorkoutCardLayout {
    static let setIndexWidth: CGFloat = 28
    static let weightCellWidth: CGFloat = 62
    static let repsCellWidth: CGFloat = 52
    static let restCellWidth: CGFloat = 52
    static let statusWidth: CGFloat = 40
    static let columnSpacing: CGFloat = 6
    static let inputFontSize: CGFloat = 14
}

// MARK: - Rest adjust button

private struct RestAdjustButton: View {
    let symbol: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.fg1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Summary overlay

private struct WorkoutSummaryOverlay: View {
    let workout: WorkoutSession
    let weightUnit: WeightUnit
    let onCollapse: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            AppTheme.fg1.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.confirm)

                Text("训练完成").font(.system(size: 28, weight: .bold))

                Text(workout.elapsedTimeText)
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                HStack(spacing: 24) {
                    summaryStatItem(title: "总组数", value: "\(workout.totalSetCount)")
                    summaryStatItem(title: "完成", value: "\(workout.completedSetCount)")
                    summaryStatItem(title: "总容量", value: workout.totalVolumeKg.formattedVolume(unit: weightUnit))
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: onDismiss) {
                        Text("完成")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.fg1)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppTheme.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button(action: onCollapse) {
                        Text("收起")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .foregroundStyle(.white)
    }

    private func summaryStatItem(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - Edit default rest sheet

private struct EditDefaultRestSheet: View {
    let currentSeconds: Int
    let onConfirm: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(currentSeconds: Int, onConfirm: @escaping (Int) -> Void) {
        self.currentSeconds = currentSeconds
        self.onConfirm = onConfirm
        _text = State(initialValue: "\(currentSeconds)")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Text("正式组默认休息时间")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.fg2)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("", text: $text)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .frame(width: 120)
                        Text("秒")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(AppTheme.fg2)
                    }
                }

                Spacer()

                Button(action: {
                    if let s = Int(text), s > 0 { onConfirm(s) }
                    dismiss()
                }) {
                    Text("确认")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("修改计时")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Bodyweight input sheet

struct BodyweightInputSheet: View {
    let currentKg: Double?
    let onConfirm: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(currentKg: Double?, onConfirm: @escaping (Double) -> Void) {
        self.currentKg = currentKg
        self.onConfirm = onConfirm
        if let kg = currentKg {
            let format = kg.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f"
            _text = State(initialValue: String(format: format, kg))
        } else {
            _text = State(initialValue: "")
        }
    }

    private var hintText: String {
        currentKg == nil ? "首次需手动输入自重" : "长按按钮可再次修改自重"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Text("请输入自重")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.fg2)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("0", text: $text)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .frame(width: 160)
                        Text("kg")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(AppTheme.fg2)
                    }

                    Text(hintText)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.fg2)
                        .padding(.top, 6)
                }

                Spacer()

                Button(action: {
                    if let kg = Double(text), kg > 0 { onConfirm(kg) }
                    dismiss()
                }) {
                    Text("确认")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle(currentKg == nil ? "设置自重" : "修改自重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Replace exercise picker

struct ExerciseReplacePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ExerciseCatalogItem.createdAt)]) private var exercises: [ExerciseCatalogItem]

    @State private var searchText = ""
    @State private var selectedCategory = "全部"

    let exercise: WorkoutExercise
    let workout: WorkoutSession

    private let categories = ["全部", "胸部", "腿部", "背部", "肩部", "手臂"]

    private var filteredExercises: [ExerciseCatalogItem] {
        exercises.filter { item in
            let matchesCategory = selectedCategory == "全部" || item.category == selectedCategory
            let matchesSearch = searchText.isEmpty ||
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.targetMuscle.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            Button(cat) { selectedCategory = cat }
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(selectedCategory == cat ? AppTheme.orange : AppTheme.fillMedium)
                                .foregroundStyle(selectedCategory == cat ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                List(filteredExercises) { item in
                    Button { replace(with: item) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(AppTheme.fg1)
                            Text(item.targetMuscle)
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.fg2)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "搜索动作")
            }
            .navigationTitle("替换动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func replace(with item: ExerciseCatalogItem) {
        exercise.name = item.name
        exercise.category = item.category
        workout.updatedAt = Date.now
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Preview

private struct CurrentWorkoutPreviewHost: View {
    @Query(
        filter: #Predicate<WorkoutSession> { session in
            session.isCompleted == false
        },
        sort: [SortDescriptor(\WorkoutSession.dateStarted, order: .reverse)]
    ) private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            if let session = sessions.first {
                CurrentWorkoutView(workout: session)
            } else {
                Text("没有可预览的训练数据")
            }
        }
    }
}

#Preview {
    CurrentWorkoutPreviewHost()
        .modelContainer(PreviewModelContainer.shared)
}

enum PreviewModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            AppPreferences.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            WorkoutSet.self,
            ExerciseCatalogItem.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            MacrocycleProgram.self,
            Mesocycle.self,
            MesocycleWeek.self,
            MesocycleDay.self
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
