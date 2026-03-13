import SwiftUI
import SwiftData

struct HistoryView: View {
    @State private var searchText = ""
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: [SortDescriptor(\WorkoutSession.dateStarted, order: .reverse)]
    ) private var sessions: [WorkoutSession]

    let onOpenDetail: (UUID) -> Void

    init(onOpenDetail: @escaping (UUID) -> Void = { _ in }) {
        self.onOpenDetail = onOpenDetail
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                topBar
                searchBar
                historySectionList
                footerText
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGray6))
        .navigationBarHidden(true)
    }

    private var filteredSessions: [WorkoutSession] {
        guard !searchText.isEmpty else {
            return sessions
        }

        return sessions.filter { session in
            session.title.localizedCaseInsensitiveContains(searchText) ||
            session.orderedExercises.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) })
        }
    }

    private var groupedSessions: [(title: String, sessions: [WorkoutSession])] {
        let grouped = Dictionary(grouping: filteredSessions) { session in
            let components = Calendar.current.dateComponents([.year, .month], from: session.dateStarted)
            return "\(components.year ?? 0)年\(components.month ?? 0)月"
        }

        return grouped
            .map { (title: $0.key, sessions: $0.value.sorted(by: { $0.dateStarted > $1.dateStarted })) }
            .sorted { lhs, rhs in
                lhs.sessions.first?.dateStarted ?? .distantPast > rhs.sessions.first?.dateStarted ?? .distantPast
            }
    }

    private var topBar: some View {
        ZStack {
            Text("历史记录")
                .font(.system(size: 18, weight: .semibold))

            HStack {
                Spacer()
                Button(action: {}) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("搜索训练记录...", text: $searchText)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color(.systemGray5).opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button(action: {}) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 42, height: 42)
                    .background(Color(.systemGray5).opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var historySectionList: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(groupedSessions, id: \.title) { section in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(section.title)
                            .font(.system(size: 18, weight: .bold))

                        Spacer()

                        HStack(spacing: 10) {
                            Label(volumeText(totalVolume(for: section.sessions)), systemImage: "waveform.path.ecg")
                            Label("\(section.sessions.count) 次训练", systemImage: "xmark.circle")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        ForEach(section.sessions) { item in
                            Button(action: {
                                onOpenDetail(item.id)
                            }) {
                                HistoryRecordCard(session: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var footerText: some View {
        Text(filteredSessions.isEmpty ? "暂无训练记录" : "已加载全部历史数据")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    private func totalVolume(for sessions: [WorkoutSession]) -> Double {
        sessions.reduce(0) { $0 + $1.totalVolumeKg }
    }

    private func volumeText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) kg"
    }
}

private struct HistoryRecordCard: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(session.title)
                        .font(.system(size: 17, weight: .bold))

                    if session.totalVolumeKg > 4_000 {
                        Text("强力")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(red: 0.73, green: 0.42, blue: 0.08))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 4) {
                    Text(session.dateStarted.formatted(date: .abbreviated, time: .omitted))
                    Text("•")
                    Text(durationText)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.totalVolumeKg.formatted(.number.precision(.fractionLength(0)))) kg")
                    .font(.system(size: 19, weight: .bold))

                Text("\(session.orderedExercises.count) 个动作")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
    }

    private var durationText: String {
        let interval = (session.dateEnded ?? session.dateStarted).timeIntervalSince(session.dateStarted)
        let minutes = max(1, Int(interval / 60))
        return "\(minutes) min"
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
