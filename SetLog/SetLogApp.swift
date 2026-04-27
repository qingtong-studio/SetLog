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
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
            // cloudKitDatabase: .private("iCloud.dahuang.SetLog") // 暂时禁用 iCloud 同步
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await bootstrapAfterCloudSync()
                    requestNotificationPermission()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    @MainActor
    private func bootstrapAfterCloudSync() async {
        // Give CloudKit a brief window to pull existing records before we
        // decide whether to seed defaults. Without this, a fresh reinstall
        // on an iCloud-backed account would race the sync and duplicate
        // seed data locally.
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        let context = sharedModelContainer.mainContext
        do {
            try ensureAppPreferences(in: context)
            try SampleDataSeeder.seedIfNeeded(in: context)
        } catch {
            #if DEBUG
            print("SetLog bootstrap error: \(error)")
            #endif
        }
    }

    @MainActor
    private func ensureAppPreferences(in context: ModelContext) throws {
        var descriptor = FetchDescriptor<AppPreferences>()
        descriptor.fetchLimit = 1

        if try context.fetch(descriptor).isEmpty {
            context.insert(AppPreferences())
            try context.save()
        }
    }
}
