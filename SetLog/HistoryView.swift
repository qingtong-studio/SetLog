import SwiftUI
import SwiftData

private let calAccent = Color(red: 0.60, green: 0.82, blue: 0.26)

struct HistoryView: View {
    @State private var calYear: Int
    @State private var calMonth: Int
    @State private var selectedDate: Date? = nil
    @State private var viewMode: HistoryViewMode = .calendar
    @Query private var preferences: [AppPreferences]
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: [SortDescriptor(\WorkoutSession.dateStarted, order: .reverse)]
    ) private var sessions: [WorkoutSession]

    let onOpenDetail: (UUID) -> Void
    let onAddRecord: (Date) -> Void

    init(onOpenDetail: @escaping (UUID) -> Void = { _ in },
         onAddRecord: @escaping (Date) -> Void = { _ in }) {
        self.onOpenDetail = onOpenDetail
        self.onAddRecord = onAddRecord
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        _calYear = State(initialValue: comps.year ?? 2026)
        _calMonth = State(initialValue: comps.month ?? 1)
    }

    private var weightUnit: WeightUnit {
        preferences.first?.weightUnit ?? .kilogram
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                topBar
                if viewMode == .calendar {
                    calendarSection
                }
                sessionList
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarHidden(true)
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack {
            Text("训练记录")
                .font(.system(size: 22, weight: .bold))

            Spacer()

            // Calendar / List toggle
            HStack(spacing: 0) {
                ForEach([HistoryViewMode.calendar, HistoryViewMode.list], id: \.self) { mode in
                    Button(action: {
                        viewMode = mode
                        selectedDate = nil
                    }) {
                        Image(systemName: mode == .calendar ? "calendar" : "list.bullet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(viewMode == mode ? Color(uiColor: .systemBackground) : .secondary)
                            .frame(width: 36, height: 30)
                            .background(viewMode == mode ? Color.primary : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .padding(2)
            .background(Color(.systemGray5).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: Calendar Section

    private var calendarSection: some View {
        VStack(spacing: 14) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                }

                Spacer()

                Text("\(calYear)年 \(chineseMonth(calMonth))")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                }
            }

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Date grid
            let days = calendarDays()
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                spacing: 2
            ) {
                ForEach(0..<days.count, id: \.self) { i in
                    if let date = days[i] {
                        CalendarDayButton(
                            date: date,
                            isToday: Calendar.current.isDateInToday(date),
                            hasWorkout: hasWorkout(on: date),
                            isSelected: isSelected(date)
                        ) {
                            if isSelected(date) {
                                selectedDate = nil
                            } else {
                                selectedDate = date
                            }
                        }
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    // MARK: Session List

    private var sessionList: some View {
        VStack(spacing: 12) {
            // "添加记录"按钮：仅当日历选中某天时显示
            if let date = selectedDate {
                Button(action: { onAddRecord(date) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("添加记录")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text(shortDateText(date))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(calAccent)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .frame(maxWidth: .infinity)
                    .background(calAccent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(calAccent.opacity(0.30), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            if filteredSessions.isEmpty {
                Text(selectedDate != nil ? "当天无训练记录" : "暂无训练记录")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, selectedDate != nil ? 8 : 32)
            } else {
                ForEach(filteredSessions) { session in
                    Button(action: { onOpenDetail(session.id) }) {
                        HistoryRecordCard(session: session, weightUnit: weightUnit)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func shortDateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }

    private var filteredSessions: [WorkoutSession] {
        guard let date = selectedDate else { return sessions }
        return sessions.filter { Calendar.current.isDate($0.dateStarted, inSameDayAs: date) }
    }

    // MARK: Calendar Helpers

    private func previousMonth() {
        if calMonth == 1 { calYear -= 1; calMonth = 12 } else { calMonth -= 1 }
    }

    private func nextMonth() {
        if calMonth == 12 { calYear += 1; calMonth = 1 } else { calMonth += 1 }
    }

    private func chineseMonth(_ month: Int) -> String {
        ["一月","二月","三月","四月","五月","六月",
         "七月","八月","九月","十月","十一月","十二月"][max(0, min(11, month - 1))]
    }

    // Returns an array padded to a multiple of 7 (nil = empty padding cell)
    private func calendarDays() -> [Date?] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Sunday
        var comps = DateComponents()
        comps.year = calYear
        comps.month = calMonth
        comps.day = 1
        guard let firstDay = cal.date(from: comps) else { return [] }
        let startWeekday = cal.component(.weekday, from: firstDay) - 1 // 0 = Sunday
        guard let range = cal.range(of: .day, in: .month, for: firstDay) else { return [] }

        var result: [Date?] = Array(repeating: nil, count: startWeekday)
        for day in 1...range.count {
            var dc = DateComponents()
            dc.year = calYear; dc.month = calMonth; dc.day = day
            result.append(cal.date(from: dc))
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    private func hasWorkout(on date: Date) -> Bool {
        sessions.contains { Calendar.current.isDate($0.dateStarted, inSameDayAs: date) }
    }

    private func isSelected(_ date: Date) -> Bool {
        selectedDate.map { Calendar.current.isDate(date, inSameDayAs: $0) } ?? false
    }
}

private enum HistoryViewMode: Hashable {
    case calendar, list
}

// MARK: - Calendar Day Button

private struct CalendarDayButton: View {
    let date: Date
    let isToday: Bool
    let hasWorkout: Bool
    let isSelected: Bool
    let action: () -> Void

    private var day: Int { Calendar.current.component(.day, from: date) }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(calAccent)
                } else if hasWorkout {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(calAccent.opacity(0.18))
                }

                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(calAccent, lineWidth: 1.5)
                }

                VStack(spacing: 2) {
                    Text("\(day)")
                        .font(.system(size: 14, weight: hasWorkout ? .bold : .regular))
                        .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)

                    Circle()
                        .fill(isSelected
                              ? Color(uiColor: .systemBackground).opacity(hasWorkout ? 1 : 0)
                              : calAccent.opacity(hasWorkout ? 1 : 0))
                        .frame(width: 4, height: 4)
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History Record Card

private struct HistoryRecordCard: View {
    let session: WorkoutSession
    let weightUnit: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(session.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(dateText)
                    Text("·")
                    Text(durationText)
                    Text("·")
                    Text("\(session.totalSetCount)组")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(volumeNumberText)
                    .font(.system(size: 16, weight: .bold).monospaced())
                    .foregroundStyle(calAccent)

                Text(weightUnit.displaySymbol.lowercased())
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
    }

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: session.dateStarted)
    }

    private var durationText: String {
        let interval = (session.dateEnded ?? session.dateStarted).timeIntervalSince(session.dateStarted)
        return "\(max(1, Int(interval / 60)))分钟"
    }

    private var volumeNumberText: String {
        let converted = session.totalVolumeKg.convertedWeight(from: .kilogram, to: weightUnit)
        return converted.formatted(.number.precision(.fractionLength(0)))
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(PreviewModelContainer.shared)
}
