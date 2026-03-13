import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ExerciseCatalogItem.createdAt)]) private var exercises: [ExerciseCatalogItem]

    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    @State private var selectedExerciseIDs: [UUID] = []

    let session: WorkoutSession

    private let categories = ["全部", "胸部", "腿部", "背部", "肩部", "手臂"]

    private var filteredExercises: [ExerciseCatalogItem] {
        exercises.filter { exercise in
            let matchesCategory = selectedCategory == "全部" || exercise.category == selectedCategory
            let matchesSearch = searchText.isEmpty ||
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.targetMuscle.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    private var selectedExercise: ExerciseCatalogItem? {
        guard let selectedExerciseID = selectedExerciseIDs.last else {
            return filteredExercises.first ?? exercises.first
        }
        return exercises.first(where: { $0.id == selectedExerciseID }) ?? filteredExercises.first ?? exercises.first
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    searchBar
                    categoryTabs
                    exerciseList
                    defaultSettingsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            confirmButton
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .background(.white)
        }
        .background(Color(.systemGray6))
        .navigationBarHidden(true)
        .onAppear {
        }
    }

    private var topBar: some View {
        ZStack {
            Text("添加动作")
                .font(.system(size: 18, weight: .semibold))

            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button("自定义", action: {})
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(.white)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("搜索动作名称...", text: $searchText)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(Color(.systemGray5).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        Text(category)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(selectedCategory == category ? .white : .secondary)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(selectedCategory == category ? Color.black : Color(.systemGray5).opacity(0.4))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("常用动作")
                .font(.system(size: 14, weight: .bold))

            VStack(spacing: 10) {
                ForEach(filteredExercises) { exercise in
                    Button(action: {
                        toggleSelection(for: exercise.id)
                    }) {
                        ExerciseOptionRow(
                            exercise: exercise,
                            selectionIndex: selectedExerciseIDs.firstIndex(of: exercise.id)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var defaultSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "figure.strengthtraining.traditional")
                    Text("默认参数设置")
                        .font(.system(size: 14, weight: .bold))
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("KG")
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 26)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text("LB")
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 26)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .font(.system(size: 11, weight: .bold))
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(summaryText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ParameterField(title: "组数 (Sets)", value: "\(selectedExercise?.defaultSets ?? 0)")
                ParameterField(title: "次数 (Reps)", value: "\(selectedExercise?.defaultReps ?? 0)")
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("初始重量 (KG)", systemImage: "scalemass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text("KG")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(weightText(selectedExercise?.defaultWeightKg ?? 0))
                        .font(.system(size: 26, weight: .black, design: .rounded))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 54)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    private var confirmButton: some View {
        Button(action: addSelectedExercise) {
            HStack(spacing: 8) {
                Text("确认添加动作")
                    .font(.system(size: 16, weight: .semibold))
                if !selectedExerciseIDs.isEmpty {
                    Text("(\(selectedExerciseIDs.count))")
                        .font(.system(size: 15, weight: .bold))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(selectedExerciseIDs.isEmpty ? Color.gray : Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(selectedExerciseIDs.isEmpty)
    }

    private var summaryText: String {
        guard let selectedExercise else {
            return "请选择一个或多个动作。"
        }
        return "已选择 \(selectedExerciseIDs.count) 个动作。默认参数当前显示的是最后选择的 `\(selectedExercise.name)`，加入训练时会按选择顺序添加。"
    }

    private func addSelectedExercise() {
        guard !selectedExerciseIDs.isEmpty else {
            return
        }

        var nextOrder = (session.exercises.map(\.order).max() ?? -1) + 1

        for selectedExerciseID in selectedExerciseIDs {
            guard let selectedExercise = exercises.first(where: { $0.id == selectedExerciseID }) else {
                continue
            }

            let workoutExercise = WorkoutExercise(
                name: selectedExercise.name,
                category: selectedExercise.category,
                order: nextOrder,
                session: session
            )

            workoutExercise.sets = (1...selectedExercise.defaultSets).map { index in
                WorkoutSet(
                    index: index,
                    targetReps: selectedExercise.defaultReps,
                    weightKg: selectedExercise.defaultWeightKg,
                    exercise: workoutExercise
                )
            }

            session.exercises.append(workoutExercise)
            nextOrder += 1
        }

        session.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }

    private func toggleSelection(for id: UUID) {
        if let index = selectedExerciseIDs.firstIndex(of: id) {
            selectedExerciseIDs.remove(at: index)
        } else {
            selectedExerciseIDs.append(id)
        }
    }

    private func weightText(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

private struct ExerciseOptionRow: View {
    let exercise: ExerciseCatalogItem
    let selectionIndex: Int?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.16))
                Image(systemName: exercise.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .bold))
                Text(exercise.targetMuscle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let selectionIndex {
                ZStack {
                    Circle()
                        .fill(Color.black)
                    Text("\(selectionIndex + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 22, height: 22)
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selectionIndex != nil ? Color.black : Color(.systemGray5), lineWidth: selectionIndex != nil ? 1.5 : 1)
        )
    }

    private var color: Color {
        switch exercise.tintName {
        case "orange":
            return .orange
        case "blue":
            return .blue
        case "gray":
            return .gray
        case "mint":
            return .mint
        case "purple":
            return .purple
        default:
            return .secondary
        }
    }
}

private struct ParameterField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        AddExerciseView(session: WorkoutSession(title: "Preview"))
    }
}
