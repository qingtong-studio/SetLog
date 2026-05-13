import Foundation

struct CyclePointer {
    let macro: MacrocycleProgram
    let meso: Mesocycle
    let weekIndex: Int
    let dayIndex: Int          // 0..daysPerWeek-1 = 训练日；otherwise rest
    let isRestDay: Bool

    var weekMultiplier: Double {
        meso.orderedWeeks.first(where: { $0.weekIndex == weekIndex })?.loadMultiplier ?? 1.0
    }

    var isDeload: Bool {
        meso.orderedWeeks.first(where: { $0.weekIndex == weekIndex })?.isDeload ?? false
    }

    var todayDay: MesocycleDay? {
        guard !isRestDay else { return nil }
        return meso.orderedDays.first(where: { $0.dayIndex == dayIndex })
    }
}

extension MacrocycleProgram {
    /// Day index from program start (>= 0); nil when before start.
    func dayOffset(on date: Date, calendar: Calendar = .current) -> Int? {
        let startDay = calendar.startOfDay(for: startDate)
        let target = calendar.startOfDay(for: date)
        guard target >= startDay else { return nil }
        let comps = calendar.dateComponents([.day], from: startDay, to: target)
        return comps.day
    }

    /// Today's macro position. Returns nil if before start or after the macro
    /// has finished (sum of all mesocycle weeks * 7 days).
    func locate(on date: Date, calendar: Calendar = .current) -> CyclePointer? {
        guard let offset = dayOffset(on: date, calendar: calendar) else { return nil }

        var remaining = offset
        for meso in orderedMesocycles {
            let mesoDays = meso.totalWeeks * 7
            if remaining < mesoDays {
                let weekIndex = remaining / 7
                let dayInWeek = remaining % 7
                let isRest = dayInWeek >= meso.daysPerWeek
                return CyclePointer(
                    macro: self,
                    meso: meso,
                    weekIndex: weekIndex,
                    dayIndex: dayInWeek,
                    isRestDay: isRest
                )
            }
            remaining -= mesoDays
        }
        return nil
    }
}

extension Mesocycle {
    func suggestedWeight(forBaseKg base: Double, weekIndex: Int) -> Double {
        let mult = orderedWeeks.first(where: { $0.weekIndex == weekIndex })?.loadMultiplier ?? 1.0
        return base * mult
    }
}
