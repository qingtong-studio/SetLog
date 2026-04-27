import Foundation
import SwiftData

enum WeightUnit: String, Codable, CaseIterable {
    case kilogram = "KG"
    case pound = "LB"
}

enum SetType: String, Codable, CaseIterable {
    case warmup = "warmup"
    case working = "working"
}

enum ExerciseWeightMode: String, Codable, CaseIterable {
    case standard = "standard"      // 非单边 - 输入总重（器械/杠铃）
    case singleHand = "singleHand"  // 单边 - 输入单边重量（哑铃）

    var displayName: String {
        switch self {
        case .standard: return "非单边"
        case .singleHand: return "单边"
        }
    }
}

@Model
final class AppPreferences {
    var weightUnitRawValue: String = WeightUnit.kilogram.rawValue
    var notificationsEnabled: Bool = true
    var hasSeededDefaults: Bool = false
    var seedVersion: Int = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        weightUnit: WeightUnit = .kilogram,
        notificationsEnabled: Bool = true,
        hasSeededDefaults: Bool = false,
        seedVersion: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.weightUnitRawValue = weightUnit.rawValue
        self.notificationsEnabled = notificationsEnabled
        self.hasSeededDefaults = hasSeededDefaults
        self.seedVersion = seedVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRawValue) ?? .kilogram }
        set {
            weightUnitRawValue = newValue.rawValue
            updatedAt = .now
        }
    }
}

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var title: String = ""
    var dateStarted: Date = Date.now
    var dateEnded: Date?
    var workoutTimerStartedAt: Date?
    var workoutElapsedOffset: TimeInterval = 0
    var workoutIsRunning: Bool = false
    var notes: String = ""
    var templateName: String?
    var isCompleted: Bool = false
    var restStartTime: Date?
    var restSourceSetID: UUID?
    var restTargetSeconds: Int = 90
    var restElapsedOffset: TimeInterval = 0
    var restIsPaused: Bool = false
    var restLastUpdatedAt: Date?
    var restActualSeconds: Int?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.session)
    var exercises: [WorkoutExercise]? = []

    init(
        id: UUID = UUID(),
        title: String,
        dateStarted: Date = .now,
        dateEnded: Date? = nil,
        workoutTimerStartedAt: Date? = nil,
        workoutElapsedOffset: TimeInterval = 0,
        workoutIsRunning: Bool = false,
        notes: String = "",
        templateName: String? = nil,
        isCompleted: Bool = false,
        restStartTime: Date? = nil,
        restSourceSetID: UUID? = nil,
        restTargetSeconds: Int = 90,
        restElapsedOffset: TimeInterval = 0,
        restIsPaused: Bool = false,
        restLastUpdatedAt: Date? = nil,
        restActualSeconds: Int? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        exercises: [WorkoutExercise] = []
    ) {
        self.id = id
        self.title = title
        self.dateStarted = dateStarted
        self.dateEnded = dateEnded
        self.workoutTimerStartedAt = workoutTimerStartedAt
        self.workoutElapsedOffset = workoutElapsedOffset
        self.workoutIsRunning = workoutIsRunning
        self.notes = notes
        self.templateName = templateName
        self.isCompleted = isCompleted
        self.restStartTime = restStartTime
        self.restSourceSetID = restSourceSetID
        self.restTargetSeconds = restTargetSeconds
        self.restElapsedOffset = restElapsedOffset
        self.restIsPaused = restIsPaused
        self.restLastUpdatedAt = restLastUpdatedAt
        self.restActualSeconds = restActualSeconds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.exercises = exercises
    }
}

@Model
final class WorkoutExercise {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = ""
    var order: Int = 0
    var notes: String = ""
    var weightModeRawValue: String?
    var session: WorkoutSession?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet]? = []

    var weightMode: ExerciseWeightMode {
        get { ExerciseWeightMode(rawValue: weightModeRawValue ?? "") ?? .standard }
        set { weightModeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        order: Int,
        notes: String = "",
        weightModeRawValue: String? = ExerciseWeightMode.standard.rawValue,
        session: WorkoutSession? = nil,
        sets: [WorkoutSet] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.order = order
        self.notes = notes
        self.weightModeRawValue = weightModeRawValue
        self.session = session
        self.sets = sets
    }
}

@Model
final class WorkoutSet {
    var id: UUID = UUID()
    var index: Int = 0
    var targetReps: Int?
    var actualReps: Int?
    var weightKg: Double = 0
    var restAfter: TimeInterval = 90
    var recordedRestSeconds: Int?
    var setTypeRawValue: String?
    var isCompleted: Bool = false
    var completedAt: Date?
    var rpe: Int?
    var exercise: WorkoutExercise?

    init(
        id: UUID = UUID(),
        index: Int,
        targetReps: Int? = nil,
        actualReps: Int? = nil,
        weightKg: Double = 0,
        restAfter: TimeInterval = 90,
        recordedRestSeconds: Int? = nil,
        setTypeRawValue: String? = SetType.working.rawValue,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        rpe: Int? = nil,
        exercise: WorkoutExercise? = nil
    ) {
        self.id = id
        self.index = index
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.weightKg = weightKg
        self.restAfter = restAfter
        self.recordedRestSeconds = recordedRestSeconds
        self.setTypeRawValue = setTypeRawValue
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.rpe = rpe
        self.exercise = exercise
    }
}

@Model
final class ExerciseCatalogItem {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = ""
    var targetMuscle: String = ""
    var defaultSets: Int = 0
    var defaultReps: Int = 0
    var defaultWeightKg: Double = 0
    var symbolName: String = ""
    var tintName: String = ""
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        targetMuscle: String,
        defaultSets: Int,
        defaultReps: Int,
        defaultWeightKg: Double,
        symbolName: String,
        tintName: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.targetMuscle = targetMuscle
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.defaultWeightKg = defaultWeightKg
        self.symbolName = symbolName
        self.tintName = tintName
        self.createdAt = createdAt
    }
}

@Model
final class WorkoutTemplate {
    var id: UUID = UUID()
    var title: String = ""
    var category: String = ""
    var groupName: String?
    var estimatedDuration: Int = 0
    var level: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise]? = []

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        groupName: String? = nil,
        estimatedDuration: Int,
        level: String,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        exercises: [TemplateExercise] = []
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.groupName = groupName
        self.estimatedDuration = estimatedDuration
        self.level = level
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.exercises = exercises
    }
}

@Model
final class TemplateExercise {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = ""
    var order: Int = 0
    var defaultSets: Int = 0
    var defaultReps: Int = 0
    var defaultWeightKg: Double = 0
    var symbolName: String = ""
    var template: WorkoutTemplate?

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        order: Int,
        defaultSets: Int,
        defaultReps: Int,
        defaultWeightKg: Double,
        symbolName: String,
        template: WorkoutTemplate? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.order = order
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.defaultWeightKg = defaultWeightKg
        self.symbolName = symbolName
        self.template = template
    }
}

extension WorkoutSession {
    var orderedExercises: [WorkoutExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    var elapsedTimeText: String {
        let interval = workoutElapsed(at: dateEnded ?? .now)
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func workoutElapsed(at date: Date = .now) -> TimeInterval {
        guard workoutIsRunning, let workoutTimerStartedAt else {
            return max(0, workoutElapsedOffset)
        }

        return max(0, workoutElapsedOffset + date.timeIntervalSince(workoutTimerStartedAt))
    }

    var workoutHasStarted: Bool {
        workoutElapsedOffset > 0 || workoutTimerStartedAt != nil
    }

    var currentExercise: WorkoutExercise? {
        orderedExercises.first(where: { !$0.isFinished }) ?? orderedExercises.first
    }

    var completedSetCount: Int {
        orderedExercises.flatMap(\.orderedSets).filter(\.isCompleted).count
    }

    var totalSetCount: Int {
        orderedExercises.reduce(0) { $0 + $1.orderedSets.count }
    }

    var totalVolumeKg: Double {
        orderedExercises.reduce(0) { $0 + $1.totalVolumeKg }
    }

    var hasActiveRest: Bool {
        restStartTime != nil && !isCompleted
    }

    func restElapsed(at date: Date = .now) -> TimeInterval {
        guard let restStartTime else {
            return 0
        }

        if restIsPaused {
            return restElapsedOffset
        }

        return max(0, restElapsedOffset + date.timeIntervalSince(restStartTime))
    }

    func restRemainingSeconds(at date: Date = .now) -> Int {
        max(0, restTargetSeconds - Int(restElapsed(at: date)))
    }

    func restProgress(at date: Date = .now) -> Double {
        guard restTargetSeconds > 0 else {
            return 1
        }

        return min(1, max(0, Double(restElapsed(at: date)) / Double(restTargetSeconds)))
    }
}

extension WorkoutExercise {
    var orderedSets: [WorkoutSet] {
        (sets ?? []).sorted { $0.index < $1.index }
    }

    var warmupSets: [WorkoutSet] {
        orderedSets.filter { $0.setType == .warmup }
    }

    var workingSets: [WorkoutSet] {
        orderedSets.filter { $0.setType == .working }
    }

    var completedSetCount: Int {
        orderedSets.filter(\.isCompleted).count
    }

    var isFinished: Bool {
        !orderedSets.isEmpty && completedSetCount == orderedSets.count
    }

    var progressText: String {
        "\(completedSetCount) / \(orderedSets.count) 组已完成"
    }

    var totalVolumeKg: Double {
        let mode = weightMode
        return orderedSets.filter(\.isCompleted).reduce(0) { result, set in
            let reps = Double(set.actualReps ?? set.targetReps ?? 0)
            let effective = mode == .singleHand ? set.weightKg * 2 : set.weightKg
            return result + effective * reps
        }
    }
}

extension WorkoutSet {
    var setType: SetType {
        get { SetType(rawValue: setTypeRawValue ?? "") ?? .working }
        set { setTypeRawValue = newValue.rawValue }
    }

    var isWarmup: Bool {
        setType == .warmup
    }

    var repsDisplay: String {
        "\(actualReps ?? targetReps ?? 0)"
    }

    var weightDisplay: String {
        if weightKg.rounded() == weightKg {
            return "\(Int(weightKg))"
        }
        return String(format: "%.1f", weightKg)
    }

    var restDisplay: String {
        guard isCompleted, let recordedRestSeconds else {
            return "-"
        }
        return "\(recordedRestSeconds)"
    }

    var canEditRecordedRest: Bool {
        isCompleted && recordedRestSeconds != nil
    }

    var completedRestDisplay: String {
        canEditRecordedRest ? "\(recordedRestSeconds ?? 0)" : "-"
    }

    func weightDisplay(unit: WeightUnit) -> String {
        weightKg.formattedWeight(unit: unit)
    }

    func effectiveWeightKg(mode: ExerciseWeightMode) -> Double {
        mode == .singleHand ? weightKg * 2 : weightKg
    }
}

extension Double {
    private static let poundsPerKilogram = 2.20462

    func convertedWeight(from sourceUnit: WeightUnit, to targetUnit: WeightUnit) -> Double {
        guard sourceUnit != targetUnit else {
            return self
        }

        switch (sourceUnit, targetUnit) {
        case (.kilogram, .pound):
            return self * Self.poundsPerKilogram
        case (.pound, .kilogram):
            return self / Self.poundsPerKilogram
        default:
            return self
        }
    }

    func formattedWeight(unit: WeightUnit, fractionDigits: Int = 1) -> String {
        let convertedValue = convertedWeight(from: .kilogram, to: unit)
        let roundedValue = convertedValue.rounded()
        if abs(convertedValue - roundedValue) < 0.05 {
            return "\(Int(roundedValue))"
        }

        return convertedValue.formatted(.number.precision(.fractionLength(0...fractionDigits)))
    }

    func formattedWeightWithUnit(unit: WeightUnit, fractionDigits: Int = 1) -> String {
        "\(formattedWeight(unit: unit, fractionDigits: fractionDigits)) \(unit.displaySymbol)"
    }

    func formattedVolume(unit: WeightUnit) -> String {
        let convertedValue = convertedWeight(from: .kilogram, to: unit)
        let formattedValue = convertedValue.formatted(.number.precision(.fractionLength(0)))
        return "\(formattedValue) \(unit.displaySymbol.lowercased())"
    }
}

extension WeightUnit {
    var displaySymbol: String {
        rawValue
    }
}

// MARK: - Export

extension WorkoutSession {
    func exportMarkdown(unit: WeightUnit) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        let durationMin = max(1, Int((dateEnded ?? dateStarted).timeIntervalSince(dateStarted) / 60))

        var md = "## \(dateFormatter.string(from: dateStarted)) - \(title)\n"
        md += "时长: \(durationMin)分钟 | 总组数: \(totalSetCount) | 总容量: \(totalVolumeKg.formattedVolume(unit: unit))\n\n"

        for exercise in orderedExercises {
            let modeLabel = exercise.weightMode == .singleHand ? " [单边模式]" : ""
            md += "### \(exercise.name) (\(exercise.category))\(modeLabel)\n"
            md += "| 组 | 类型 | 重量(\(unit.displaySymbol.lowercased())) | 次数 | 休息(s) |\n"
            md += "|----|------|----------|------|--------|\n"
            for set in exercise.orderedSets {
                let typeLabel = set.isWarmup ? "热身" : "正式"
                let weight = set.weightKg.formattedWeight(unit: unit)
                let reps = set.actualReps ?? set.targetReps ?? 0
                let rest = set.recordedRestSeconds.map { "\($0)" } ?? "-"
                md += "| \(set.index) | \(typeLabel) | \(weight) | \(reps) | \(rest) |\n"
            }
            md += "\n"
        }

        if !notes.isEmpty {
            md += "备注: \(notes)\n\n"
        }
        return md
    }
}

extension Array where Element == WorkoutSession {
    func generateExportContent(unit: WeightUnit) -> String {
        let sorted = self.filter { $0.isCompleted }.sorted { $0.dateStarted < $1.dateStarted }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        var md = "# SetLog 训练记录导出\n"
        md += "导出时间: \(dateFormatter.string(from: Date()))\n"
        md += "总训练次数: \(sorted.count)"
        let totalVolume = sorted.reduce(0.0) { $0 + $1.totalVolumeKg }
        md += " | 总容量: \(totalVolume.formattedVolume(unit: unit))\n\n"
        md += "---\n\n"

        for session in sorted {
            md += session.exportMarkdown(unit: unit)
            md += "---\n\n"
        }

        return md
    }
}

enum SampleDataSeeder {
    static func seedIfNeeded(in context: ModelContext) throws {
        var prefsDescriptor = FetchDescriptor<AppPreferences>()
        prefsDescriptor.fetchLimit = 1
        let prefs = try context.fetch(prefsDescriptor).first

        // Skip only when both first-run seeding has happened AND template
        // seed version is up-to-date. Otherwise fall through so we can
        // back-fill new defaults / migrate templates.
        if prefs?.hasSeededDefaults == true && (prefs?.seedVersion ?? 0) >= currentSeedVersion {
            return
        }

        let existingCatalogItems = try context.fetch(FetchDescriptor<ExerciseCatalogItem>())
        let existingCatalogNames = Set(existingCatalogItems.map(\.name))
        let catalogItems = makeCatalogItems().filter { !existingCatalogNames.contains($0.name) }

        let freshTemplates = makeTemplates()
        let freshTemplatesByTitle = Dictionary(uniqueKeysWithValues: freshTemplates.map { ($0.title, $0) })
        let freshTitles = Set(freshTemplates.map(\.title))

        // Migrate templates: if seedVersion is behind, drop superseded templates
        // (legacy v3 cycle) AND any current-version templates so we re-insert
        // them with the latest exercise list / sets / reps.
        var existingTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        if (prefs?.seedVersion ?? 0) < currentSeedVersion {
            let stale = existingTemplates.filter {
                $0.groupName == groupCycleV3
                    || $0.title.hasPrefix("v3-")
                    || freshTitles.contains($0.title)
            }
            for template in stale {
                context.delete(template)
            }
            existingTemplates.removeAll { stale.contains($0) }
        }

        let existingTemplateTitles = Set(existingTemplates.map(\.title))
        let templates = freshTemplates.filter { !existingTemplateTitles.contains($0.title) }
        let existingSessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let sessions = makeSessions()

        // If any user data already synced down from iCloud, treat this install
        // as "restored" and skip demo sessions — still allow catalog/template
        // back-fills if a new build introduces new defaults.
        let alreadyHasAnyData = !existingCatalogItems.isEmpty || !existingTemplates.isEmpty || !existingSessions.isEmpty

        var hasChanges = false
        for item in catalogItems {
            context.insert(item)
            hasChanges = true
        }

        for template in templates {
            context.insert(template)
            hasChanges = true
        }

        for existing in existingTemplates {
            if !freshTitles.contains(existing.title) {
                context.delete(existing)
                hasChanges = true
                continue
            }
            guard let reference = freshTemplatesByTitle[existing.title] else { continue }
            if existing.groupName != reference.groupName {
                existing.groupName = reference.groupName
                hasChanges = true
            }
            if existing.sortOrder != reference.sortOrder {
                existing.sortOrder = reference.sortOrder
                hasChanges = true
            }
        }

        if !alreadyHasAnyData {
            for session in sessions {
                context.insert(session)
                hasChanges = true
            }
        }

        if let prefs {
            if !prefs.hasSeededDefaults {
                prefs.hasSeededDefaults = true
                prefs.updatedAt = .now
                hasChanges = true
            }
            if prefs.seedVersion < currentSeedVersion {
                prefs.seedVersion = currentSeedVersion
                prefs.updatedAt = .now
                hasChanges = true
            }
        }

        if hasChanges {
            try context.save()
        }
    }

    private static func makeCatalogItems() -> [ExerciseCatalogItem] {
        [
            ExerciseCatalogItem(name: "杠铃卧推", category: "胸部", targetMuscle: "胸大肌", defaultSets: 4, defaultReps: 8, defaultWeightKg: 60, symbolName: "flame.fill", tintName: "orange"),
            ExerciseCatalogItem(name: "深蹲", category: "腿部", targetMuscle: "股四头肌", defaultSets: 4, defaultReps: 6, defaultWeightKg: 100, symbolName: "figure.strengthtraining.traditional", tintName: "blue"),
            ExerciseCatalogItem(name: "硬拉", category: "背部", targetMuscle: "后侧链", defaultSets: 3, defaultReps: 5, defaultWeightKg: 120, symbolName: "mountain.2.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "引体向上", category: "背部", targetMuscle: "背阔肌", defaultSets: 4, defaultReps: 8, defaultWeightKg: 0, symbolName: "figure.pull.up", tintName: "mint"),
            ExerciseCatalogItem(name: "肩推", category: "肩部", targetMuscle: "三角肌", defaultSets: 3, defaultReps: 10, defaultWeightKg: 30, symbolName: "triangle.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "哑铃弯举", category: "手臂", targetMuscle: "肱二头肌", defaultSets: 3, defaultReps: 12, defaultWeightKg: 12.5, symbolName: "bolt.fill", tintName: "purple"),

            ExerciseCatalogItem(name: "上斜哑铃卧推", category: "胸部", targetMuscle: "胸大肌上束", defaultSets: 4, defaultReps: 8, defaultWeightKg: 30, symbolName: "flame.fill", tintName: "orange"),
            ExerciseCatalogItem(name: "上斜杠铃卧推", category: "胸部", targetMuscle: "胸大肌上束", defaultSets: 3, defaultReps: 8, defaultWeightKg: 60, symbolName: "flame.fill", tintName: "orange"),
            ExerciseCatalogItem(name: "Smith 上斜", category: "胸部", targetMuscle: "胸大肌上束", defaultSets: 3, defaultReps: 6, defaultWeightKg: 60, symbolName: "flame.fill", tintName: "orange"),
            ExerciseCatalogItem(name: "低到高飞鸟", category: "胸部", targetMuscle: "胸大肌上束", defaultSets: 3, defaultReps: 12, defaultWeightKg: 12, symbolName: "flame.fill", tintName: "orange"),

            ExerciseCatalogItem(name: "对握引体", category: "背部", targetMuscle: "背阔肌", defaultSets: 4, defaultReps: 6, defaultWeightKg: 10, symbolName: "figure.pull.up", tintName: "mint"),
            ExerciseCatalogItem(name: "对握高位下拉", category: "背部", targetMuscle: "背阔肌", defaultSets: 3, defaultReps: 8, defaultWeightKg: 55, symbolName: "figure.rower", tintName: "mint"),
            ExerciseCatalogItem(name: "单臂高位下拉", category: "背部", targetMuscle: "背阔肌", defaultSets: 3, defaultReps: 10, defaultWeightKg: 25, symbolName: "figure.rower", tintName: "mint"),
            ExerciseCatalogItem(name: "胸托划船", category: "背部", targetMuscle: "上背部", defaultSets: 3, defaultReps: 8, defaultWeightKg: 50, symbolName: "figure.strengthtraining.traditional", tintName: "mint"),
            ExerciseCatalogItem(name: "直臂下压", category: "背部", targetMuscle: "背阔肌", defaultSets: 3, defaultReps: 12, defaultWeightKg: 35, symbolName: "arrow.down.circle.fill", tintName: "mint"),

            ExerciseCatalogItem(name: "单臂侧平举", category: "肩部", targetMuscle: "三角肌中束", defaultSets: 3, defaultReps: 12, defaultWeightKg: 8, symbolName: "triangle.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "机器侧平举", category: "肩部", targetMuscle: "三角肌中束", defaultSets: 3, defaultReps: 15, defaultWeightKg: 7, symbolName: "triangle.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "倾斜侧平举", category: "肩部", targetMuscle: "三角肌中束", defaultSets: 3, defaultReps: 15, defaultWeightKg: 6, symbolName: "triangle.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "严格侧平举", category: "肩部", targetMuscle: "三角肌中束", defaultSets: 2, defaultReps: 15, defaultWeightKg: 6, symbolName: "triangle.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "轻量侧平举", category: "肩部", targetMuscle: "三角肌中束", defaultSets: 2, defaultReps: 15, defaultWeightKg: 5, symbolName: "triangle.fill", tintName: "gray"),

            ExerciseCatalogItem(name: "RDL", category: "腿部", targetMuscle: "后侧链", defaultSets: 3, defaultReps: 6, defaultWeightKg: 90, symbolName: "figure.strengthtraining.traditional", tintName: "blue"),
            ExerciseCatalogItem(name: "腿举", category: "腿部", targetMuscle: "股四头肌", defaultSets: 3, defaultReps: 8, defaultWeightKg: 140, symbolName: "figure.strengthtraining.traditional", tintName: "blue"),
            ExerciseCatalogItem(name: "腿弯举", category: "腿部", targetMuscle: "腘绳肌", defaultSets: 3, defaultReps: 10, defaultWeightKg: 35, symbolName: "figure.strengthtraining.traditional", tintName: "blue"),

            ExerciseCatalogItem(name: "绳索卷腹", category: "核心", targetMuscle: "腹直肌", defaultSets: 4, defaultReps: 10, defaultWeightKg: 55, symbolName: "bolt.fill", tintName: "purple"),
            ExerciseCatalogItem(name: "下斜卷腹", category: "核心", targetMuscle: "腹直肌", defaultSets: 3, defaultReps: 10, defaultWeightKg: 5, symbolName: "bolt.fill", tintName: "purple"),
            ExerciseCatalogItem(name: "悬垂举腿", category: "核心", targetMuscle: "下腹", defaultSets: 3, defaultReps: 12, defaultWeightKg: 0, symbolName: "bolt.fill", tintName: "purple"),
            ExerciseCatalogItem(name: "Pallof", category: "核心", targetMuscle: "抗旋转核心", defaultSets: 3, defaultReps: 12, defaultWeightKg: 20, symbolName: "bolt.fill", tintName: "purple"),
            ExerciseCatalogItem(name: "前锯墙滑", category: "肩部", targetMuscle: "前锯肌", defaultSets: 3, defaultReps: 12, defaultWeightKg: 0, symbolName: "triangle.fill", tintName: "gray"),

            // 腿部补充
            ExerciseCatalogItem(name: "腿伸", category: "腿部", targetMuscle: "股四头肌", defaultSets: 3, defaultReps: 15, defaultWeightKg: 40, symbolName: "figure.strengthtraining.traditional", tintName: "blue"),
            ExerciseCatalogItem(name: "站姿提踵", category: "腿部", targetMuscle: "小腿", defaultSets: 4, defaultReps: 15, defaultWeightKg: 60, symbolName: "figure.strengthtraining.traditional", tintName: "blue"),

            // 胸部补充
            ExerciseCatalogItem(name: "平板杠铃卧推", category: "胸部", targetMuscle: "胸大肌", defaultSets: 4, defaultReps: 6, defaultWeightKg: 80, symbolName: "flame.fill", tintName: "orange"),
            ExerciseCatalogItem(name: "下斜卧推", category: "胸部", targetMuscle: "胸大肌下束", defaultSets: 3, defaultReps: 10, defaultWeightKg: 70, symbolName: "flame.fill", tintName: "orange"),
            ExerciseCatalogItem(name: "绳索夹胸（中位）", category: "胸部", targetMuscle: "胸大肌", defaultSets: 3, defaultReps: 12, defaultWeightKg: 15, symbolName: "flame.fill", tintName: "orange"),
            ExerciseCatalogItem(name: "双杠臂屈伸", category: "胸部", targetMuscle: "胸大肌下束", defaultSets: 3, defaultReps: 10, defaultWeightKg: 0, symbolName: "flame.fill", tintName: "orange"),

            // 背部补充
            ExerciseCatalogItem(name: "加重引体向上", category: "背部", targetMuscle: "背阔肌", defaultSets: 4, defaultReps: 5, defaultWeightKg: 15, symbolName: "figure.pull.up", tintName: "mint"),
            ExerciseCatalogItem(name: "杠铃划船", category: "背部", targetMuscle: "上背部", defaultSets: 4, defaultReps: 8, defaultWeightKg: 80, symbolName: "figure.rower", tintName: "mint"),
            ExerciseCatalogItem(name: "绳索高位下拉", category: "背部", targetMuscle: "背阔肌", defaultSets: 3, defaultReps: 10, defaultWeightKg: 60, symbolName: "figure.rower", tintName: "mint"),
            ExerciseCatalogItem(name: "面拉", category: "背部", targetMuscle: "后束三角肌", defaultSets: 3, defaultReps: 15, defaultWeightKg: 25, symbolName: "figure.rower", tintName: "mint"),
            ExerciseCatalogItem(name: "单臂哑铃划船", category: "背部", targetMuscle: "背阔肌", defaultSets: 3, defaultReps: 10, defaultWeightKg: 35, symbolName: "figure.rower", tintName: "mint"),
            ExerciseCatalogItem(name: "Dead Hang", category: "背部", targetMuscle: "背阔肌", defaultSets: 3, defaultReps: 30, defaultWeightKg: 0, symbolName: "figure.pull.up", tintName: "mint"),

            // 肩部补充
            ExerciseCatalogItem(name: "后束飞鸟", category: "肩部", targetMuscle: "后束三角肌", defaultSets: 3, defaultReps: 15, defaultWeightKg: 8, symbolName: "triangle.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "哑铃肩推", category: "肩部", targetMuscle: "三角肌", defaultSets: 3, defaultReps: 10, defaultWeightKg: 25, symbolName: "triangle.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "哑铃侧平举", category: "肩部", targetMuscle: "三角肌中束", defaultSets: 4, defaultReps: 15, defaultWeightKg: 8, symbolName: "triangle.fill", tintName: "gray"),

            // 手臂补充
            ExerciseCatalogItem(name: "锤式弯举", category: "手臂", targetMuscle: "肱二头肌", defaultSets: 3, defaultReps: 12, defaultWeightKg: 14, symbolName: "bolt.fill", tintName: "purple"),
            ExerciseCatalogItem(name: "哑铃集中弯举", category: "手臂", targetMuscle: "肱二头肌", defaultSets: 3, defaultReps: 12, defaultWeightKg: 12, symbolName: "bolt.fill", tintName: "purple"),
            ExerciseCatalogItem(name: "绳索下压（直杆）", category: "手臂", targetMuscle: "肱三头肌", defaultSets: 3, defaultReps: 12, defaultWeightKg: 30, symbolName: "bolt.fill", tintName: "purple"),
            ExerciseCatalogItem(name: "过顶绳索伸展", category: "手臂", targetMuscle: "肱三头肌", defaultSets: 3, defaultReps: 12, defaultWeightKg: 20, symbolName: "bolt.fill", tintName: "purple"),

            // 核心补充
            ExerciseCatalogItem(name: "负重卷腹", category: "核心", targetMuscle: "腹直肌", defaultSets: 3, defaultReps: 12, defaultWeightKg: 10, symbolName: "bolt.fill", tintName: "purple"),

            // 完整训练周期计划 v2 补充
            ExerciseCatalogItem(name: "站姿杠铃推举 OHP", category: "肩部", targetMuscle: "三角肌前束", defaultSets: 4, defaultReps: 6, defaultWeightKg: 50, symbolName: "triangle.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "罗马尼亚硬拉", category: "腿部", targetMuscle: "腘绳肌", defaultSets: 4, defaultReps: 8, defaultWeightKg: 90, symbolName: "figure.strengthtraining.traditional", tintName: "blue"),
            ExerciseCatalogItem(name: "悬挂举腿", category: "核心", targetMuscle: "下腹+髂腰肌", defaultSets: 4, defaultReps: 12, defaultWeightKg: 5, symbolName: "bolt.fill", tintName: "purple"),
            ExerciseCatalogItem(name: "上斜哑铃飞鸟", category: "胸部", targetMuscle: "胸大肌上束", defaultSets: 3, defaultReps: 12, defaultWeightKg: 10, symbolName: "flame.fill", tintName: "orange"),
            ExerciseCatalogItem(name: "器械夹胸", category: "胸部", targetMuscle: "胸大肌", defaultSets: 3, defaultReps: 15, defaultWeightKg: 40, symbolName: "flame.fill", tintName: "orange"),
            ExerciseCatalogItem(name: "木桩转体 Pallof Press", category: "核心", targetMuscle: "腹斜肌", defaultSets: 3, defaultReps: 12, defaultWeightKg: 20, symbolName: "bolt.fill", tintName: "purple"),

            // v4 五日分化 补充
            ExerciseCatalogItem(name: "杠铃深蹲", category: "腿部", targetMuscle: "股四头肌", defaultSets: 5, defaultReps: 5, defaultWeightKg: 0, symbolName: "figure.strengthtraining.traditional", tintName: "blue"),
            ExerciseCatalogItem(name: "器械腿屈伸", category: "腿部", targetMuscle: "股四头肌", defaultSets: 3, defaultReps: 15, defaultWeightKg: 0, symbolName: "figure.strengthtraining.traditional", tintName: "blue"),
            ExerciseCatalogItem(name: "史密斯机站姿提踵", category: "腿部", targetMuscle: "小腿", defaultSets: 2, defaultReps: 10, defaultWeightKg: 0, symbolName: "figure.strengthtraining.traditional", tintName: "blue"),
            ExerciseCatalogItem(name: "坐姿提踵机", category: "腿部", targetMuscle: "比目鱼肌", defaultSets: 2, defaultReps: 15, defaultWeightKg: 0, symbolName: "figure.strengthtraining.traditional", tintName: "blue"),
            ExerciseCatalogItem(name: "平板哑铃卧推", category: "胸部", targetMuscle: "胸大肌", defaultSets: 4, defaultReps: 8, defaultWeightKg: 0, symbolName: "flame.fill", tintName: "orange"),
            ExerciseCatalogItem(name: "双杠臂屈伸（加重）", category: "胸部", targetMuscle: "胸大肌下束", defaultSets: 3, defaultReps: 10, defaultWeightKg: 0, symbolName: "flame.fill", tintName: "orange"),
            ExerciseCatalogItem(name: "宽握高位下拉", category: "背部", targetMuscle: "背阔肌", defaultSets: 3, defaultReps: 12, defaultWeightKg: 0, symbolName: "figure.rower", tintName: "mint"),
            ExerciseCatalogItem(name: "实力举OHP", category: "肩部", targetMuscle: "三角肌前束", defaultSets: 4, defaultReps: 6, defaultWeightKg: 0, symbolName: "triangle.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "哑铃后束飞鸟", category: "肩部", targetMuscle: "后束三角肌", defaultSets: 3, defaultReps: 15, defaultWeightKg: 0, symbolName: "triangle.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "绳索下压", category: "手臂", targetMuscle: "肱三头肌", defaultSets: 4, defaultReps: 12, defaultWeightKg: 0, symbolName: "bolt.fill", tintName: "purple"),
            ExerciseCatalogItem(name: "绳索夹胸", category: "胸部", targetMuscle: "胸大肌", defaultSets: 4, defaultReps: 15, defaultWeightKg: 0, symbolName: "flame.fill", tintName: "orange"),
            ExerciseCatalogItem(name: "木桩转体", category: "核心", targetMuscle: "腹斜肌", defaultSets: 3, defaultReps: 12, defaultWeightKg: 0, symbolName: "bolt.fill", tintName: "purple"),
            ExerciseCatalogItem(name: "绳索侧平举（单臂）", category: "肩部", targetMuscle: "三角肌中束", defaultSets: 4, defaultReps: 15, defaultWeightKg: 0, symbolName: "triangle.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "反向飞鸟（器械）", category: "肩部", targetMuscle: "后束三角肌", defaultSets: 3, defaultReps: 15, defaultWeightKg: 0, symbolName: "triangle.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "弹力带二头弯举", category: "手臂", targetMuscle: "肱二头肌", defaultSets: 3, defaultReps: 20, defaultWeightKg: 0, symbolName: "bolt.fill", tintName: "purple")
        ]
    }

    static let groupCycleV3 = "周期 v3 · 推拉臂+攀岩"
    static let groupCycleV4 = "周期 v4 · 五日分化"

    static let currentSeedVersion: Int = 3

    static let groupDisplayOrder: [String] = [
        groupCycleV4,
        groupCycleV3
    ]

    private static func makeTemplates() -> [WorkoutTemplate] {
        // ── 周期 v4 · 五日分化 ───────────────────────────────────────────

        // 周一 · 腿
        let v4Mon = WorkoutTemplate(title: "v4-周一·腿", category: "Legs", groupName: groupCycleV4, estimatedDuration: 75, level: "计划", sortOrder: 1)
        v4Mon.exercises = [
            TemplateExercise(name: "杠铃深蹲",         category: "腿部", order: 0, defaultSets: 5, defaultReps: 5,  defaultWeightKg: 0, symbolName: "figure.strengthtraining.traditional", template: v4Mon),
            TemplateExercise(name: "罗马尼亚硬拉",     category: "腿部", order: 1, defaultSets: 3, defaultReps: 8,  defaultWeightKg: 0, symbolName: "figure.strengthtraining.traditional", template: v4Mon),
            TemplateExercise(name: "腿弯举",           category: "腿部", order: 2, defaultSets: 4, defaultReps: 12, defaultWeightKg: 0, symbolName: "figure.strengthtraining.traditional", template: v4Mon),
            TemplateExercise(name: "器械腿屈伸",       category: "腿部", order: 3, defaultSets: 3, defaultReps: 15, defaultWeightKg: 0, symbolName: "figure.strengthtraining.traditional", template: v4Mon),
            TemplateExercise(name: "史密斯机站姿提踵", category: "腿部", order: 4, defaultSets: 2, defaultReps: 10, defaultWeightKg: 0, symbolName: "figure.strengthtraining.traditional", template: v4Mon),
            TemplateExercise(name: "坐姿提踵机",       category: "腿部", order: 5, defaultSets: 2, defaultReps: 15, defaultWeightKg: 0, symbolName: "figure.strengthtraining.traditional", template: v4Mon),
            TemplateExercise(name: "负重卷腹",         category: "核心", order: 6, defaultSets: 4, defaultReps: 12, defaultWeightKg: 0, symbolName: "bolt.fill",                              template: v4Mon)
        ]

        // 周二 · 推（力量）
        let v4Tue = WorkoutTemplate(title: "v4-周二·推（力量）", category: "Push", groupName: groupCycleV4, estimatedDuration: 75, level: "计划", sortOrder: 2)
        v4Tue.exercises = [
            TemplateExercise(name: "上斜杠铃卧推",     category: "胸部", order: 0, defaultSets: 5, defaultReps: 5,  defaultWeightKg: 0, symbolName: "flame.fill",     template: v4Tue),
            TemplateExercise(name: "平板哑铃卧推",     category: "胸部", order: 1, defaultSets: 4, defaultReps: 8,  defaultWeightKg: 0, symbolName: "flame.fill",     template: v4Tue),
            TemplateExercise(name: "双杠臂屈伸（加重）", category: "胸部", order: 2, defaultSets: 3, defaultReps: 10, defaultWeightKg: 0, symbolName: "flame.fill",     template: v4Tue),
            TemplateExercise(name: "哑铃侧平举",       category: "肩部", order: 3, defaultSets: 4, defaultReps: 15, defaultWeightKg: 0, symbolName: "triangle.fill",  template: v4Tue),
            TemplateExercise(name: "锤式弯举",         category: "手臂", order: 4, defaultSets: 3, defaultReps: 10, defaultWeightKg: 0, symbolName: "bolt.fill",      template: v4Tue),
            TemplateExercise(name: "悬挂举腿",         category: "核心", order: 5, defaultSets: 4, defaultReps: 12, defaultWeightKg: 0, symbolName: "bolt.fill",      template: v4Tue)
        ]

        // 周三 · 拉
        let v4Wed = WorkoutTemplate(title: "v4-周三·拉", category: "Pull", groupName: groupCycleV4, estimatedDuration: 65, level: "计划", sortOrder: 3)
        v4Wed.exercises = [
            TemplateExercise(name: "加重引体向上",     category: "背部", order: 0, defaultSets: 4, defaultReps: 6,  defaultWeightKg: 0, symbolName: "figure.pull.up", template: v4Wed),
            TemplateExercise(name: "杠铃划船",         category: "背部", order: 1, defaultSets: 4, defaultReps: 8,  defaultWeightKg: 0, symbolName: "figure.rower",   template: v4Wed),
            TemplateExercise(name: "宽握高位下拉",     category: "背部", order: 2, defaultSets: 3, defaultReps: 12, defaultWeightKg: 0, symbolName: "figure.rower",   template: v4Wed),
            TemplateExercise(name: "面拉",             category: "背部", order: 3, defaultSets: 4, defaultReps: 15, defaultWeightKg: 0, symbolName: "figure.rower",   template: v4Wed),
            TemplateExercise(name: "绳索卷腹",         category: "核心", order: 4, defaultSets: 4, defaultReps: 15, defaultWeightKg: 0, symbolName: "bolt.fill",      template: v4Wed)
        ]

        // 周四 · 手臂+肩
        let v4Thu = WorkoutTemplate(title: "v4-周四·手臂+肩", category: "Arms", groupName: groupCycleV4, estimatedDuration: 70, level: "计划", sortOrder: 4)
        v4Thu.exercises = [
            TemplateExercise(name: "实力举OHP",        category: "肩部", order: 0, defaultSets: 4, defaultReps: 6,  defaultWeightKg: 0, symbolName: "triangle.fill",  template: v4Thu),
            TemplateExercise(name: "哑铃侧平举",       category: "肩部", order: 1, defaultSets: 5, defaultReps: 15, defaultWeightKg: 0, symbolName: "triangle.fill",  template: v4Thu),
            TemplateExercise(name: "哑铃后束飞鸟",     category: "肩部", order: 2, defaultSets: 3, defaultReps: 15, defaultWeightKg: 0, symbolName: "triangle.fill",  template: v4Thu),
            TemplateExercise(name: "哑铃集中弯举",     category: "手臂", order: 3, defaultSets: 4, defaultReps: 10, defaultWeightKg: 0, symbolName: "bolt.fill",      template: v4Thu),
            TemplateExercise(name: "绳索下压",         category: "手臂", order: 4, defaultSets: 4, defaultReps: 12, defaultWeightKg: 0, symbolName: "bolt.fill",      template: v4Thu)
        ]

        // 周五 · 平衡调和日
        let v4Fri = WorkoutTemplate(title: "v4-周五·平衡调和", category: "Balance", groupName: groupCycleV4, estimatedDuration: 65, level: "计划", sortOrder: 5)
        v4Fri.exercises = [
            TemplateExercise(name: "上斜哑铃飞鸟",       category: "胸部", order: 0, defaultSets: 3, defaultReps: 12, defaultWeightKg: 0, symbolName: "flame.fill",    template: v4Fri),
            TemplateExercise(name: "绳索夹胸（中位）",   category: "胸部", order: 1, defaultSets: 3, defaultReps: 15, defaultWeightKg: 0, symbolName: "flame.fill",    template: v4Fri),
            TemplateExercise(name: "器械夹胸",           category: "胸部", order: 2, defaultSets: 3, defaultReps: 15, defaultWeightKg: 0, symbolName: "flame.fill",    template: v4Fri),
            TemplateExercise(name: "绳索侧平举（单臂）", category: "肩部", order: 3, defaultSets: 4, defaultReps: 15, defaultWeightKg: 0, symbolName: "triangle.fill", template: v4Fri),
            TemplateExercise(name: "反向飞鸟（器械）",   category: "肩部", order: 4, defaultSets: 3, defaultReps: 15, defaultWeightKg: 0, symbolName: "triangle.fill", template: v4Fri),
            TemplateExercise(name: "弹力带二头弯举",     category: "手臂", order: 5, defaultSets: 3, defaultReps: 20, defaultWeightKg: 0, symbolName: "bolt.fill",     template: v4Fri),
            TemplateExercise(name: "木桩转体 Pallof Press", category: "核心", order: 6, defaultSets: 3, defaultReps: 12, defaultWeightKg: 0, symbolName: "bolt.fill",  template: v4Fri),
            TemplateExercise(name: "悬挂举腿",           category: "核心", order: 7, defaultSets: 3, defaultReps: 12, defaultWeightKg: 0, symbolName: "bolt.fill",     template: v4Fri)
        ]

        return [v4Mon, v4Tue, v4Wed, v4Thu, v4Fri]
    }

    private static func makeSessions() -> [WorkoutSession] {
        let activeSession = WorkoutSession(
            title: "今日自由训练",
            dateStarted: .now,
            workoutTimerStartedAt: nil,
            workoutElapsedOffset: 0,
            workoutIsRunning: false,
            notes: "保持动作控制，卧推最后两组注意发力。",
            templateName: nil,
            isCompleted: false,
            restStartTime: nil,
            restSourceSetID: nil,
            restTargetSeconds: 90,
            restElapsedOffset: 0,
            restIsPaused: false,
            restLastUpdatedAt: nil,
            restActualSeconds: nil
        )

        let bench = WorkoutExercise(name: "杠铃卧推", category: "胸部", order: 0, session: activeSession)
        bench.sets = [
            WorkoutSet(index: 1, targetReps: 10, actualReps: 10, weightKg: 60, isCompleted: true, completedAt: Calendar.current.date(byAdding: .minute, value: -6, to: .now), exercise: bench),
            WorkoutSet(index: 2, targetReps: 10, actualReps: 10, weightKg: 60, isCompleted: true, completedAt: Calendar.current.date(byAdding: .minute, value: -3, to: .now), exercise: bench),
            WorkoutSet(index: 3, targetReps: 8, actualReps: nil, weightKg: 65, exercise: bench),
            WorkoutSet(index: 4, targetReps: 8, actualReps: nil, weightKg: 65, exercise: bench)
        ]
        let fly = WorkoutExercise(name: "哑铃飞鸟", category: "胸部", order: 1, session: activeSession)
        fly.sets = [
            WorkoutSet(index: 1, targetReps: 12, weightKg: 14, exercise: fly),
            WorkoutSet(index: 2, targetReps: 12, weightKg: 14, exercise: fly),
            WorkoutSet(index: 3, targetReps: 10, weightKg: 16, exercise: fly)
        ]

        activeSession.exercises = [bench, fly]

        let historyDate = Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now
        let completedSession = WorkoutSession(
            title: "腿部日",
            dateStarted: Calendar.current.date(byAdding: .minute, value: -75, to: historyDate) ?? historyDate,
            dateEnded: historyDate,
            workoutTimerStartedAt: nil,
            workoutElapsedOffset: 75 * 60,
            workoutIsRunning: false,
            notes: "深蹲状态不错，下次把第三组提升到 102.5kg。",
            templateName: "硬核腿部轰炸",
            isCompleted: true
        )

        let squat = WorkoutExercise(name: "深蹲", category: "腿部", order: 0, session: completedSession)
        squat.sets = [
            WorkoutSet(index: 1, targetReps: 12, actualReps: 12, weightKg: 60, isCompleted: true, completedAt: Calendar.current.date(byAdding: .minute, value: -70, to: historyDate), exercise: squat),
            WorkoutSet(index: 2, targetReps: 10, actualReps: 10, weightKg: 80, isCompleted: true, completedAt: Calendar.current.date(byAdding: .minute, value: -62, to: historyDate), exercise: squat),
            WorkoutSet(index: 3, targetReps: 8, actualReps: 8, weightKg: 100, isCompleted: true, completedAt: Calendar.current.date(byAdding: .minute, value: -54, to: historyDate), exercise: squat),
            WorkoutSet(index: 4, targetReps: 6, actualReps: 6, weightKg: 100, isCompleted: true, completedAt: Calendar.current.date(byAdding: .minute, value: -46, to: historyDate), exercise: squat)
        ]

        let press = WorkoutExercise(name: "腿举", category: "腿部", order: 1, session: completedSession)
        press.sets = [
            WorkoutSet(index: 1, targetReps: 12, actualReps: 12, weightKg: 160, isCompleted: true, completedAt: Calendar.current.date(byAdding: .minute, value: -32, to: historyDate), exercise: press),
            WorkoutSet(index: 2, targetReps: 12, actualReps: 12, weightKg: 180, isCompleted: true, completedAt: Calendar.current.date(byAdding: .minute, value: -24, to: historyDate), exercise: press),
            WorkoutSet(index: 3, targetReps: 10, actualReps: 10, weightKg: 180, isCompleted: true, completedAt: Calendar.current.date(byAdding: .minute, value: -16, to: historyDate), exercise: press)
        ]

        completedSession.exercises = [squat, press]

        return [activeSession, completedSession]
    }
}
