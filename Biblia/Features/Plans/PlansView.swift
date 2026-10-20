import SwiftData
import SwiftUI

struct PlansView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \PlanEnrollment.startedAt) private var enrollments: [PlanEnrollment]
    @Query private var entries: [ReadingEntry]
    @State private var leaving: PlanEnrollment?

    var body: some View {
        NavigationStack {
            List {
                if !enrollments.isEmpty {
                    Section("Seus planos") {
                        ForEach(enrollments) { enrollment in
                            if let plan = PlanGenerator.plan(enrollment.planID) {
                                ActivePlanCard(progress: progress(plan, enrollment)) { refs in
                                    let store = BibleStore(context: context)
                                    store.markRead(refs)
                                    app.onReadingChanged?(store)
                                }
                                .swipeActions {
                                    Button("Sair", role: .destructive) { leaving = enrollment }
                                }
                            }
                        }
                    }
                }
                let available = PlanGenerator.all.filter { plan in !enrollments.contains { $0.planID == plan.id } }
                if !available.isEmpty {
                    Section("Começar um plano") {
                        ForEach(available) { plan in
                            HStack(spacing: 14) {
                                Image(systemName: plan.icon)
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plan.title).font(.body.weight(.semibold))
                                    Text("\(plan.days.count) dias · \(plan.summary)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Começar") {
                                    context.insert(PlanEnrollment(planID: plan.id))
                                    try? context.save()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Planos")
            .confirmationDialog(
                "Sair do plano?",
                isPresented: Binding(get: { leaving != nil }, set: { if !$0 { leaving = nil } }),
                titleVisibility: .visible
            ) {
                Button("Sair do plano", role: .destructive) {
                    if let leaving { context.delete(leaving) }
                    try? context.save()
                }
            } message: {
                Text("Suas leituras continuam registradas no mapa de progresso.")
            }
        }
    }

    private func progress(_ plan: ReadingPlan, _ enrollment: PlanEnrollment) -> PlanProgress {
        let start = Calendar.current.startOfDay(for: enrollment.startedAt)
        let read = Set(entries.filter { $0.readAt >= start }.map(\.chapterRef))
        return PlanProgress(plan: plan, startedAt: enrollment.startedAt, readSinceStart: read)
    }
}

private struct ActivePlanCard: View {
    let progress: PlanProgress
    let completeDay: ([ChapterRef]) -> Void

    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: progress.plan.icon).foregroundStyle(Color.accentColor)
                Text(progress.plan.title).font(.headline)
                Spacer()
                Text(progress.fraction.formatted(.percent.precision(.fractionLength(0))))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress.fraction)
                .tint(.accentColor)

            if let day = progress.currentDay {
                let chapters = progress.plan.days[day]
                HStack {
                    Text("Dia \(day + 1) de \(progress.plan.days.count)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    status
                }
                FlowChips(chapters: chapters, read: progress.readSinceStart) { ref in
                    app.open(ref)
                }
                Button {
                    completeDay(chapters.filter { !progress.readSinceStart.contains($0) })
                } label: {
                    Label("Concluir dia \(day + 1)", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Label("Plano concluído!", systemImage: "party.popper")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var status: some View {
        let behind = progress.daysBehind
        if behind > 0 {
            Text(behind == 1 ? "1 dia atrasado" : "\(behind) dias atrasado")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
        } else {
            Text("Em dia")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.accentColor)
        }
    }
}

/// Capítulos do dia como fichas tocáveis; os já lidos ficam marcados.
private struct FlowChips: View {
    let chapters: [ChapterRef]
    let read: Set<ChapterRef>
    let onTap: (ChapterRef) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(chapters, id: \.self) { ref in
                    let done = read.contains(ref)
                    Button { onTap(ref) } label: {
                        HStack(spacing: 4) {
                            if done { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
                            Text(ref.title).font(.footnote.weight(.medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(done ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill), in: Capsule())
                        .foregroundStyle(done ? Color.accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
