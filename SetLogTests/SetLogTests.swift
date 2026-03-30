//
//  SetLogTests.swift
//  SetLogTests
//
//  Created by toka on 2026/03/13.
//

import Testing
import SwiftData
@testable import SetLog

struct SetLogTests {
    @MainActor @Test func sampleDataSeederCreatesCatalogAndSessions() throws {
        let schema = Schema([
            AppPreferences.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            WorkoutSet.self,
            ExerciseCatalogItem.self,
            WorkoutTemplate.self,
            TemplateExercise.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        try SampleDataSeeder.seedIfNeeded(in: container.mainContext)

        let catalog = try container.mainContext.fetch(FetchDescriptor<ExerciseCatalogItem>())
        let sessions = try container.mainContext.fetch(FetchDescriptor<WorkoutSession>())

        #expect(catalog.isEmpty == false)
        #expect(sessions.count >= 2)
        #expect(sessions.contains(where: { $0.isCompleted == false }))
    }
}
