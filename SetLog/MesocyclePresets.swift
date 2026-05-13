import Foundation

struct PhasePreset {
    let phase: String
    let label: String
    let totalWeeks: Int
    let weekMultipliers: [Double]
    let rpeCap: Double
    let repsLow: Int
    let repsHigh: Int
}

enum MacroPresetKind: String, CaseIterable, Identifiable {
    case classic16 = "classic16"
    case eightWeek = "eightWeek"
    case empty = "empty"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic16: return "增肌→力量→峰值→走量"
        case .eightWeek: return "增肌+力量"
        case .empty:     return "从空开始"
        }
    }

    var phases: [PhasePreset] {
        switch self {
        case .classic16: return MacroPreset.classic16Week
        case .eightWeek: return MacroPreset.eightWeek
        case .empty:     return []
        }
    }
}

enum MacroPreset {
    static let classic16Week: [PhasePreset] = [
        PhasePreset(
            phase: "hypertrophy", label: "增肌", totalWeeks: 4,
            weekMultipliers: [1.00, 1.025, 1.05, 0.60],
            rpeCap: 8.0, repsLow: 8, repsHigh: 12
        ),
        PhasePreset(
            phase: "strength", label: "力量", totalWeeks: 4,
            weekMultipliers: [1.00, 1.025, 1.05, 0.60],
            rpeCap: 9.0, repsLow: 4, repsHigh: 6
        ),
        PhasePreset(
            phase: "peaking", label: "峰值", totalWeeks: 4,
            weekMultipliers: [1.00, 1.025, 1.05, 0.60],
            rpeCap: 9.5, repsLow: 1, repsHigh: 3
        ),
        PhasePreset(
            phase: "volume", label: "走量", totalWeeks: 4,
            weekMultipliers: [1.00, 1.025, 1.05, 0.60],
            rpeCap: 7.0, repsLow: 12, repsHigh: 20
        )
    ]

    static let eightWeek: [PhasePreset] = [
        PhasePreset(
            phase: "hypertrophy", label: "增肌", totalWeeks: 4,
            weekMultipliers: [1.00, 1.025, 1.05, 0.60],
            rpeCap: 8.0, repsLow: 8, repsHigh: 12
        ),
        PhasePreset(
            phase: "strength", label: "力量", totalWeeks: 4,
            weekMultipliers: [1.00, 1.025, 1.05, 0.60],
            rpeCap: 9.0, repsLow: 4, repsHigh: 6
        )
    ]
}
