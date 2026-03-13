import Foundation
import SwiftData

enum WeightUnit: String, Codable, CaseIterable {
    case kilogram = "KG"
    case pound = "LB"
}

@Model
final class WorkoutSession {
    var id: UUID
    var title: String
    var dateStarted: Date
    var dateEnded: Date?
    var workoutTimerStartedAt: Date?
    var workoutElapsedOffset: TimeInterval
    var workoutIsRunning: Bool
    var notes: String
    var templateName: String?
    var isCompleted: Bool
    var restStartTime: Date?
    var restSourceSetID: UUID?
    var restTargetSeconds: Int
    var restElapsedOffset: TimeInterval
    var restIsPaused: Bool
    var restLastUpdatedAt: Date?
    var restActualSeconds: Int?
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.session)
    var exercises: [WorkoutExercise]

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
    var id: UUID
    var name: String
    var category: String
    var order: Int
    var notes: String
    var session: WorkoutSession?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet]

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        order: Int,
        notes: String = "",
        session: WorkoutSession? = nil,
        sets: [WorkoutSet] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.order = order
        self.notes = notes
        self.session = session
        self.sets = sets
    }
}

@Model
final class WorkoutSet {
    var id: UUID
    var index: Int
    var targetReps: Int?
    var actualReps: Int?
    var weightKg: Double
    var restAfter: TimeInterval
    var recordedRestSeconds: Int?
    var isCompleted: Bool
    var completedAt: Date?
    var exercise: WorkoutExercise?

    init(
        id: UUID = UUID(),
        index: Int,
        targetReps: Int? = nil,
        actualReps: Int? = nil,
        weightKg: Double = 0,
        restAfter: TimeInterval = 90,
        recordedRestSeconds: Int? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        exercise: WorkoutExercise? = nil
    ) {
        self.id = id
        self.index = index
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.weightKg = weightKg
        self.restAfter = restAfter
        self.recordedRestSeconds = recordedRestSeconds
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.exercise = exercise
    }
}

@Model
final class ExerciseCatalogItem {
    var id: UUID
    var name: String
    var category: String
    var targetMuscle: String
    var defaultSets: Int
    var defaultReps: Int
    var defaultWeightKg: Double
    var symbolName: String
    var tintName: String
    var createdAt: Date

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
    var id: UUID
    var title: String
    var category: String
    var estimatedDuration: Int
    var level: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise]

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        estimatedDuration: Int,
        level: String,
        createdAt: Date = .now,
        exercises: [TemplateExercise] = []
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.estimatedDuration = estimatedDuration
        self.level = level
        self.createdAt = createdAt
        self.exercises = exercises
    }
}

@Model
final class TemplateExercise {
    var id: UUID
    var name: String
    var category: String
    var order: Int
    var defaultSets: Int
    var defaultReps: Int
    var defaultWeightKg: Double
    var symbolName: String
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
        exercises.sorted { $0.order < $1.order }
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
        sets.sorted { $0.index < $1.index }
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
        orderedSets.filter(\.isCompleted).reduce(0) { partialResult, set in
            partialResult + (set.weightKg * Double(set.actualReps ?? set.targetReps ?? 0))
        }
    }
}

extension WorkoutSet {
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
}

enum SampleDataSeeder {
    static func seedIfNeeded(in context: ModelContext) throws {
        var catalogDescriptor = FetchDescriptor<ExerciseCatalogItem>()
        catalogDescriptor.fetchLimit = 1

        if try !context.fetch(catalogDescriptor).isEmpty {
            return
        }

        let catalogItems = makeCatalogItems()
        let templates = makeTemplates()
        let sessions = makeSessions()

        for item in catalogItems {
            context.insert(item)
        }

        for template in templates {
            context.insert(template)
        }

        for session in sessions {
            context.insert(session)
        }

        try context.save()
    }

    private static func makeCatalogItems() -> [ExerciseCatalogItem] {
        [
            ExerciseCatalogItem(name: "杠铃卧推", category: "胸部", targetMuscle: "胸大肌", defaultSets: 4, defaultReps: 8, defaultWeightKg: 60, symbolName: "flame.fill", tintName: "orange"),
            ExerciseCatalogItem(name: "深蹲", category: "腿部", targetMuscle: "股四头肌", defaultSets: 4, defaultReps: 6, defaultWeightKg: 100, symbolName: "figure.strengthtraining.traditional", tintName: "blue"),
            ExerciseCatalogItem(name: "硬拉", category: "背部", targetMuscle: "后侧链", defaultSets: 3, defaultReps: 5, defaultWeightKg: 120, symbolName: "mountain.2.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "引体向上", category: "背部", targetMuscle: "背阔肌", defaultSets: 4, defaultReps: 8, defaultWeightKg: 0, symbolName: "figure.pull.up", tintName: "mint"),
            ExerciseCatalogItem(name: "肩推", category: "肩部", targetMuscle: "三角肌", defaultSets: 3, defaultReps: 10, defaultWeightKg: 30, symbolName: "triangle.fill", tintName: "gray"),
            ExerciseCatalogItem(name: "哑铃弯举", category: "手臂", targetMuscle: "肱二头肌", defaultSets: 3, defaultReps: 12, defaultWeightKg: 12.5, symbolName: "bolt.fill", tintName: "purple")
        ]
    }

    private static func makeTemplates() -> [WorkoutTemplate] {
        let pushTemplate = WorkoutTemplate(title: "经典胸肌与肱三头肌训练", category: "力量", estimatedDuration: 65, level: "进阶")
        pushTemplate.exercises = [
            TemplateExercise(name: "杠铃卧推", category: "胸部", order: 0, defaultSets: 4, defaultReps: 8, defaultWeightKg: 60, symbolName: "flame.fill", template: pushTemplate),
            TemplateExercise(name: "肩推", category: "肩部", order: 1, defaultSets: 3, defaultReps: 10, defaultWeightKg: 30, symbolName: "triangle.fill", template: pushTemplate)
        ]

        let legTemplate = WorkoutTemplate(title: "硬核腿部轰炸", category: "力量", estimatedDuration: 75, level: "专业")
        legTemplate.exercises = [
            TemplateExercise(name: "深蹲", category: "腿部", order: 0, defaultSets: 4, defaultReps: 6, defaultWeightKg: 100, symbolName: "figure.strengthtraining.traditional", template: legTemplate),
            TemplateExercise(name: "硬拉", category: "背部", order: 1, defaultSets: 3, defaultReps: 5, defaultWeightKg: 120, symbolName: "mountain.2.fill", template: legTemplate)
        ]

        return [pushTemplate, legTemplate]
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
