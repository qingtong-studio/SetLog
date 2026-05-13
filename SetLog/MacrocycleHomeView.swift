import SwiftData
import SwiftUI

struct MacrocycleHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\MacrocycleProgram.createdAt, order: .reverse)])
    private var macros: [MacrocycleProgram]

    @State private var setupMode: CycleSetupMode?
    @State private var showEndConfirm = false

    private var activeMacro: MacrocycleProgram? {
        macros.first(where: { $0.isActive })
    }

    private var historyMacros: [MacrocycleProgram] {
        macros.filter { !$0.isActive }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let macro = activeMacro {
                    activeSection(macro)
                } else {
                    emptyState
                }

                if !historyMacros.isEmpty {
                    historySection
                }
            }
            .padding(16)
        }
        .background(AppTheme.bgPage)
        .navigationTitle("周期训练")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $setupMode) { mode in
            MacrocycleSetupView(mode: mode)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.fg2)
            Text("还没有进行中的周期")
                .font(.system(size: 15, weight: .semibold))
            Text("可以开启一个完整的大周期（多个阶段串联），或先尝试一个小周期。")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.fg2)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button {
                    setupMode = .macro
                } label: {
                    Text("开启大周期")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(AppTheme.orange)
                        .clipShape(Capsule())
                }
                Button {
                    setupMode = .singleMeso
                } label: {
                    Text("开启小周期")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.orange)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(AppTheme.bgCard)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(AppTheme.orange, lineWidth: 1)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func activeSection(_ macro: MacrocycleProgram) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(macro.title)
                .font(.system(size: 18, weight: .bold))
            Text("起始 \(macro.startDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.fg2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

        ForEach(macro.orderedMesocycles, id: \.id) { meso in
            NavigationLink {
                MesocycleEditorView(meso: meso)
            } label: {
                mesoRow(meso)
            }
            .buttonStyle(.plain)
        }

        Button(role: .destructive) {
            showEndConfirm = true
        } label: {
            Text("结束周期")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AppTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .confirmationDialog("结束当前大周期?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("结束周期", role: .destructive) {
                endCurrent(macro)
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func mesoRow(_ meso: Mesocycle) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meso.phaseLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.fg1)
                Text("\(meso.totalWeeks) 周 · 每周 \(meso.daysPerWeek) 天 · RPE 上限 \(String(format: "%.1f", meso.defaultRpeCap)) · \(meso.targetRepsLow)–\(meso.targetRepsHigh) 次")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.fg2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("历史")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.fg2)
            ForEach(historyMacros) { macro in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(macro.title)
                            .font(.system(size: 14, weight: .semibold))
                        Text("\(macro.startDate.formatted(date: .abbreviated, time: .omitted)) – \((macro.endedAt ?? macro.createdAt).formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.fg2)
                    }
                    Spacer()
                }
                .padding(14)
                .background(AppTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func endCurrent(_ macro: MacrocycleProgram) {
        macro.isActive = false
        macro.endedAt = .now
        try? modelContext.save()
    }
}
