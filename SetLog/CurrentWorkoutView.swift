import Combine
import SwiftData
import SwiftUI
import UIKit

struct CurrentWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var preferences: [AppPreferences]
    @State private var isPresentingAddExercise = false
    @State private var now = Date.now
    @State private var focusedSetRowID: UUID?

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
                        VStack(spacing: 14) {
                            ForEach(workout.orderedExercises) { exercise in
                                ExerciseEditorCard(
                                    exercise: exercise,
                                    weightUnit: weightUnit,
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
                                    onAddSet: {
                                        addSet(to: exercise, in: workout)
                                    },
                                    onUpdateWeightMode: { mode in
                                        exercise.weightMode = mode
                                        workout.updatedAt = now
                                        try? modelContext.save()
                                    },
                                    onDelete: {
                                        delete(exercise: exercise, from: workout)
                                    }
                                )
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
                .background(Color(.systemGray6))
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
            }

            if workout.hasActiveRest {
                collapsedRestCard(workout: workout)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }

        }
        .animation(.easeOut(duration: 0.24), value: workout.hasActiveRest)
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            }
        }
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
                    .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.13))
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
                    .foregroundStyle(Color(red: 0.08, green: 0.09, blue: 0.12))

                Text("进度: \(workout.completedSetCount)/\(max(workout.totalSetCount, 1)) 组  体积: \(volumeText(workout.totalVolumeKg))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.23, green: 0.26, blue: 0.32))
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
                        .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.13))
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
            .background(Color(red: 0.97, green: 0.98, blue: 0.99))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(red: 0.86, green: 0.88, blue: 0.91), lineWidth: 1)
            )
            .padding(.top, 22)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(.white)
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
            .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.36))
            .frame(width: 40, height: 15)
            .frame(width: 50, height: 17)
            .background(Color.white)
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
            .foregroundStyle(Color(red: 0.18, green: 0.19, blue: 0.22))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(red: 0.82, green: 0.83, blue: 0.86), lineWidth: 1.2)
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
                    .font(.system(size: remainingSeconds > 99 ? 14 : 18, weight: .black, design: .rounded))
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
                        .fill(Color(red: 0.87, green: 0.88, blue: 0.91))
                        .frame(width: 1, height: 18)

                    RestAdjustButton(symbol: "-10s", accessibilityLabel: "减少十秒") {
                        adjustRest(for: workout, delta: -10)
                    }
                }
                .frame(width: 103, height: 44)
                .background(Color(red: 0.95, green: 0.95, blue: 0.97))
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
        .background(.white)
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
        let toggledSetID = set.id
        set.isCompleted.toggle()
        set.actualReps = set.actualReps ?? set.targetReps
        set.completedAt = set.isCompleted ? now : nil
        workout.updatedAt = now

        if set.isCompleted {
            set.recordedRestSeconds = nil
            if !workout.workoutIsRunning {
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

        set.weightKg = parsedValue.convertedWeight(from: weightUnit, to: .kilogram)
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
            if let onFinish {
                onFinish()
            } else {
                dismiss()
            }
        } else {
            startWorkoutTimer(for: workout)
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
    }

    private func clearRest(for workout: WorkoutSession) {
        workout.restStartTime = nil
        workout.restSourceSetID = nil
        workout.restElapsedOffset = 0
        workout.restIsPaused = false
        workout.restLastUpdatedAt = now
        workout.restActualSeconds = nil
    }

    private func finishRest(for workout: WorkoutSession) {
        let actualSeconds = Int(workout.restElapsed(at: now))
        workout.restActualSeconds = actualSeconds
        if let sourceSetID = workout.restSourceSetID,
           let sourceSet = workout.orderedExercises
            .flatMap(\.orderedSets)
            .first(where: { $0.id == sourceSetID }) {
            sourceSet.recordedRestSeconds = actualSeconds
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
            try? modelContext.save()
            provideImpactFeedback(style: .light)
        }
    }

    private func handleRestTick(for workout: WorkoutSession) {
        guard workout.hasActiveRest else {
            return
        }

        if workout.restRemainingSeconds(at: now) == 0 {
            finishRest(for: workout)
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

        if !workout.restIsPaused {
            workout.restStartTime = now
        }
        workout.restLastUpdatedAt = now
        try? modelContext.save()
    }

    private func provideImpactFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func provideNotificationFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

private struct ExerciseEditorCard: View {
    let exercise: WorkoutExercise
    let weightUnit: WeightUnit
    let onToggleSet: (WorkoutSet) -> Void
    let onUpdateWeight: (WorkoutSet, String) -> Void
    let onUpdateReps: (WorkoutSet, String) -> Void
    let onUpdateRest: (WorkoutSet, String) -> Void
    let onBeginEditingSet: (WorkoutSet) -> Void
    let onAddSet: () -> Void
    let onDelete: () -> Void
    let onUpdateWeightMode: (WeightMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.16))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)

                    Text(exercise.progressText)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(red: 0.29, green: 0.32, blue: 0.38))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.13))
                        .frame(width: 29, height: 32)
                }
            }

            // 重量模式切换
            HStack(spacing: 0) {
                ForEach(WeightMode.allCases, id: \.self) { mode in
                    let isSelected = exercise.weightMode == mode
                    Button {
                        onUpdateWeightMode(mode)
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
                            Text(exercise.weightMode == .singleHand ? "单手重" : "重量")
                            if exercise.weightMode == .singleHand {
                                Text("×2")
                                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.08))
                            }
                        }
                        .frame(width: WorkoutCardLayout.inputCellWidth + (exercise.weightMode == .singleHand ? 14 : 0), alignment: .center)
                        Text("次数")
                            .frame(width: WorkoutCardLayout.inputCellWidth, alignment: .center)
                        Text("休息")
                            .frame(width: WorkoutCardLayout.inputCellWidth, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("状态")
                        .frame(width: WorkoutCardLayout.statusWidth, alignment: .center)
                }
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Color(red: 0.29, green: 0.32, blue: 0.38))

                ForEach(exercise.orderedSets) { item in
                    WorkoutSetRow(set: item, weightUnit: weightUnit, weightMode: exercise.weightMode) {
                        onToggleSet(item)
                    } onUpdateWeight: { value in
                        onUpdateWeight(item, value)
                    } onUpdateReps: { value in
                        onUpdateReps(item, value)
                    } onUpdateRest: { value in
                        onUpdateRest(item, value)
                    } onBeginEditing: {
                        onBeginEditingSet(item)
                    }
                }
            }

            Button(action: onAddSet) {
                HStack(spacing: 0) {
                    HStack(spacing: WorkoutCardLayout.columnSpacing) {
                        Text("\(exercise.orderedSets.count + 1)")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(red: 0.72, green: 0.74, blue: 0.78))
                            .frame(width: WorkoutCardLayout.setIndexWidth, alignment: .center)

                        AddPlaceholderCell()
                        AddPlaceholderCell()
                        AddPlaceholderCell()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Circle()
                        .stroke(Color(red: 0.89, green: 0.90, blue: 0.93), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
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
            .foregroundStyle(Color(red: 0.57, green: 0.60, blue: 0.66))
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
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

private struct WorkoutSetRow: View {
    let set: WorkoutSet
    let weightUnit: WeightUnit
    let weightMode: WeightMode
    let onToggle: () -> Void
    let onUpdateWeight: (String) -> Void
    let onUpdateReps: (String) -> Void
    let onUpdateRest: (String) -> Void
    let onBeginEditing: () -> Void

    // For single-hand mode, odd sets = 左, even sets = 右
    private var handLabel: String {
        set.index.isMultiple(of: 2) ? "右" : "左"
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: WorkoutCardLayout.columnSpacing) {
                Text("\(set.index)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(red: 0.14, green: 0.15, blue: 0.18))
                    .frame(width: WorkoutCardLayout.setIndexWidth, alignment: .center)

                VStack(spacing: 1) {
                    EditableInputCell(
                        value: set.weightDisplay(unit: weightUnit),
                        keyboardType: .decimalPad,
                        isEditable: true,
                        activeTextColor: Color(red: 0.14, green: 0.15, blue: 0.18),
                        inactiveTextColor: Color(red: 0.14, green: 0.15, blue: 0.18),
                        onBeginEditing: onBeginEditing,
                        onCommit: onUpdateWeight
                    )
                    if weightMode == .singleHand {
                        Text(handLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.08))
                    }
                }
                .frame(width: WorkoutCardLayout.inputCellWidth)
                EditableInputCell(
                    value: set.repsDisplay,
                    keyboardType: .numberPad,
                    isEditable: true,
                    activeTextColor: Color(red: 0.14, green: 0.15, blue: 0.18),
                    inactiveTextColor: Color(red: 0.14, green: 0.15, blue: 0.18),
                    onBeginEditing: onBeginEditing,
                    onCommit: onUpdateReps
                )
                EditableInputCell(
                    value: set.completedRestDisplay,
                    keyboardType: .numberPad,
                    isEditable: set.canEditRecordedRest,
                    activeTextColor: Color(red: 1.0, green: 0.45, blue: 0.08),
                    inactiveTextColor: Color(red: 0.67, green: 0.70, blue: 0.75),
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
                            .stroke(set.isCompleted ? Color.clear : Color(red: 0.84, green: 0.86, blue: 0.89), lineWidth: 2)
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
        }
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

    var body: some View {
        SelectAllTextField(
            value: value,
            keyboardType: keyboardType,
            isEditable: isEditable,
            textColor: UIColor(isEditable ? activeTextColor : inactiveTextColor),
            onBeginEditing: onBeginEditing,
            onCommit: onCommit
        )
            .frame(width: WorkoutCardLayout.inputCellWidth, height: 36, alignment: .center)
            .background(Color(red: 0.97, green: 0.97, blue: 0.98))
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

    func makeCoordinator() -> Coordinator {
        Coordinator(onBeginEditing: onBeginEditing, onCommit: onCommit)
    }

    func makeUIView(context: Context) -> HiddenCaretTextField {
        let textField = HiddenCaretTextField()
        textField.delegate = context.coordinator
        textField.keyboardType = keyboardType
        textField.textAlignment = .center
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.font = .systemFont(ofSize: 15, weight: .regular)
        textField.adjustsFontSizeToFitWidth = true
        textField.minimumFontSize = 11
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ textField: HiddenCaretTextField, context: Context) {
        if textField.text != value, !textField.isFirstResponder {
            textField.text = value
        }
        textField.keyboardType = keyboardType
        textField.textColor = textColor
        textField.isUserInteractionEnabled = isEditable
        context.coordinator.onBeginEditing = onBeginEditing
        context.coordinator.onCommit = onCommit
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var onBeginEditing: () -> Void
        var onCommit: (String) -> Void

        init(onBeginEditing: @escaping () -> Void, onCommit: @escaping (String) -> Void) {
            self.onBeginEditing = onBeginEditing
            self.onCommit = onCommit
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            onBeginEditing()
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

        private func commit(_ textField: UITextField) {
            let trimmedValue = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedValue.isEmpty else {
                return
            }
            onCommit(trimmedValue)
        }
    }
}

private final class HiddenCaretTextField: UITextField {
    override func caretRect(for position: UITextPosition) -> CGRect {
        .zero
    }
}

private struct AddPlaceholderCell: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.89, green: 0.90, blue: 0.93), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                .frame(width: WorkoutCardLayout.inputCellWidth, height: 36)

            Image(systemName: "plus")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(red: 0.67, green: 0.70, blue: 0.75))
        }
        .frame(width: WorkoutCardLayout.inputCellWidth, height: 36)
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
                .foregroundStyle(Color(red: 0.07, green: 0.09, blue: 0.13))
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
                .foregroundStyle(Color(red: 0.07, green: 0.09, blue: 0.13))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
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
