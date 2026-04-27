import SwiftUI
import SwiftData

struct TemplateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var preferences: [AppPreferences]

    let template: WorkoutTemplate
    let onApply: (WorkoutTemplate) -> Void

    private var weightUnit: WeightUnit {
        preferences.first?.weightUnit ?? .kilogram
    }

    private var orderedExercises: [TemplateExercise] {
        (template.exercises ?? []).sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    metaInfoSection
                    exerciseListSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            applyButton
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .background(AppTheme.bgCard)
        }
        .background(AppTheme.bgPage)
        .navigationBarHidden(true)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.fg1)
                }
                Spacer()
            }

            Text(template.title)
                .font(.system(size: 28, weight: .bold))

            Text(template.category)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.fg2)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.fillMedium)
                .clipShape(Capsule())
        }
    }

    private var metaInfoSection: some View {
        HStack(spacing: 0) {
            metaItem(icon: "clock", title: "预计时长", value: "\(template.estimatedDuration) 分钟")
            Divider().frame(height: 40)
            metaItem(icon: "flame", title: "难度", value: template.level)
            Divider().frame(height: 40)
            metaItem(icon: "list.number", title: "动作数", value: "\(orderedExercises.count)")
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    private func metaItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.fg2)
            Text(value)
                .font(.system(size: 16, weight: .bold))
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.fg2)
        }
        .frame(maxWidth: .infinity)
    }

    private var exerciseListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("训练动作")
                .font(.system(size: 17, weight: .bold))

            VStack(spacing: 10) {
                ForEach(Array(orderedExercises.enumerated()), id: \.element.id) { index, exercise in
                    templateExerciseRow(exercise: exercise, index: index + 1)
                }
            }
        }
    }

    private func templateExerciseRow(exercise: TemplateExercise, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(AppTheme.ctaFill)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .semibold))

                HStack(spacing: 8) {
                    Label("\(exercise.defaultSets) 组", systemImage: "square.stack")
                    Label("\(exercise.defaultReps) 次", systemImage: "repeat")
                    Label(
                        exercise.defaultWeightKg > 0
                            ? exercise.defaultWeightKg.formattedWeightWithUnit(unit: weightUnit)
                            : "按历史",
                        systemImage: "scalemass"
                    )
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.fg2)
            }

            Spacer()

            Image(systemName: exercise.symbolName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.fg2)
                .frame(width: 36, height: 36)
                .background(AppTheme.fillMedium)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.fillMedium, lineWidth: 1)
        )
    }

    private var applyButton: some View {
        Button(action: {
            onApply(template)
        }) {
            HStack(spacing: 8) {
                Image(systemName: "play")
                    .font(.system(size: 12, weight: .bold))
                Text("立即应用")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AppTheme.ctaFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
