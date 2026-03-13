import SwiftUI
import SwiftData

struct HistoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [WorkoutSession]

    init(sessionID: UUID) {
        _sessions = Query(
            filter: #Predicate<WorkoutSession> { session in
                session.id == sessionID
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if let detail = sessions.first {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        topBar
                        titleBlock(detail)
                        summaryGrid(detail)
                        exerciseSection(detail)
                        chartSection(detail)
                        noteSection(detail)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }

                bottomButton
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                    .background(Color.white)
            } else {
                Text("未找到训练详情")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(.systemGray6))
        .navigationBarHidden(true)
    }

    private var topBar: some View {
        ZStack {
            Text("训练详情")
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

                Button(action: {}) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func titleBlock(_ detail: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(detail.dateStarted.formatted(date: .complete, time: .omitted), systemImage: "calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text(detail.title)
                .font(.system(size: 28, weight: .bold))
        }
    }

    private func summaryGrid(_ detail: WorkoutSession) -> some View {
        let metrics = [
            DetailMetric(title: "总用时", value: durationText(for: detail), icon: "clock"),
            DetailMetric(title: "总重量", value: volumeText(detail.totalVolumeKg), icon: "scalemass"),
            DetailMetric(title: "总组数", value: "\(detail.totalSetCount) 组", icon: "flame"),
            DetailMetric(title: "强度", value: detail.totalVolumeKg > 4_000 ? "高强度" : "标准", icon: "waveform.path.ecg")
        ]

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            ForEach(metrics) { metric in
                DetailMetricCard(metric: metric)
            }
        }
    }

    private func exerciseSection(_ detail: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("训练动作", systemImage: "figure.strengthtraining.traditional")
                    .font(.system(size: 17, weight: .bold))

                Spacer()

                Text("\(detail.orderedExercises.count) 个动作")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(detail.orderedExercises) { exercise in
                    ExerciseGroupCard(exercise: exercise)
                }
            }
        }
    }

    private func chartSection(_ detail: WorkoutSession) -> some View {
        let maxVolume = max(detail.orderedExercises.map(\.totalVolumeKg).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 12) {
            Label("卷量分布 (kg)", systemImage: "chart.bar.xaxis")
                .font(.system(size: 17, weight: .bold))

            Text("每种动作的总重量与训练负载")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(alignment: .bottom, spacing: 26) {
                ForEach(detail.orderedExercises) { item in
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.systemGray6))
                                .frame(width: 44, height: 170)

                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 0.22, green: 0.33, blue: 0.40))
                                .frame(width: 44, height: max(18, 170 * item.totalVolumeKg / maxVolume))
                        }

                        Text(item.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 8)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    private func noteSection(_ detail: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("训练笔记", systemImage: "text.bubble")
                .font(.system(size: 17, weight: .bold))

            Text(detail.notes.isEmpty ? "本次训练没有记录笔记。" : detail.notes)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    private var bottomButton: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                Text("以此为模板开始训练")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func durationText(for detail: WorkoutSession) -> String {
        let interval = (detail.dateEnded ?? detail.dateStarted).timeIntervalSince(detail.dateStarted)
        return "\(max(1, Int(interval / 60))) 分钟"
    }

    private func volumeText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) kg"
    }
}

private struct DetailMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
}

private struct DetailMetricCard: View {
    let metric: DetailMetric

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: metric.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(metric.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(metric.value)
                    .font(.system(size: 20, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ExerciseGroupCard: View {
    let exercise: WorkoutExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(exercise.name, systemImage: "link")
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                Text(exercise.category)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                HStack {
                    Text("组号")
                    Spacer()
                    Text("重量 (kg)")
                    Spacer()
                    Text("次数")
                    Spacer()
                    Text("完成时间")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                ForEach(exercise.orderedSets) { set in
                    HStack {
                        Text("\(set.index)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(set.weightDisplay)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(set.repsDisplay)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(timeText(set.completedAt))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(set.index.isMultiple(of: 2) ? Color(.systemGray6).opacity(0.45) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private func timeText(_ date: Date?) -> String {
        guard let date else {
            return "--:--"
        }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

#Preview {
    NavigationStack {
        HistoryDetailView(sessionID: UUID())
    }
}
