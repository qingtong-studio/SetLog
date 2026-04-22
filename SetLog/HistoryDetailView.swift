import SwiftUI
import SwiftData

struct HistoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var preferences: [AppPreferences]
    @Query private var sessions: [WorkoutSession]
    let onStartFromHistory: (WorkoutSession) -> Void
    let onEdit: (UUID) -> Void

    init(sessionID: UUID,
         onStartFromHistory: @escaping (WorkoutSession) -> Void = { _ in },
         onEdit: @escaping (UUID) -> Void = { _ in }) {
        self.onStartFromHistory = onStartFromHistory
        self.onEdit = onEdit
        _sessions = Query(
            filter: #Predicate<WorkoutSession> { session in
                session.id == sessionID
            }
        )
    }

    private var weightUnit: WeightUnit {
        preferences.first?.weightUnit ?? .kilogram
    }

    var body: some View {
        VStack(spacing: 0) {
            if let detail = sessions.first {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        topBar(detail)
                        summaryCards(detail)
                        exerciseSection(detail)
                        chartSection(detail)
                        noteSection(detail)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }

                bottomButton(detail)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                    .background(AppTheme.bgCard)
            } else {
                Text("未找到训练详情")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppTheme.bgPage)
        .navigationBarHidden(true)
    }

    // MARK: Top Bar — back arrow + title + date/duration

    private func topBar(_ detail: WorkoutSession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.fg1)
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(detail.title)
                    .font(.system(size: 20, weight: .bold))

                HStack(spacing: 4) {
                    Text(detail.dateStarted.formatted(date: .abbreviated, time: .omitted))
                    Text("·")
                    Text(durationText(for: detail))
                }
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.fg2)
            }

            Spacer()

            Button(action: { onEdit(detail.id) }) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.fg1)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppTheme.fillMedium, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: 3-column stats: duration / total sets / total volume

    private func summaryCards(_ detail: WorkoutSession) -> some View {
        HStack(spacing: 10) {
            DetailStatCard(title: "时长", value: durationText(for: detail))
            DetailStatCard(title: "总组数", value: "\(detail.totalSetCount)组")
            DetailStatCard(title: "总容量", value: volumeText(detail.totalVolumeKg))
        }
    }

    // MARK: Exercise Section

    private func exerciseSection(_ detail: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("训练动作", systemImage: "figure.strengthtraining.traditional")
                    .font(.system(size: 17, weight: .bold))

                Spacer()

                Text("\(detail.orderedExercises.count) 个动作")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.fg2)
            }

            VStack(spacing: 12) {
                ForEach(detail.orderedExercises) { exercise in
                    ExerciseGroupCard(exercise: exercise, weightUnit: weightUnit)
                }
            }
        }
    }

    // MARK: Chart Section

    private func chartSection(_ detail: WorkoutSession) -> some View {
        let maxVolume = max(detail.orderedExercises.map(\.totalVolumeKg).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 12) {
            Label("卷量分布 (\(weightUnit.displaySymbol.lowercased()))", systemImage: "chart.bar.xaxis")
                .font(.system(size: 17, weight: .bold))

            Text("每种动作的总重量与训练负载")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.fg2)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(detail.orderedExercises) { item in
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppTheme.fillMedium)
                                .frame(width: 44, height: 170)

                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppTheme.fg2)
                                .frame(width: 44, height: max(18, 170 * item.totalVolumeKg / maxVolume))
                        }

                        Text(item.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.fg2)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 8)
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    // MARK: Note Section

    private func noteSection(_ detail: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("训练笔记", systemImage: "text.bubble")
                .font(.system(size: 17, weight: .bold))

            Text(detail.notes.isEmpty ? "本次训练没有记录笔记。" : detail.notes)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.fg2)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.fillMedium)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    // MARK: Bottom Button

    private func bottomButton(_ detail: WorkoutSession) -> some View {
        Button(action: { onStartFromHistory(detail) }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                Text("复制为新训练")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppTheme.ctaFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: Helpers

    private func durationText(for detail: WorkoutSession) -> String {
        let interval = (detail.dateEnded ?? detail.dateStarted).timeIntervalSince(detail.dateStarted)
        return "\(max(1, Int(interval / 60))) 分钟"
    }

    private func volumeText(_ value: Double) -> String {
        value.formattedVolume(unit: weightUnit)
    }
}

// MARK: - Detail Stat Card (3-column horizontal)

private struct DetailStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.fg2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }
}

// MARK: - Exercise Group Card

private struct ExerciseGroupCard: View {
    let exercise: WorkoutExercise
    let weightUnit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(exercise.name, systemImage: "link")
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                Text(exercise.category)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.fg2)
            }

            VStack(spacing: 0) {
                // Table header
                HStack {
                    Text("组号")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 2) {
                        Text(exercise.weightMode == .singleHand ? "单边" : "重量")
                        Text("(\(weightUnit.displaySymbol.lowercased()))")
                        if exercise.weightMode == .singleHand {
                            Text("×2")
                                .foregroundStyle(AppTheme.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    Text("次数")
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("休息时间")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.fg2)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                // Table rows
                let workingSetIDs = exercise.workingSets.map(\.id)
                ForEach(exercise.orderedSets) { set in
                    let displayLabel = set.isWarmup ? "W" : "\((workingSetIDs.firstIndex(of: set.id) ?? -1) + 1)"
                    HStack {
                        Text(displayLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(set.weightDisplay(unit: weightUnit))
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(set.repsDisplay)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(restText(set))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(set.index.isMultiple(of: 2)
                                ? AppTheme.fillMedium.opacity(0.45)
                                : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    private func restText(_ set: WorkoutSet) -> String {
        guard set.isCompleted, let seconds = set.recordedRestSeconds else { return "-" }
        return "\(seconds)s"
    }
}

#Preview {
    NavigationStack {
        HistoryDetailView(sessionID: UUID())
    }
    .modelContainer(PreviewModelContainer.shared)
}
