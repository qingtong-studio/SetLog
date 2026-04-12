//
//  SetLogApp.swift
//  SetLog
//
//  Created by toka on 2026/03/13.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct SetLogApp: App {
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AppPreferences.self,
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
            try ensureAppPreferences(in: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    requestNotificationPermission()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private static func makeModelContainer(
        schema: Schema,
        configuration: ModelConfiguration
    ) throws -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            #if DEBUG
            // Early development fallback: reset an incompatible local store after schema changes.
            try resetStore(at: configuration.url)
            return try ModelContainer(for: schema, configurations: [configuration])
            #else
            throw error
            #endif
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

    private static func ensureAppPreferences(in context: ModelContext) throws {
        var descriptor = FetchDescriptor<AppPreferences>()
        descriptor.fetchLimit = 1

        if try context.fetch(descriptor).isEmpty {
            context.insert(AppPreferences())
            try context.save()
        }
    }
}
