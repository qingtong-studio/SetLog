//
//  SetLogApp.swift
//  SetLog
//
//  Created by toka on 2026/03/13.
//

import SwiftUI
import SwiftData

@main
struct SetLogApp: App {
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            WorkoutExercise.self,
            WorkoutSet.self,
            ExerciseCatalogItem.self,
            WorkoutTemplate.self,
            TemplateExercise.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try makeModelContainer(schema: schema, configuration: modelConfiguration)
            try SampleDataSeeder.seedIfNeeded(in: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }

    private static func makeModelContainer(
        schema: Schema,
        configuration: ModelConfiguration
    ) throws -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Early development fallback: reset an incompatible local store after schema changes.
            try resetStore(at: configuration.url)
            return try ModelContainer(for: schema, configurations: [configuration])
        }
    }

    private static func resetStore(at url: URL) throws {
        let fileManager = FileManager.default
        let relatedURLs = [
            url,
            url.appendingPathExtension("shm"),
            url.appendingPathExtension("wal")
        ]

        for relatedURL in relatedURLs where fileManager.fileExists(atPath: relatedURL.path) {
            try fileManager.removeItem(at: relatedURL)
        }
    }
}
