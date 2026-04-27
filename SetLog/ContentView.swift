//
//  ContentView.swift
//  SetLog
//
//  Created by toka on 2026/03/13.
//

import SwiftData
import SwiftUI
import Combine

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: AppTab = .train
    @State private var trainPath: [TrainRoute] = []
    @State private var historyPath: [HistoryRoute] = []
    @State private var profilePath = NavigationPath()
    @State private var activeWorkoutSession: WorkoutSession?

    var body: some View {
        TabView(selection: $selectedTab) {
            trainStack
                .tabItem {
                    Label(AppTab.train.title, systemImage: AppTab.train.icon)
                }
                .tag(AppTab.train)

            historyStack
                .tabItem {
                    Label(AppTab.history.title, systemImage: AppTab.history.icon)
                }
                .tag(AppTab.history)

            profileStack
                .tabItem {
                    Label(AppTab.profile.title, systemImage: AppTab.profile.icon)
                }
                .tag(AppTab.profile)
        }
        .background(AppTheme.bgPage)
        .tint(AppTheme.orange)
    }

    private var trainStack: some View {
        NavigationStack(path: $trainPath) {
            HomeDashboardView(
                onQuickStart: {
                    let session = createQuickWorkout()
                    activeWorkoutSession = session
                },
                onOpenSession: { session in
                    activeWorkoutSession = session
                },
                onOpenTemplates: {
                    trainPath.append(.templates)
                },
                onStartTemplate: { template in
                    let session = createWorkout(from: template)
                    activeWorkoutSession = session
                }
            )
            .navigationDestination(for: TrainRoute.self) { route in
                switch route {
                case .templates:
                    WorkoutTemplatesView { template in
                        let session = createWorkout(from: template)
                        activeWorkoutSession = session
                    }
                }
            }
        }
        .fullScreenCover(isPresented: activeWorkoutPresentedBinding) {
            if let session = activeWorkoutSession {
                CurrentWorkoutView(workout: session) {
                    activeWorkoutSession = nil
                }
            }
        }
    }

    private var historyStack: some View {
        NavigationStack(path: $historyPath) {
            HistoryView(
                onOpenDetail: { sessionID in
                    historyPath.append(.detail(sessionID))
                },
                onAddRecord: { date in
                    historyPath.append(.addRecord(date))
                }
            )
            .navigationDestination(for: HistoryRoute.self) { route in
                switch route {
                case .detail(let sessionID):
                    HistoryDetailView(sessionID: sessionID) { sourceSession in
                        selectedTab = .train
                        let session = createWorkout(from: sourceSession)
                        activeWorkoutSession = session
                    } onEdit: { sessionID in
                        historyPath.append(.editRecord(sessionID))
                    }
                case .editRecord(let sessionID):
                    EditRecordDestination(sessionID: sessionID)
                case .addRecord(let date):
                    AddRecordDestination(date: date)
                }
            }
        }
    }

    private var profileStack: some View {
        NavigationStack(path: $profilePath) {
            ProfileView()
        }
    }

    private var activeWorkoutPresentedBinding: Binding<Bool> {
        Binding(
            get: { activeWorkoutSession != nil },
            set: { isPresented in
                if !isPresented {
                    activeWorkoutSession = nil
                }
            }
        )
    }

    private func createQuickWorkout() -> WorkoutSession {
        let session = WorkoutSession(title: "自由训练", dateStarted: .now, isCompleted: false)
        modelContext.insert(session)
        try? modelContext.save()
        return session
    }

    private func lastUserWeight(forExerciseNamed name: String) -> Double? {
        let descriptor = FetchDescriptor<WorkoutExercise>(
            predicate: #Predicate { $0.name == name }
        )
        guard let exercises = try? modelContext.fetch(descriptor) else { return nil }

        let candidates = exercises
            .flatMap { $0.sets ?? [] }
            .filter { $0.weightKg > 0 }

        let mostRecent = candidates.max { lhs, rhs in
            let lhsDate = lhs.completedAt ?? lhs.exercise?.session?.dateStarted ?? .distantPast
            let rhsDate = rhs.completedAt ?? rhs.exercise?.session?.dateStarted ?? .distantPast
            return lhsDate < rhsDate
        }
        return mostRecent?.weightKg
    }

    private func createWorkout(from template: WorkoutTemplate) -> WorkoutSession {
        let session = WorkoutSession(
            title: template.title,
            dateStarted: .now,
            templateName: template.title,
            isCompleted: false
        )
        modelContext.insert(session)

        for (exerciseOrder, templateExercise) in (template.exercises ?? [])
            .sorted(by: { $0.order < $1.order })
            .enumerated() {
            let workoutExercise = WorkoutExercise(
                name: templateExercise.name,
                category: templateExercise.category,
                order: exerciseOrder,
                session: session
            )

            let suggestedWeight = lastUserWeight(forExerciseNamed: templateExercise.name)
                ?? templateExercise.defaultWeightKg

            workoutExercise.sets = (1...max(1, templateExercise.defaultSets)).map { index in
                WorkoutSet(
                    index: index,
                    targetReps: templateExercise.defaultReps,
                    actualReps: nil,
                    weightKg: suggestedWeight,
                    exercise: workoutExercise
                )
            }

            if session.exercises == nil { session.exercises = [] }
            session.exercises?.append(workoutExercise)
        }

        try? modelContext.save()
        return session
    }

    private func createWorkout(from sourceSession: WorkoutSession) -> WorkoutSession {
        let session = WorkoutSession(
            title: sourceSession.title,
            dateStarted: .now,
            templateName: sourceSession.templateName,
            isCompleted: false
        )
        modelContext.insert(session)

        for (exerciseOrder, sourceExercise) in sourceSession.orderedExercises.enumerated() {
            let workoutExercise = WorkoutExercise(
                name: sourceExercise.name,
                category: sourceExercise.category,
                order: exerciseOrder,
                session: session
            )

            workoutExercise.sets = sourceExercise.orderedSets.enumerated().map { index, sourceSet in
                WorkoutSet(
                    index: index + 1,
                    targetReps: sourceSet.targetReps ?? sourceSet.actualReps,
                    actualReps: nil,
                    weightKg: sourceSet.weightKg,
                    restAfter: sourceSet.restAfter,
                    exercise: workoutExercise
                )
            }

            if session.exercises == nil { session.exercises = [] }
            session.exercises?.append(workoutExercise)
        }

        try? modelContext.save()
        return session
    }
}

private struct HomeDashboardView: View {
    @Query private var preferences: [AppPreferences]
    @Query(
        filter: #Predicate<WorkoutSession> { session in
            session.isCompleted == false
        },
        sort: [SortDescriptor(\WorkoutSession.dateStarted, order: .reverse)]
    ) private var unfinishedSessions: [WorkoutSession]
    @Query(sort: [SortDescriptor(\WorkoutSession.dateStarted, order: .reverse)]) private var allSessions: [WorkoutSession]
    @Query(sort: [SortDescriptor(\WorkoutTemplate.createdAt, order: .reverse)]) private var workoutTemplates: [WorkoutTemplate]
    @State private var now = Date.now

    let onQuickStart: () -> Void
    let onOpenSession: (WorkoutSession) -> Void
    let onOpenTemplates: () -> Void
    let onStartTemplate: (WorkoutTemplate) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                topBar
                overviewSection
                if let activeSession = activeSessions.first {
                    activeWorkoutCard(session: activeSession)
                }
                if !completedTodaySessions.isEmpty {
                    completedWorkoutSection
                }
                if activeSessions.isEmpty {
                    quickStartButton
                }
                templateHeader
                templateList
                noRecordCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(AppTheme.bgPage)
        .navigationBarHidden(true)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { value in
            now = value
        }
    }

    private var weightUnit: WeightUnit {
        preferences.first?.weightUnit ?? .kilogram
    }

    private var activeSessions: [WorkoutSession] {
        unfinishedSessions.filter { $0.workoutHasStarted }
    }

    private var topBar: some View {
        HStack {
            Text("今日训练")
                .font(.system(size: 18, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var overviewSection: some View {
        HStack(alignment: .top, spacing: 12) {
            calendarCard
            statusCard
        }
    }

    private var calendarCard: some View {
        let currentMonth = calendarMonth
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(currentMonth.title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.fg2)
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.fg2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }

                ForEach(currentMonth.days) { day in
                    Text(day.label)
                        .font(.system(size: 12, weight: day.isToday ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .frame(height: 18)
                        .background(day.isToday ? AppTheme.fg1 : Color.clear)
                        .foregroundStyle(day.isToday ? Color.white : (day.isInCurrentMonth ? AppTheme.fg1 : .clear))
                        .clipShape(Circle())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var statusCard: some View {
        let summary = todaysSummary

        return VStack(alignment: .leading, spacing: 14) {
            StatusRow(color: AppTheme.orange, title: "总时长", value: summary.durationText, symbol: "clock")
            StatusRow(color: AppTheme.confirm, title: "已完成", value: "\(summary.completedSets)", symbol: "checkmark.circle")
            StatusRow(color: AppTheme.fg2, title: "总组数", value: "\(summary.totalSets)", symbol: "dumbbell")
            StatusRow(color: AppTheme.fg3, title: "总容量", value: summary.volumeText(unit: weightUnit), symbol: "scalemass")
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    private var quickStartButton: some View {
        Button(action: onQuickStart) {
            HStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 15, weight: .semibold))
                Text("开启一场自由训练")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(AppTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    .foregroundStyle(AppTheme.fg3)
            )
        }
    }

    private func activeWorkoutCard(session: WorkoutSession) -> some View {
        Button(action: {
            onOpenSession(session)
        }) {
            workoutStatusCardContent(
                session: session,
                statusTitle: "有正在进行的训练",
                accentColor: AppTheme.orange,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
    }

    private func completedWorkoutCard(session: WorkoutSession) -> some View {
        Button(action: {
            onOpenSession(session)
        }) {
            workoutStatusCardContent(
                session: session,
                statusTitle: "已完成",
                accentColor: AppTheme.confirm,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
    }

    private var completedWorkoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("已完成")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.secondary)

            ForEach(completedTodaySessions) { session in
                completedWorkoutCard(session: session)
            }
        }
    }

    private var templateHeader: some View {
        HStack {
            Text("训练模板")
                .font(.system(size: 24, weight: .bold))
            Spacer()
            Button("查看更多", action: onOpenTemplates)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }

    private var templateList: some View {
        Group {
            if workoutTemplates.isEmpty {
                noTemplateCard
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(workoutTemplates.prefix(4)) { template in
                        TrainingTemplateCard(
                            template: template,
                            lastUsedText: lastUsedText(for: template),
                            tags: templateTags(for: template),
                            onStart: onStartTemplate
                        )
                    }
                }
            }
        }
    }

    private var noTemplateCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
            Text("暂无模板")
                .font(.system(size: 14, weight: .semibold))
            Text("先创建一条模板，训练会更快开始。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    private var noRecordCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)

            Text("没有灵感?")
                .font(.system(size: 16, weight: .semibold))

            Text("从浏览热门模板开始，或者复制你上一次的训练记录")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    private var todaysSessions: [WorkoutSession] {
        allSessions.filter { Calendar.current.isDateInToday($0.dateStarted) }
    }

    private var completedTodaySessions: [WorkoutSession] {
        todaysSessions
            .filter(\.isCompleted)
            .sorted { lhs, rhs in
                (lhs.dateEnded ?? lhs.updatedAt) > (rhs.dateEnded ?? rhs.updatedAt)
            }
    }

    private func lastUsedText(for template: WorkoutTemplate) -> String {
        guard let session = allSessions.first(where: { $0.templateName == template.title }) else {
            return "未使用"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: session.dateStarted, relativeTo: .now)
    }

    private func templateTags(for template: WorkoutTemplate) -> [String] {
        (template.exercises ?? [])
            .sorted(by: { $0.order < $1.order })
            .prefix(2)
            .map(\.name)
    }

    private var todaysSummary: DashboardSummary {
        let completedSets = todaysSessions.reduce(0) { $0 + $1.completedSetCount }
        let totalSets = todaysSessions.reduce(0) { $0 + $1.totalSetCount }
        let totalVolume = todaysSessions.reduce(0) { $0 + $1.totalVolumeKg }
        let totalDuration = todaysSessions.reduce(0.0) { partial, session in
            partial + session.workoutElapsed(at: now)
        }

        return DashboardSummary(
            completedSets: completedSets,
            totalSets: totalSets,
            totalVolumeKg: totalVolume,
            totalDuration: totalDuration
        )
    }

    private var calendarMonth: CalendarMonth {
        CalendarMonth.make(for: .now)
    }

    private func activeElapsedText(for session: WorkoutSession) -> String {
        let interval = session.workoutElapsed(at: now)
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", hours * 60 + minutes, seconds)
    }

    private func workoutStatusCardContent(
        session: WorkoutSession,
        statusTitle: String,
        accentColor: Color,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.fillSubtle)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(accentColor)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 8) {
                Text(statusTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.fg2)
                Text(session.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.fg1)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accentColor)
                    Text(activeElapsedText(for: session))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(accentColor)
                }
            }

            Spacer()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.fg2)
            }
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.fg4, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 6)
    }
}

private struct TrainingTemplateCard: View {
    let template: WorkoutTemplate
    let lastUsedText: String
    let tags: [String]
    let onStart: (WorkoutTemplate) -> Void

    var body: some View {
        Button {
            onStart(template)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(template.title)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(AppTheme.fg1)

                Text("上次: \(lastUsedText)")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.fg2)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.fg2)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(AppTheme.fillMedium)
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.fillMedium, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct StatusRow: View {
    let color: Color
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)
        }
    }
}

private struct DashboardSummary {
    let completedSets: Int
    let totalSets: Int
    let totalVolumeKg: Double
    let totalDuration: TimeInterval

    var durationText: String {
        "\(max(0, Int(totalDuration / 60)))m"
    }

    func volumeText(unit: WeightUnit) -> String {
        totalVolumeKg.formattedVolume(unit: unit)
    }
}

private struct CalendarMonth {
    let title: String
    let days: [CalendarDay]

    static func make(for date: Date, calendar: Calendar = .current) -> CalendarMonth {
        let monthInterval = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let numberOfDays = calendar.range(of: .day, in: .month, for: date)?.count ?? 0
        let leadingEmptyDays = max(0, firstWeekday - 1)

        var days = Array(repeating: CalendarDay.placeholder, count: leadingEmptyDays)

        for day in 1...numberOfDays {
            guard let currentDate = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) else {
                continue
            }

            days.append(
                CalendarDay(
                    label: "\(day)",
                    isInCurrentMonth: true,
                    isToday: calendar.isDateInToday(currentDate)
                )
            )
        }

        while days.count % 7 != 0 {
            days.append(.placeholder)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月 yyyy"

        return CalendarMonth(title: formatter.string(from: date), days: days)
    }
}

private struct CalendarDay: Identifiable {
    let id = UUID()
    let label: String
    let isInCurrentMonth: Bool
    let isToday: Bool

    static let placeholder = CalendarDay(label: "", isInCurrentMonth: false, isToday: false)
}

private enum AppTab: CaseIterable {
    case train
    case history
    case profile

    var title: String {
        switch self {
        case .train:
            return "训练"
        case .history:
            return "历史"
        case .profile:
            return "我的"
        }
    }

    var icon: String {
        switch self {
        case .train:
            return "figure.strengthtraining.traditional"
        case .history:
            return "clock.arrow.circlepath"
        case .profile:
            return "gearshape"
        }
    }
}

private enum TrainRoute: Hashable {
    case templates
}

// MARK: - 编辑记录目标页（通过 sessionID 查询已有 session）

private struct EditRecordDestination: View {
    @Query private var sessions: [WorkoutSession]

    init(sessionID: UUID) {
        _sessions = Query(filter: #Predicate<WorkoutSession> { $0.id == sessionID })
    }

    var body: some View {
        if let session = sessions.first {
            WorkoutRecordEditView(workout: session)
        } else {
            Text("未找到训练记录").foregroundStyle(.secondary)
        }
    }
}

// MARK: - 新增记录目标页（为指定日期创建一条新 session）

private struct AddRecordDestination: View {
    @Environment(\.modelContext) private var modelContext
    @State private var session: WorkoutSession?

    let date: Date

    var body: some View {
        Group {
            if let session {
                WorkoutRecordEditView(workout: session)
            } else {
                ProgressView()
                    .onAppear { createSession() }
            }
        }
    }

    private func createSession() {
        let s = WorkoutSession(
            title: "训练记录",
            dateStarted: date,
            isCompleted: false
        )
        modelContext.insert(s)
        try? modelContext.save()
        session = s
    }
}

private enum HistoryRoute: Hashable {
    case detail(UUID)
    case editRecord(UUID)
    case addRecord(Date)
}

#Preview {
    ContentView()
        .modelContainer(PreviewModelContainer.shared)
}
