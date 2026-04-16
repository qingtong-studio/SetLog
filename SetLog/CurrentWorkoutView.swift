import AudioToolbox
import Combine
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

private struct CardHeightKey: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

struct CurrentWorkoutView: View {
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

    enum SummaryDisplayMode {
        case fullscreen
        case collapsed
    }

    let workout: WorkoutSession
    let onFinish: (() -> Void)?

    init(workout: WorkoutSession, onFinish: (() -> Void)? = nil) {
        self.workout = workout
        self.onFinish = onFinish
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

                                ExerciseEditorCard(
                                    exercise: exercise,
                                    weightUnit: weightUnit,
                                    isDragging: isDragging,
                                    isRestActive: workout.hasActiveRest,
                                    restSourceSetID: workout.restSourceSetID,
                                    onToggleSet: { set in
                                        toggle(set: set, in: workout)
                                    },
                                    onUpdateWeight: { set, value in
                                        updateWeight(for: set, value: value, in: workout)
                                    },
                                    onUpdateReps: { set, value in
                                        updateReps(for: set, value: value, in: workout)
                                    },
                                    onUpdateRest: { set, value in
                                        updateRest(for: set, value: value, in: workout)
                                    },
                                    onBeginEditingSet: { set in
                                        focusedSetRowID = set.id
                                    },
                                    onCopyWeightRight: { set in
                                        copyWeightRight(for: set, in: exercise, workout: workout)
                                    },
                                    onCopyWeightDown: { set in
                                        copyWeightDown(for: set, in: exercise, workout: workout)
                                    },
                                    onCopyRepsDown: { set in
                                        copyRepsDown(for: set, in: exercise, workout: workout)
                                    },
                                    onAddSet: {
                                        addSet(to: exercise, in: workout)
                                    },
                                    onToggleWeightMode: {
                                        toggleWeightMode(for: exercise)
                                    },
                                    onToggleSetType: { set in
                                        toggleSetType(for: set, in: workout)
                                    },
                                    onDeleteSet: { set in
                                        deleteSet(set, from: exercise, in: workout)
                                    },
                                    onAddWarmupSet: {
                                        addWarmupSet(to: exercise, in: workout)
                                    },
                                    onReplaceExercise: {
                                        exerciseToReplace = exercise
                                    },
                                    onDelete: {
                                        delete(exercise: exercise, from: workout)
                                    },
                                    onDragActivated: {
                                        if draggingExerciseID == nil {
                                            draggingExerciseID = exercise.id
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }
                                    },
                                    onDragChanged: { offset in
                                        if draggingExerciseID == exercise.id {
                                            dragTranslation = offset
                                        }
                                    },
                                    onDragEnded: {
                                        if draggingExerciseID != nil {
                                            let fromIdx = exercises.firstIndex(where: { $0.id == draggingExerciseID }) ?? 0
                                            let toIdx = computeTargetIndex(from: fromIdx, offset: dragTranslation, exercises: exercises)
                                            if fromIdx != toIdx {
                                                moveExercise(from: fromIdx, to: toIdx, in: workout)
                                            }
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                                draggingExerciseID = nil
                                                dragTranslation = 0
                                            }
                                        }
                                    }
                                )
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
                .onChange(of: focusedSetRowID) { _, rowID in
                    guard let rowID else {
                        return
                    }

                    withAnimation(.easeInOut(duration: 0.22)) {
                        proxy.scrollTo(rowID, anchor: .center)
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationBarHidden(true)
                .ignoresSafeArea(edges: .bottom)
                .toolbar(.hidden, for: .tabBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    stickyHeader(workout: workout)
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

            if workout.hasActiveRest && summaryDisplayMode == nil {
                collapsedRestCard(workout: workout)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }

            if summaryDisplayMode == .collapsed {
                collapsedSummaryBar(workout: workout)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }

            if summaryDisplayMode == .fullscreen {
                WorkoutSummaryOverlay(
                    workout: workout,
                    weightUnit: weightUnit,
                    onCollapse: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            summaryDisplayMode = .collapsed
                        }
                    },
                    onDismiss: {
                        dismissSummaryAndFinish()
                    }
                )
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .animation(.easeOut(duration: 0.24), value: workout.hasActiveRest)
        .animation(.easeOut(duration: 0.3), value: summaryDisplayMode != nil)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { value in
            now = value
            handleRestTick(for: workout)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard workout.hasActiveRest else {
                return
            }

            switch newPhase {
            case .background, .inactive:
                persistRestSnapshot(for: workout)
            case .active:
                restoreRestSnapshot(for: workout)
            @unknown default:
                break
            }
        }
        // Use simultaneousGesture so keyboard dismissal never blocks button taps in the header
        .simultaneousGesture(TapGesture().onEnded {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        })
    }

    private var weightUnit: WeightUnit {
        preferences.first?.weightUnit ?? .kilogram
    }

    private func stickyHeader(workout: WorkoutSession) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color(uiColor: .label))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .padding(.top, 22)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    tagChip(title: "胸部训练")
                    tagChip(title: "力量模式")
                }

                Text(elapsedTimeText(for: workout))
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(uiColor: .label))

                Text("进度: \(workout.completedSetCount)/\(max(workout.totalSetCount, 1)) 组  体积: \(volumeText(workout.totalVolumeKg))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                Menu {
                    Button(role: .destructive) {
                        delete(workout: workout)
                    } label: {
                        Label("删除该训练", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.secondary)
                        .frame(width: 29, height: 32)
                }

                Button(action: {
                    handlePrimaryAction(for: workout)
                }) {
                    Text(primaryActionTitle(for: workout))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 32)
                        .background(primaryActionColor(for: workout))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(3)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .padding(.top, 22)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }

    private func tagChip(title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.primary)
            .frame(width: 40, height: 15)
            .frame(width: 50, height: 17)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(red: 1.00, green: 0.43, blue: 0.06).opacity(0.32), lineWidth: 1.1)
            )
    }

    private var addExerciseButton: some View {
        Button(action: {
            isPresentingAddExercise = true
        }) {
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

    private func collapsedRestCard(workout: WorkoutSession) -> some View {
        let remainingSeconds = workout.restRemainingSeconds(at: now)
        let progress = workout.restProgress(at: now)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color(red: 1.0, green: 0.45, blue: 0.08).opacity(0.18), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: max(0.08, 1 - progress))
                    .stroke(
                        Color(red: 1.0, green: 0.45, blue: 0.08),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                Text(restSecondsText(remainingSeconds))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.08))
            }
            .frame(width: 56, height: 56)

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                HStack(spacing: 0) {
                    RestAdjustButton(symbol: "+10s", accessibilityLabel: "增加十秒") {
                        adjustRest(for: workout, delta: 10)
                    }

                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 1, height: 18)

                    RestAdjustButton(symbol: "-10s", accessibilityLabel: "减少十秒") {
                        adjustRest(for: workout, delta: -10)
                    }
                }
                .frame(width: 103, height: 44)
                .background(Color(uiColor: .tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("跳过") {
                    finishRest(for: workout)
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 44)
                .background(Color(red: 1.0, green: 0.45, blue: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color(red: 1.0, green: 0.45, blue: 0.08).opacity(0.25), radius: 10, y: 4)
                .accessibilityLabel("提前完成休息")
                .accessibilityHint("立即结束当前休息倒计时")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 18, y: 10)
        .accessibilityElement(children: .contain)
    }

    private func elapsedTimeText(for workout: WorkoutSession) -> String {
        let interval = workout.workoutElapsed(at: now)
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func timeText(from totalSeconds: Int) -> String {
        if totalSeconds >= 3600 {
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }

        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func restSecondsText(_ seconds: Int) -> String {
        let clampedSeconds = min(max(0, seconds), 999)
        return "\(clampedSeconds)s"
    }

    private func volumeText(_ value: Double) -> String {
        value.formattedVolume(unit: weightUnit)
    }

    private func toggle(set: WorkoutSet, in workout: WorkoutSession) {
        // Block completing other sets while rest timer is active
        if workout.hasActiveRest && !set.isCompleted && set.id != workout.restSourceSetID {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        let toggledSetID = set.id
        set.isCompleted.toggle()
        set.actualReps = set.actualReps ?? set.targetReps
        set.completedAt = set.isCompleted ? now : nil
        workout.updatedAt = now

        if set.isCompleted {
            set.recordedRestSeconds = nil
            if !workout.workoutIsRunning {
                if workout.isCompleted {
                    workout.isCompleted = false
                    workout.dateEnded = nil
                }
                startWorkoutTimer(for: workout)
            }
            startRest(for: set, in: workout)
            provideNotificationFeedback(.success)
        } else {
            set.recordedRestSeconds = nil
            if workout.restSourceSetID == toggledSetID {
                clearRest(for: workout)
            }
        }

        try? modelContext.save()
    }

    private func addSet(to exercise: WorkoutExercise, in workout: WorkoutSession) {
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
        workout.updatedAt = now
        try? modelContext.save()
    }

    private func deleteSet(_ set: WorkoutSet, from exercise: WorkoutExercise, in workout: WorkoutSession) {
        if workout.restSourceSetID == set.id {
            clearRest(for: workout)
        }
        exercise.sets.removeAll { $0.id == set.id }
        modelContext.delete(set)
        // Reindex: warmups first, then working
        let warmups = exercise.warmupSets
        let workings = exercise.workingSets
        for (i, s) in (warmups + workings).enumerated() { s.index = i + 1 }
        workout.updatedAt = now
        try? modelContext.save()
    }

    private func delete(exercise: WorkoutExercise, from workout: WorkoutSession) {
        if exercise.orderedSets.contains(where: { $0.id == workout.restSourceSetID }) {
            clearRest(for: workout)
        }

        if let index = workout.exercises.firstIndex(where: { $0.id == exercise.id }) {
            workout.exercises.remove(at: index)
        }

        for (index, item) in workout.orderedExercises.enumerated() {
            item.order = index
        }

        modelContext.delete(exercise)
        workout.updatedAt = now
        try? modelContext.save()
    }

    private func moveExercise(from sourceIndex: Int, to destinationIndex: Int, in workout: WorkoutSession) {
        var exercises = workout.orderedExercises
        let exercise = exercises.remove(at: sourceIndex)
        exercises.insert(exercise, at: destinationIndex)
        for (i, ex) in exercises.enumerated() {
            ex.order = i
        }
        workout.updatedAt = now
        try? modelContext.save()
    }

    private func computeTargetIndex(from startIndex: Int, offset: CGFloat, exercises: [WorkoutExercise]) -> Int {
        let spacing: CGFloat = 14
        var positions: [CGFloat] = [0]
        for i in 0..<max(0, exercises.count - 1) {
            let h = cardHeights[exercises[i].id] ?? 220
            positions.append(positions.last! + h + spacing)
        }
        guard startIndex < exercises.count else { return startIndex }
        let draggedHeight = cardHeights[exercises[startIndex].id] ?? 220
        let newCenter = positions[startIndex] + draggedHeight / 2 + offset

        var bestIndex = startIndex
        var bestDist = CGFloat.infinity
        for i in 0..<exercises.count {
            let h = cardHeights[exercises[i].id] ?? 220
            let center = positions[i] + h / 2
            let dist = abs(newCenter - center)
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }
        return bestIndex
    }

    private func cardDisplacement(for index: Int, draggingIndex: Int, targetIndex: Int, draggedHeight: CGFloat) -> CGFloat {
        guard draggingIndex >= 0, index != draggingIndex else { return 0 }
        let shift = draggedHeight + 14
        if targetIndex > draggingIndex, index > draggingIndex, index <= targetIndex {
            return -shift
        } else if targetIndex < draggingIndex, index >= targetIndex, index < draggingIndex {
            return shift
        }
        return 0
    }

    private func replaceExercise(_ exercise: WorkoutExercise, with catalogItem: ExerciseCatalogItem, in workout: WorkoutSession) {
        exercise.name = catalogItem.name
        exercise.category = catalogItem.category
        workout.updatedAt = now
        try? modelContext.save()
        exerciseToReplace = nil
    }

    private func delete(workout: WorkoutSession) {
        clearRest(for: workout)
        modelContext.delete(workout)
        try? modelContext.save()
        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }

    private func updateWeight(for set: WorkoutSet, value: String, in workout: WorkoutSession?) {
        guard let parsedValue = Double(value), parsedValue >= 0 else {
            return
        }

        let baseKg = parsedValue.convertedWeight(from: weightUnit, to: .kilogram)
        let exerciseWeightMode = set.exercise?.weightMode ?? .standard
        set.weightKg = exerciseWeightMode == .singleHand ? baseKg * 2 : baseKg
        workout?.updatedAt = now
        try? modelContext.save()
    }

    private func updateReps(for set: WorkoutSet, value: String, in workout: WorkoutSession?) {
        guard let parsedValue = Int(value), parsedValue >= 0 else {
            return
        }

        set.actualReps = parsedValue
        workout?.updatedAt = now
        try? modelContext.save()
    }

    private func updateRest(for set: WorkoutSet, value: String, in workout: WorkoutSession?) {
        guard set.canEditRecordedRest, let parsedValue = Int(value), parsedValue >= 0 else {
            return
        }

        set.recordedRestSeconds = parsedValue
        set.restAfter = TimeInterval(parsedValue)
        workout?.updatedAt = now
        try? modelContext.save()
    }

    private func stopAllTimers(for workout: WorkoutSession) {
        clearRest(for: workout)
        workout.restTargetSeconds = 0
        if workout.workoutIsRunning, let workoutTimerStartedAt = workout.workoutTimerStartedAt {
            workout.workoutElapsedOffset += max(0, now.timeIntervalSince(workoutTimerStartedAt))
        }
        workout.workoutTimerStartedAt = nil
        workout.workoutIsRunning = false
        workout.updatedAt = now
        try? modelContext.save()
    }

    private func startWorkoutTimer(for workout: WorkoutSession) {
        guard !workout.workoutIsRunning else {
            return
        }
        workout.workoutTimerStartedAt = now
        workout.workoutIsRunning = true
        workout.updatedAt = now
        try? modelContext.save()
    }

    private func handlePrimaryAction(for workout: WorkoutSession) {
        if workout.workoutIsRunning {
            completeWorkout(workout)
            withAnimation(.easeOut(duration: 0.3)) {
                summaryDisplayMode = .fullscreen
            }
        } else {
            // If the workout was previously completed, un-complete it so the timer can resume
            if workout.isCompleted {
                workout.isCompleted = false
                workout.dateEnded = nil
            }
            startWorkoutTimer(for: workout)
        }
    }

    private func dismissSummaryAndFinish() {
        summaryDisplayMode = nil
        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }

    private func primaryActionTitle(for workout: WorkoutSession) -> String {
        if workout.workoutIsRunning {
            return "结束"
        }
        return workout.workoutHasStarted ? "继续" : "开始"
    }

    private func primaryActionColor(for workout: WorkoutSession) -> Color {
        workout.workoutIsRunning ? Color(red: 1.00, green: 0.43, blue: 0.06) : Color.green
    }

    private func completeWorkout(_ workout: WorkoutSession) {
        clearRest(for: workout)
        workout.restTargetSeconds = 0
        if workout.workoutIsRunning, let workoutTimerStartedAt = workout.workoutTimerStartedAt {
            workout.workoutElapsedOffset += max(0, now.timeIntervalSince(workoutTimerStartedAt))
        }
        workout.workoutTimerStartedAt = nil
        workout.workoutIsRunning = false
        workout.isCompleted = true
        workout.dateEnded = now
        workout.updatedAt = now
        try? modelContext.save()
    }

    private func latestCompletedSet(in workout: WorkoutSession) -> WorkoutSet? {
        workout.orderedExercises
            .flatMap(\.orderedSets)
            .filter({ $0.isCompleted })
            .sorted(by: { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) })
            .first
    }

    private func startRest(for set: WorkoutSet, in workout: WorkoutSession) {
        workout.restStartTime = now
        workout.restSourceSetID = set.id
        workout.restTargetSeconds = max(0, Int(set.restAfter))
        workout.restElapsedOffset = 0
        workout.restIsPaused = false
        workout.restLastUpdatedAt = now
        workout.restActualSeconds = nil
        scheduleRestNotification(seconds: workout.restTargetSeconds)
    }

    private func clearRest(for workout: WorkoutSession) {
        workout.restStartTime = nil
        workout.restSourceSetID = nil
        workout.restElapsedOffset = 0
        workout.restIsPaused = false
        workout.restLastUpdatedAt = now
        workout.restActualSeconds = nil
        cancelRestNotification()
    }

    private func finishRest(for workout: WorkoutSession) {
        let actualSeconds = Int(workout.restElapsed(at: now))
        let targetSeconds = workout.restTargetSeconds
        workout.restActualSeconds = actualSeconds
        if let sourceSetID = workout.restSourceSetID,
           let sourceSet = workout.orderedExercises
            .flatMap(\.orderedSets)
            .first(where: { $0.id == sourceSetID }) {
            sourceSet.recordedRestSeconds = actualSeconds
            // If rest duration was adjusted, propagate the new target to subsequent uncompleted sets
            if Int(sourceSet.restAfter) != targetSeconds,
               let exercise = sourceSet.exercise {
                let exerciseSets = exercise.orderedSets
                if let idx = exerciseSets.firstIndex(where: { $0.id == sourceSetID }) {
                    for i in (idx + 1)..<exerciseSets.count {
                        let nextSet = exerciseSets[i]
                        if !nextSet.isCompleted {
                            nextSet.restAfter = TimeInterval(targetSeconds)
                        }
                    }
                }
            }
        }
        clearRest(for: workout)
        try? modelContext.save()
        provideNotificationFeedback(.success)
    }

    private func adjustRest(for workout: WorkoutSession, delta: Int) {
        workout.restTargetSeconds = max(0, workout.restTargetSeconds + delta)
        workout.restLastUpdatedAt = now
        if workout.restTargetSeconds == 0 {
            finishRest(for: workout)
        } else {
            let remaining = workout.restRemainingSeconds(at: now)
            scheduleRestNotification(seconds: remaining)
            try? modelContext.save()
            provideImpactFeedback(style: .light)
        }
    }

    private func handleRestTick(for workout: WorkoutSession) {
        guard workout.hasActiveRest else {
            lastVibrationSecond = nil
            return
        }

        let remaining = workout.restRemainingSeconds(at: now)

        if remaining == 0 {
            AudioServicesPlaySystemSound(SystemSoundID(1007))
            finishRest(for: workout)
            lastVibrationSecond = nil
            return
        }

        if remaining >= 1 && remaining <= 10 && lastVibrationSecond != remaining {
            lastVibrationSecond = remaining
            if remaining <= 3 {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func persistRestSnapshot(for workout: WorkoutSession) {
        guard workout.hasActiveRest else {
            return
        }

        if !workout.restIsPaused {
            workout.restElapsedOffset = workout.restElapsed(at: now)
            workout.restStartTime = now
        }
        workout.restLastUpdatedAt = now
        try? modelContext.save()
    }

    private func restoreRestSnapshot(for workout: WorkoutSession) {
        guard workout.hasActiveRest else {
            return
        }

        // Sync now to real time since the Timer may not have fired yet
        now = Date.now

        // If timer expired while in background, finish immediately
        let remaining = workout.restRemainingSeconds(at: now)
        if remaining <= 0 {
            finishRest(for: workout)
            return
        }

        workout.restLastUpdatedAt = now
        try? modelContext.save()
    }

    private func copyWeightRight(for set: WorkoutSet, in exercise: WorkoutExercise, workout: WorkoutSession) {
        let orderedSets = exercise.orderedSets
        guard let currentIndex = orderedSets.firstIndex(where: { $0.id == set.id }),
              currentIndex + 1 < orderedSets.count else { return }
        let nextSet = orderedSets[currentIndex + 1]
        guard !nextSet.isCompleted else { return }
        nextSet.weightKg = set.weightKg
        workout.updatedAt = now
        try? modelContext.save()
        provideImpactFeedback(style: .light)
    }

    private func copyWeightDown(for set: WorkoutSet, in exercise: WorkoutExercise, workout: WorkoutSession) {
        let orderedSets = exercise.orderedSets
        guard let currentIndex = orderedSets.firstIndex(where: { $0.id == set.id }) else { return }
        for i in (currentIndex + 1)..<orderedSets.count {
            let targetSet = orderedSets[i]
            guard !targetSet.isCompleted else { continue }
            targetSet.weightKg = set.weightKg
        }
        workout.updatedAt = now
        try? modelContext.save()
        provideImpactFeedback(style: .light)
    }

    private func copyRepsDown(for set: WorkoutSet, in exercise: WorkoutExercise, workout: WorkoutSession) {
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
        workout.updatedAt = now
        try? modelContext.save()
        provideImpactFeedback(style: .light)
    }

    private func toggleWeightMode(for exercise: WorkoutExercise) {
        exercise.weightMode = exercise.weightMode == .standard ? .singleHand : .standard
        try? modelContext.save()
    }

    private func toggleSetType(for set: WorkoutSet, in workout: WorkoutSession) {
        set.setType = set.setType == .working ? .warmup : .working
        if set.isWarmup {
            set.restAfter = min(set.restAfter, 60)
        }
        workout.updatedAt = now
        try? modelContext.save()
    }

    private func addWarmupSet(to exercise: WorkoutExercise, in workout: WorkoutSession) {
        let source = exercise.warmupSets.last
        let newSet = WorkoutSet(
            index: 0,
            targetReps: source?.targetReps ?? exercise.workingSets.first?.targetReps ?? 10,
            weightKg: source?.weightKg ?? (exercise.workingSets.first?.weightKg ?? 20) * 0.5,
            restAfter: source?.restAfter ?? 45,
            setTypeRawValue: SetType.warmup.rawValue,
            exercise: exercise
        )
        exercise.sets.append(newSet)
        // Reindex: warmup sets first, then working sets
        for (i, ws) in exercise.warmupSets.enumerated() {
            ws.index = i + 1
        }
        let warmupEnd = exercise.warmupSets.count
        for (i, ws) in exercise.workingSets.enumerated() {
            ws.index = warmupEnd + i + 1
        }
        workout.updatedAt = now
        try? modelContext.save()
    }

    private func collapsedSummaryBar(workout: WorkoutSession) -> some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.3)) {
                summaryDisplayMode = .fullscreen
            }
        }) {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("训练已完成")
                        .font(.system(size: 14, weight: .bold))
                    Text(workout.title + " · " + elapsedTimeText(for: workout))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
    }

    private func provideImpactFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func provideNotificationFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    private func scheduleRestNotification(seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["rest-timer-complete"])

        guard seconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "休息结束"
        content.body = "该开始下一组了"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: "rest-timer-complete", content: content, trigger: trigger)
        center.add(request)
    }

    private func cancelRestNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest-timer-complete"])
    }
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
    let onToggleSetType: (WorkoutSet) -> Void
    let onDeleteSet: (WorkoutSet) -> Void
    let onAddWarmupSet: () -> Void
    let onReplaceExercise: () -> Void
    let onDelete: () -> Void
    let onDragActivated: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: () -> Void
    var forceEditableRest: Bool = false

    private var weightColumnTitle: String {
        exercise.weightMode == .singleHand ? "单手重" : "重量"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                // Drag handle — gesture lives here only so ScrollView scrolls unimpeded elsewhere
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13))
                    .foregroundStyle(.quaternary)
                    .frame(width: 28, height: 36)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.3)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onChanged { value in
                                switch value {
                                case .first(true):
                                    onDragActivated()
                                case .second(true, let drag?):
                                    onDragChanged(drag.translation.height)
                                default:
                                    break
                                }
                            }
                            .onEnded { _ in onDragEnded() }
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(exercise.name)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        if exercise.weightMode == .singleHand {
                            Text("单手")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)

                    Text(exercise.progressText)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Button(action: onAddWarmupSet) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                        Text("+ 热身组")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.18))
                    .overlay(Capsule().stroke(Color.orange.opacity(0.5), lineWidth: 1))
                    .clipShape(Capsule())
                }

                Menu {
                    Button(action: onToggleWeightMode) {
                        Label(
                            exercise.weightMode == .standard ? "切换为单手重量" : "切换为总重量",
                            systemImage: exercise.weightMode == .standard ? "arrow.left.arrow.right" : "equal.circle"
                        )
                    }
                    Button(action: onReplaceExercise) {
                        Label("替换动作", systemImage: "arrow.2.squarepath")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(uiColor: .label))
                        .frame(width: 29, height: 32)
                }
            }

            // 重量模式切换
            HStack(spacing: 0) {
                ForEach(ExerciseWeightMode.allCases, id: \.self) { mode in
                    let isSelected = exercise.weightMode == mode
                    Button {
                        if !isSelected { onToggleWeightMode() }
                    } label: {
                        Text(mode.displayName)
                            .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                            .foregroundStyle(isSelected ? Color(red: 1.0, green: 0.45, blue: 0.08) : Color(red: 0.50, green: 0.53, blue: 0.58))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(isSelected ? Color(red: 1.0, green: 0.45, blue: 0.08).opacity(0.10) : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: exercise.weightMode)
                }
            }

            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    HStack(spacing: WorkoutCardLayout.columnSpacing) {
                        Text("组")
                            .frame(width: WorkoutCardLayout.setIndexWidth, alignment: .center)
                        HStack(spacing: 2) {
                            Text(weightColumnTitle)
                            if exercise.weightMode == .singleHand {
                                Text("×2")
                                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.08))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        Text("次数")
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("休息")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("状态")
                        .frame(width: WorkoutCardLayout.statusWidth, alignment: .center)
                }
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary)

                ForEach(exercise.orderedSets) { item in
                    WorkoutSetRow(
                        set: item,
                        weightUnit: weightUnit,
                        weightMode: exercise.weightMode,
                        canDelete: exercise.orderedSets.count > 1,
                        isRestActive: isRestActive,
                        restSourceSetID: restSourceSetID,
                        onToggle: { onToggleSet(item) },
                        onUpdateWeight: { value in onUpdateWeight(item, value) },
                        onUpdateReps: { value in onUpdateReps(item, value) },
                        onUpdateRest: { value in onUpdateRest(item, value) },
                        onBeginEditing: { onBeginEditingSet(item) },
                        onCopyRight: { onCopyWeightRight(item) },
                        onCopyDown: { onCopyWeightDown(item) },
                        onCopyRepsDown: { onCopyRepsDown(item) },
                        onToggleSetType: { onToggleSetType(item) },
                        onDeleteSet: { onDeleteSet(item) },
                        forceEditableRest: forceEditableRest
                    )
                }
            }

            Button(action: onAddSet) {
                HStack(spacing: 0) {
                    HStack(spacing: WorkoutCardLayout.columnSpacing) {
                        Text("\(exercise.orderedSets.count + 1)")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.tertiary)
                            .frame(width: WorkoutCardLayout.setIndexWidth, alignment: .center)

                        AddPlaceholderCell()
                        AddPlaceholderCell()
                        AddPlaceholderCell()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Circle()
                        .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .frame(width: 28, height: 28)
                        .frame(width: WorkoutCardLayout.statusWidth, alignment: .center)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Image(systemName: "menucard")
                    .font(.system(size: 16, weight: .regular))
                Text("点击增加动作备注...")
                    .font(.system(size: 13, weight: .regular))
            }
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isDragging ? Color.orange.opacity(0.3) : Color.black.opacity(0.05), lineWidth: isDragging ? 2 : 1)
        )
        .shadow(color: isDragging ? Color.black.opacity(0.18) : Color.black.opacity(0.04), radius: isDragging ? 18 : 10, y: isDragging ? 8 : 5)
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }

    private var symbolName: String {
        switch exercise.category {
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

    private var accentColor: Color {
        switch exercise.category {
        case "胸部":
            return .orange
        case "腿部":
            return .blue
        case "背部":
            return .mint
        case "肩部":
            return .gray
        case "手臂":
            return .purple
        default:
            return .secondary
        }
    }
}

struct WorkoutSetRow: View {
    let set: WorkoutSet
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
    var forceEditableRest: Bool = false

    private var weightDisplayValue: String {
        let baseKg = set.weightKg
        let displayKg = weightMode == .singleHand ? baseKg / 2 : baseKg
        return displayKg.formattedWeight(unit: weightUnit)
    }

    private var indexLabel: String {
        self.set.isWarmup ? "W" : "\(self.set.index)"
    }

    private var indexColor: Color {
        self.set.isWarmup ? .orange : Color.primary
    }

    private var rowBackground: Color {
        if isRestActive && set.id == restSourceSetID {
            return Color.orange.opacity(0.10)
        }
        return self.set.isWarmup ? Color.orange.opacity(0.04) : Color.clear
    }

    private var isToggleLocked: Bool {
        isRestActive && !set.isCompleted && set.id != restSourceSetID
    }

    // For single-hand mode, odd sets = 左, even sets = 右
    private var handLabel: String {
        self.set.index.isMultiple(of: 2) ? "右" : "左"
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: WorkoutCardLayout.columnSpacing) {
                Text(indexLabel)
                    .font(.system(size: 14, weight: set.isWarmup ? .bold : .regular))
                    .foregroundStyle(indexColor)
                    .frame(width: WorkoutCardLayout.setIndexWidth, alignment: .center)
                    .contextMenu {
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
                    }

                VStack(spacing: 1) {
                    EditableInputCell(
                        value: weightDisplayValue,
                        keyboardType: .decimalPad,
                        isEditable: true,
                        activeTextColor: Color(uiColor: .label),
                        inactiveTextColor: Color(uiColor: .label),
                        onBeginEditing: onBeginEditing,
                        onCommit: onUpdateWeight,
                        onCopyRight: onCopyRight,
                        onCopyDown: onCopyDown
                    )
                    if weightMode == .singleHand {
                        Text(handLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.08))
                    }
                }
                .frame(maxWidth: .infinity)
                EditableInputCell(
                    value: set.repsDisplay,
                    keyboardType: .numberPad,
                    isEditable: true,
                    activeTextColor: Color(uiColor: .label),
                    inactiveTextColor: Color(uiColor: .label),
                    onBeginEditing: onBeginEditing,
                    onCommit: onUpdateReps,
                    onCopyDown: onCopyRepsDown
                )
                let isRestSource = isRestActive && set.id == restSourceSetID
                EditableInputCell(
                    value: forceEditableRest
                        ? (set.recordedRestSeconds.map { "\($0)" } ?? "\(Int(set.restAfter))")
                        : (isRestSource ? "..." : set.completedRestDisplay),
                    keyboardType: .numberPad,
                    isEditable: set.canEditRecordedRest || forceEditableRest,
                    activeTextColor: Color(red: 1.0, green: 0.45, blue: 0.08),
                    inactiveTextColor: isRestSource ? Color(red: 1.0, green: 0.45, blue: 0.08) : Color(uiColor: .tertiaryLabel),
                    onBeginEditing: onBeginEditing,
                    onCommit: onUpdateRest
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onToggle) {
                Circle()
                    .fill(set.isCompleted ? Color(red: 1.0, green: 0.45, blue: 0.08) : Color.clear)
                    .background(
                        Circle()
                            .stroke(set.isCompleted ? Color.clear : Color(.systemGray3), lineWidth: 2)
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
            }
            .buttonStyle(.plain)
            .opacity(isToggleLocked ? 0.3 : 1.0)
        }
        .padding(.vertical, set.isWarmup ? 2 : 0)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .id(set.id)
    }
}

private struct EditableInputCell: View {
    let value: String
    let keyboardType: UIKeyboardType
    let isEditable: Bool
    let activeTextColor: Color
    let inactiveTextColor: Color
    let onBeginEditing: () -> Void
    let onCommit: (String) -> Void
    var onCopyRight: (() -> Void)?
    var onCopyDown: (() -> Void)?

    var body: some View {
        SelectAllTextField(
            value: value,
            keyboardType: keyboardType,
            isEditable: isEditable,
            textColor: UIColor(isEditable ? activeTextColor : inactiveTextColor),
            onBeginEditing: onBeginEditing,
            onCommit: onCommit,
            onCopyRight: onCopyRight,
            onCopyDown: onCopyDown
        )
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(Color(uiColor: .tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SelectAllTextField: UIViewRepresentable {
    let value: String
    let keyboardType: UIKeyboardType
    let isEditable: Bool
    let textColor: UIColor
    let onBeginEditing: () -> Void
    let onCommit: (String) -> Void
    var onCopyRight: (() -> Void)?
    var onCopyDown: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onBeginEditing: onBeginEditing, onCommit: onCommit)
    }

    func makeUIView(context: Context) -> HiddenCaretTextField {
        let textField = HiddenCaretTextField()
        textField.delegate = context.coordinator
        textField.textAlignment = .center
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.font = .systemFont(ofSize: 15, weight: .regular)
        textField.adjustsFontSizeToFitWidth = true
        textField.minimumFontSize = 11
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)

        let keyboard = NumericKeyboardInputView(frame: CGRect(x: 0, y: 0, width: 0, height: 280))
        keyboard.targetTextField = textField
        keyboard.onDismiss = { [weak textField] in
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
        textField.isUserInteractionEnabled = isEditable
        context.coordinator.onBeginEditing = onBeginEditing
        context.coordinator.onCommit = onCommit

        if let keyboard = context.coordinator.keyboard {
            keyboard.onCopyRight = onCopyRight
            // Commit the current typed value first so the latest input is used when copying down
            if let onCopyDown = onCopyDown {
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
        weak var keyboard: NumericKeyboardInputView?

        init(onBeginEditing: @escaping () -> Void, onCommit: @escaping (String) -> Void) {
            self.onBeginEditing = onBeginEditing
            self.onCommit = onCommit
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            onBeginEditing()
            // Select all so typing immediately replaces the existing value
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            commit(textField)
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            commit(textField)
            textField.resignFirstResponder()
            return true
        }

        @objc func textDidChange(_ textField: UITextField) {}

        func commit(_ textField: UITextField) {
            let trimmed = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            onCommit(trimmed)
        }
    }
}

private final class HiddenCaretTextField: UITextField {
    // Show a plain vertical bar cursor (no water-drop handles)
    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        []
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }
}

private struct AddPlaceholderCell: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.89, green: 0.90, blue: 0.93), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                .frame(maxWidth: .infinity)
                .frame(height: 36)

            Image(systemName: "plus")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(red: 0.67, green: 0.70, blue: 0.75))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
    }
}

private enum WorkoutCardLayout {
    static let setIndexWidth: CGFloat = 28
    static let inputCellWidth: CGFloat = 48
    static let statusWidth: CGFloat = 40
    static let columnSpacing: CGFloat = 8
}

private struct RestProgressRing: View {
    let progress: Double
    let remainingSeconds: Int
    var lineWidth: CGFloat = 6
    var symbolSize: CGFloat = 20

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.95, green: 0.96, blue: 0.97), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color(red: 1.0, green: 0.42, blue: 0.0),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            Image(systemName: remainingSeconds <= 3 ? "bell.fill" : "timer")
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .accessibilityHidden(true)
    }
}

private struct RestAdjustButton: View {
    let symbol: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(uiColor: .label))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct WorkoutSummaryOverlay: View {
    let workout: WorkoutSession
    let weightUnit: WeightUnit
    let onCollapse: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)

                Text("训练完成")
                    .font(.system(size: 28, weight: .bold))

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
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
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
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

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
                                .background(selectedCategory == cat ? Color.orange : Color(uiColor: .secondarySystemFill))
                                .foregroundStyle(selectedCategory == cat ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                List(filteredExercises) { item in
                    Button {
                        replace(with: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.primary)
                            Text(item.targetMuscle)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
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

#Preview {
    CurrentWorkoutPreviewHost()
        .modelContainer(PreviewModelContainer.shared)
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
