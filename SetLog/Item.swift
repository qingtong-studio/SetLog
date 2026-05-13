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

/// Mode chosen when a workout session is started. Acts as the extensible
/// interface for adjusting how a session reads/writes data ("减载模式" being
/// the first non-default mode). Add a case here and update
/// `WorkoutStartModeBehavior` to introduce a new mode.
enum WorkoutStartMode: String, Codable, CaseIterable {
    case normal
    case deload

    var displayName: String {
        switch self {
        case .normal: return "正常"
        case .deload: return "减载"
        }
    }
}

/// Per-mode behavior knobs. Future modes extend this with new toggles
/// (e.g. `volumeMultiplier`, `repAdjustment`) so callers stay decoupled
/// from the raw mode value.
struct WorkoutStartModeBehavior {
    /// Whether completing the session should overwrite each exercise's
    /// preferred weight / rest in the catalog.
    let persistsPreferredWeights: Bool
    /// Whether saving back to the source template is allowed for this mode.
    let allowsTemplateSaveBack: Bool

    static func behavior(for mode: WorkoutStartMode) -> WorkoutStartModeBehavior {
        switch mode {
        case .normal:
            return .init(persistsPreferredWeights: true, allowsTemplateSaveBack: true)
        case .deload:
            return .init(persistsPreferredWeights: false, allowsTemplateSaveBack: false)
        }
    }
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
    var bodyweightKg: Double?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        weightUnit: WeightUnit = .kilogram,
        notificationsEnabled: Bool = true,
        hasSeededDefaults: Bool = false,
        seedVersion: Int = 0,
        bodyweightKg: Double? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.weightUnitRawValue = weightUnit.rawValue
        self.notificationsEnabled = notificationsEnabled
        self.hasSeededDefaults = hasSeededDefaults
        self.seedVersion = seedVersion
        self.bodyweightKg = bodyweightKg
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
    var startModeRawValue: String = WorkoutStartMode.normal.rawValue
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var macrocycleProgramID: UUID?
    var mesocycleID: UUID?
    var mesocyclePhase: String?
    var mesocycleWeekIndex: Int?
    var mesocycleDayIndex: Int?
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
        startMode: WorkoutStartMode = .normal,
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
        self.startModeRawValue = startMode.rawValue
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
    var bodyweightKg: Double?
    var includesBodyweight: Bool = false
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
        bodyweightKg: Double? = nil,
        includesBodyweight: Bool = false,
        session: WorkoutSession? = nil,
        sets: [WorkoutSet] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.order = order
        self.notes = notes
        self.weightModeRawValue = weightModeRawValue
        self.bodyweightKg = bodyweightKg
        self.includesBodyweight = includesBodyweight
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

    // Personal preferences updated after each completed workout.
    var preferredWeightKg: Double?
    var preferredWeightModeRawValue: String?
    var preferredRestSeconds: Int?

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

    var preferredWeightMode: ExerciseWeightMode? {
        get { preferredWeightModeRawValue.flatMap(ExerciseWeightMode.init(rawValue:)) }
        set { preferredWeightModeRawValue = newValue?.rawValue }
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

// MARK: - Daily Plan (single-day template overrides)

/// One-time per-day overrides for a template, used when the user wants to
/// adjust weights/sets/reps for a single training day (e.g. deload week)
/// without permanently modifying the template defaults. Created from the
/// template detail view; consumed when starting today's workout; deleted
/// automatically once that workout completes.
@Model
final class DailyPlan {
    var id: UUID = UUID()
    var date: Date = Date.now
    var templateID: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \DailyPlanExercise.plan)
    var exercises: [DailyPlanExercise]? = []

    init(
        id: UUID = UUID(),
        date: Date = DailyPlan.startOfToday(),
        templateID: UUID,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        exercises: [DailyPlanExercise] = []
    ) {
        self.id = id
        self.date = date
        self.templateID = templateID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.exercises = exercises
    }
}

@Model
final class DailyPlanExercise {
    var id: UUID = UUID()
    var exerciseName: String = ""
    var order: Int = 0
    var sets: Int = 0
    var reps: Int = 0
    var weightKg: Double = 0
    var plan: DailyPlan?

    init(
        id: UUID = UUID(),
        exerciseName: String,
        order: Int,
        sets: Int,
        reps: Int,
        weightKg: Double,
        plan: DailyPlan? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.order = order
        self.sets = sets
        self.reps = reps
        self.weightKg = weightKg
        self.plan = plan
    }
}

extension DailyPlan {
    static func startOfToday(_ now: Date = .now) -> Date {
        Calendar.current.startOfDay(for: now)
    }

    static func findTodayPlan(templateID: UUID, in context: ModelContext) -> DailyPlan? {
        let dayStart = startOfToday()
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }
        var descriptor = FetchDescriptor<DailyPlan>(
            predicate: #Predicate { plan in
                plan.templateID == templateID && plan.date >= dayStart && plan.date < dayEnd
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    var orderedExercises: [DailyPlanExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }
}

// MARK: - Periodization (Macro / Meso)

@Model
final class MacrocycleProgram {
    var id: UUID = UUID()
    var title: String = ""
    var startDate: Date = Date.now
    var isActive: Bool = false
    var createdAt: Date = Date.now
    var endedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \Mesocycle.macro)
    var mesocycles: [Mesocycle]? = []

    init(
        id: UUID = UUID(),
        title: String = "",
        startDate: Date = .now,
        isActive: Bool = false,
        createdAt: Date = .now,
        endedAt: Date? = nil,
        mesocycles: [Mesocycle] = []
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.isActive = isActive
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.mesocycles = mesocycles
    }
}

@Model
final class Mesocycle {
    var id: UUID = UUID()
    var order: Int = 0
    var phase: String = "hypertrophy"
    var phaseLabel: String = "增肌"
    var totalWeeks: Int = 4
    var daysPerWeek: Int = 4
    var defaultRpeCap: Double = 8.0
    var targetRepsLow: Int = 8
    var targetRepsHigh: Int = 12
    var notes: String = ""
    var macro: MacrocycleProgram?
    @Relationship(deleteRule: .cascade, inverse: \MesocycleWeek.meso)
    var weeks: [MesocycleWeek]? = []
    @Relationship(deleteRule: .cascade, inverse: \MesocycleDay.meso)
    var days: [MesocycleDay]? = []

    init(
        id: UUID = UUID(),
        order: Int = 0,
        phase: String = "hypertrophy",
        phaseLabel: String = "增肌",
        totalWeeks: Int = 4,
        daysPerWeek: Int = 4,
        defaultRpeCap: Double = 8.0,
        targetRepsLow: Int = 8,
        targetRepsHigh: Int = 12,
        notes: String = "",
        macro: MacrocycleProgram? = nil,
        weeks: [MesocycleWeek] = [],
        days: [MesocycleDay] = []
    ) {
        self.id = id
        self.order = order
        self.phase = phase
        self.phaseLabel = phaseLabel
        self.totalWeeks = totalWeeks
        self.daysPerWeek = daysPerWeek
        self.defaultRpeCap = defaultRpeCap
        self.targetRepsLow = targetRepsLow
        self.targetRepsHigh = targetRepsHigh
        self.notes = notes
        self.macro = macro
        self.weeks = weeks
        self.days = days
    }
}

@Model
final class MesocycleWeek {
    var id: UUID = UUID()
    var weekIndex: Int = 0
    var loadMultiplier: Double = 1.0
    var isDeload: Bool = false
    var meso: Mesocycle?

    init(
        id: UUID = UUID(),
        weekIndex: Int,
        loadMultiplier: Double,
        isDeload: Bool,
        meso: Mesocycle? = nil
    ) {
        self.id = id
        self.weekIndex = weekIndex
        self.loadMultiplier = loadMultiplier
        self.isDeload = isDeload
        self.meso = meso
    }
}

@Model
final class MesocycleDay {
    var id: UUID = UUID()
    var dayIndex: Int = 0
    var label: String = ""
    var templateID: UUID?
    var meso: Mesocycle?

    init(
        id: UUID = UUID(),
        dayIndex: Int,
        label: String,
        templateID: UUID? = nil,
        meso: Mesocycle? = nil
    ) {
        self.id = id
        self.dayIndex = dayIndex
        self.label = label
        self.templateID = templateID
        self.meso = meso
    }
}

extension MacrocycleProgram {
    var orderedMesocycles: [Mesocycle] {
        (mesocycles ?? []).sorted { $0.order < $1.order }
    }
}

extension Mesocycle {
    var orderedWeeks: [MesocycleWeek] {
        (weeks ?? []).sorted { $0.weekIndex < $1.weekIndex }
    }

    var orderedDays: [MesocycleDay] {
        (days ?? []).sorted { $0.dayIndex < $1.dayIndex }
    }
}

extension WorkoutSession {
    var startMode: WorkoutStartMode {
        get { WorkoutStartMode(rawValue: startModeRawValue) ?? .normal }
        set { startModeRawValue = newValue.rawValue }
    }

    var startModeBehavior: WorkoutStartModeBehavior {
        WorkoutStartModeBehavior.behavior(for: startMode)
    }

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
        let bw = includesBodyweight ? (bodyweightKg ?? 0) : 0
        return orderedSets.filter(\.isCompleted).reduce(0) { result, set in
            let reps = Double(set.actualReps ?? set.targetReps ?? 0)
            var effective = mode == .singleHand ? set.weightKg * 2 : set.weightKg
            effective += bw
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

    func effectiveLoadKg(for exercise: WorkoutExercise) -> Double {
        let base = effectiveWeightKg(mode: exercise.weightMode)
        let bw = exercise.includesBodyweight ? (exercise.bodyweightKg ?? 0) : 0
        return base + bw
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

// MARK: - Personal preferences

enum ExercisePreferences {
    /// Update each catalog item's personal preferences (weight, single-hand mode,
    /// rest seconds) based on the latest completed work in the session. Should be
    /// called once when a workout is marked completed.
    static func apply(from session: WorkoutSession, in context: ModelContext) {
        guard session.startModeBehavior.persistsPreferredWeights else { return }
        for exercise in session.orderedExercises {
            let workingSets = exercise.workingSets.filter(\.isCompleted)
            guard !workingSets.isEmpty else { continue }

            let trimmedName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }

            var descriptor = FetchDescriptor<ExerciseCatalogItem>(
                predicate: #Predicate { $0.name == trimmedName }
            )
            descriptor.fetchLimit = 1
            guard let catalogItem = try? context.fetch(descriptor).first else { continue }

            let topSet = workingSets.max { $0.weightKg < $1.weightKg }
            if let topSet, topSet.weightKg > 0 {
                catalogItem.preferredWeightKg = topSet.weightKg
            }
            catalogItem.preferredWeightModeRawValue = exercise.weightMode.rawValue
            if let firstRest = workingSets.first.map({ Int($0.restAfter) }), firstRest > 0 {
                catalogItem.preferredRestSeconds = firstRest
            }
        }
    }
}

// MARK: - Export

enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case csv
    case json

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .csv: return "csv"
        case .json: return "json"
        }
    }

    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .csv: return "CSV"
        case .json: return "JSON"
        }
    }
}

enum ExportDateRange: Hashable, Identifiable {
    case all
    case last7Days
    case last30Days
    case custom(start: Date, end: Date)

    var id: String {
        switch self {
        case .all: return "all"
        case .last7Days: return "last7"
        case .last30Days: return "last30"
        case .custom: return "custom"
        }
    }

    var displayName: String {
        switch self {
        case .all: return "全部"
        case .last7Days: return "近 7 天"
        case .last30Days: return "近 30 天"
        case .custom: return "自定义"
        }
    }

    static var presets: [ExportDateRange] {
        [.all, .last7Days, .last30Days]
    }

    func filter(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        let completed = sessions.filter { $0.isCompleted }
        switch self {
        case .all:
            return completed
        case .last7Days:
            let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return completed.filter { $0.dateStarted >= cutoff }
        case .last30Days:
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            return completed.filter { $0.dateStarted >= cutoff }
        case .custom(let start, let end):
            let lo = min(start, end)
            let hi = max(start, end)
            let startOfDay = Calendar.current.startOfDay(for: lo)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: hi)) ?? hi
            return completed.filter { $0.dateStarted >= startOfDay && $0.dateStarted < endOfDay }
        }
    }
}

extension WorkoutSession {
    func exportMarkdown(unit: WeightUnit) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        let durationMin = max(1, Int((dateEnded ?? dateStarted).timeIntervalSince(dateStarted) / 60))

        var md = "## \(dateFormatter.string(from: dateStarted)) - \(title)\n"
        md += "时长: \(durationMin)分钟 | 总组数: \(totalSetCount) | 总容量: \(totalVolumeKg.formattedVolume(unit: unit))\n\n"

        let unitSymbol = unit.displaySymbol.lowercased()
        for exercise in orderedExercises {
            var headerExtras: [String] = []
            if exercise.weightMode == .singleHand {
                headerExtras.append("单边模式")
            }
            if exercise.includesBodyweight, let bw = exercise.bodyweightKg, bw > 0 {
                headerExtras.append("含自重 \(bw.formattedWeight(unit: unit)) \(unitSymbol)")
            }
            let extrasLabel = headerExtras.isEmpty ? "" : " [\(headerExtras.joined(separator: " · "))]"
            md += "### \(exercise.name) (\(exercise.category))\(extrasLabel)\n"
            md += "| 组 | 类型 | 重量(\(unitSymbol)) | 次数 | RPE | 休息(s) |\n"
            md += "|----|------|----------|------|-----|--------|\n"
            for set in exercise.orderedSets {
                let typeLabel = set.isWarmup ? "热身" : "正式"
                let weight = set.weightKg.formattedWeight(unit: unit)
                let reps = set.actualReps ?? set.targetReps ?? 0
                let rpe = set.rpe.map { "\($0)" } ?? "-"
                let rest = set.recordedRestSeconds.map { "\($0)" } ?? "-"
                md += "| \(set.index) | \(typeLabel) | \(weight) | \(reps) | \(rpe) | \(rest) |\n"
            }
            md += "\n"

            let trimmedExNotes = exercise.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedExNotes.isEmpty {
                md += "> 备注: \(trimmedExNotes)\n\n"
            }
        }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            md += "备注: \(trimmedNotes)\n\n"
        }
        return md
    }
}

extension Array where Element == WorkoutSession {
    private var sortedForExport: [WorkoutSession] {
        self.sorted { $0.dateStarted < $1.dateStarted }
    }

    func generateExportContent(unit: WeightUnit) -> String {
        generateExportContent(unit: unit, progress: nil)
    }

    @MainActor
    func generateExportContent(unit: WeightUnit, progress: ((Double) -> Void)?) -> String {
        let sorted = sortedForExport

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        var md = "# SetLog 训练记录导出\n"
        md += "导出时间: \(dateFormatter.string(from: Date()))\n"
        md += "总训练次数: \(sorted.count)"
        let totalVolume = sorted.reduce(0.0) { $0 + $1.totalVolumeKg }
        md += " | 总容量: \(totalVolume.formattedVolume(unit: unit))\n\n"
        md += "---\n\n"

        let total = Swift.max(1, sorted.count)
        for (idx, session) in sorted.enumerated() {
            md += session.exportMarkdown(unit: unit)
            md += "---\n\n"
            progress?(Double(idx + 1) / Double(total))
        }

        return md
    }

    func generateCSV(unit: WeightUnit) -> String {
        generateCSV(unit: unit, progress: nil)
    }

    @MainActor
    func generateCSV(unit: WeightUnit, progress: ((Double) -> Void)?) -> String {
        let unitSymbol = unit.displaySymbol.lowercased()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        var rows: [String] = []
        rows.append([
            "日期", "会话标题", "动作", "分类", "重量模式", "含自重",
            "组号", "类型", "重量(\(unitSymbol))", "次数", "RPE", "休息(s)",
            "动作备注", "会话备注"
        ].joined(separator: ","))

        let sorted = sortedForExport
        let total = Swift.max(1, sorted.count)
        for (idx, session) in sorted.enumerated() {
            let dateStr = dateFormatter.string(from: session.dateStarted)
            let title = session.title
            let sessionNotes = session.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            for exercise in session.orderedExercises {
                let mode = exercise.weightMode.displayName
                let bw: String
                if exercise.includesBodyweight, let v = exercise.bodyweightKg, v > 0 {
                    bw = "是(\(v.formattedWeight(unit: unit))\(unitSymbol))"
                } else {
                    bw = "否"
                }
                let exNotes = exercise.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                for set in exercise.orderedSets {
                    let typeLabel = set.isWarmup ? "热身" : "正式"
                    let weight = set.weightKg.formattedWeight(unit: unit)
                    let reps = set.actualReps ?? set.targetReps ?? 0
                    let rpe = set.rpe.map { "\($0)" } ?? ""
                    let rest = set.recordedRestSeconds.map { "\($0)" } ?? ""
                    let fields: [String] = [
                        dateStr, title, exercise.name, exercise.category, mode, bw,
                        "\(set.index)", typeLabel, weight, "\(reps)", rpe, rest,
                        exNotes, sessionNotes
                    ]
                    rows.append(fields.map(csvEscape).joined(separator: ","))
                }
            }
            progress?(Double(idx + 1) / Double(total))
        }

        // Prepend BOM so Excel detects UTF-8 correctly.
        return "\u{FEFF}" + rows.joined(separator: "\r\n") + "\r\n"
    }

    func generateJSON(unit: WeightUnit) -> Data {
        let dto = ExportRootDTO(
            exportedAt: Date(),
            unit: unit.rawValue,
            totalSessions: sortedForExport.count,
            totalVolume: sortedForExport.reduce(0.0) { $0 + $1.totalVolumeKg }
                .convertedWeight(from: .kilogram, to: unit),
            sessions: sortedForExport.map { ExportSessionDTO(session: $0, unit: unit) }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(dto)) ?? Data("{}".utf8)
    }
}

private func csvEscape(_ value: String) -> String {
    if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    return value
}

private struct ExportRootDTO: Encodable {
    let exportedAt: Date
    let unit: String
    let totalSessions: Int
    let totalVolume: Double
    let sessions: [ExportSessionDTO]
}

private struct ExportSessionDTO: Encodable {
    let id: String
    let title: String
    let dateStarted: Date
    let dateEnded: Date?
    let durationSeconds: Int
    let templateName: String?
    let notes: String
    let totalSets: Int
    let totalVolume: Double
    let exercises: [ExportExerciseDTO]

    init(session: WorkoutSession, unit: WeightUnit) {
        self.id = session.id.uuidString
        self.title = session.title
        self.dateStarted = session.dateStarted
        self.dateEnded = session.dateEnded
        let end = session.dateEnded ?? session.dateStarted
        self.durationSeconds = max(0, Int(end.timeIntervalSince(session.dateStarted)))
        self.templateName = session.templateName
        self.notes = session.notes
        self.totalSets = session.totalSetCount
        self.totalVolume = session.totalVolumeKg.convertedWeight(from: .kilogram, to: unit)
        self.exercises = session.orderedExercises.map { ExportExerciseDTO(exercise: $0, unit: unit) }
    }
}

private struct ExportExerciseDTO: Encodable {
    let id: String
    let name: String
    let category: String
    let order: Int
    let weightMode: String
    let includesBodyweight: Bool
    let bodyweightInUnit: Double?
    let notes: String
    let sets: [ExportSetDTO]

    init(exercise: WorkoutExercise, unit: WeightUnit) {
        self.id = exercise.id.uuidString
        self.name = exercise.name
        self.category = exercise.category
        self.order = exercise.order
        self.weightMode = exercise.weightMode.rawValue
        self.includesBodyweight = exercise.includesBodyweight
        self.bodyweightInUnit = exercise.bodyweightKg?.convertedWeight(from: .kilogram, to: unit)
        self.notes = exercise.notes
        self.sets = exercise.orderedSets.map { ExportSetDTO(set: $0, unit: unit) }
    }
}

private struct ExportSetDTO: Encodable {
    let index: Int
    let setType: String
    let targetReps: Int?
    let actualReps: Int?
    let weight: Double
    let weightUnit: String
    let rpe: Int?
    let restSeconds: Int?
    let isCompleted: Bool
    let completedAt: Date?

    init(set: WorkoutSet, unit: WeightUnit) {
        self.index = set.index
        self.setType = set.setType.rawValue
        self.targetReps = set.targetReps
        self.actualReps = set.actualReps
        self.weight = set.weightKg.convertedWeight(from: .kilogram, to: unit)
        self.weightUnit = unit.rawValue
        self.rpe = set.rpe
        self.restSeconds = set.recordedRestSeconds
        self.isCompleted = set.isCompleted
        self.completedAt = set.completedAt
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
