import SwiftUI
import Shared

/// Per-hole score entry screen during an active round.
/// Auto-advance prompt fires when the player moves to the next hole.
struct LiveScoringView: View {
    @Bindable var roundManager: RoundManager
    @State private var showAutoAdvancePrompt: Bool = false
    @State private var showFinishConfirmation: Bool = false
    @State private var pendingHoleEntry: HoleEntryState = .init()

    private var currentHole: CourseHole? {
        guard case .active(let holeNum, _) = roundManager.state,
              let detail = roundManager.courseDetail else { return nil }
        return detail.holes.first { $0.holeNumber == holeNum }
    }

    private var currentHoleNumber: Int {
        if case .active(let h, _) = roundManager.state { return h }
        return 1
    }

    private var runningScoreVsPar: Int {
        if case .active(_, let score) = roundManager.state { return score }
        return 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                holeHeader
                Divider()
                scoreEntryArea
                Spacer()
                statsSection
                Divider()
                actionBar
            }
            .navigationTitle("Hole \(currentHoleNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .alert("Move to Hole \(currentHoleNumber + 1)?", isPresented: $showAutoAdvancePrompt) {
            Button("Yes, next hole") {
                Task { await submitAndAdvance() }
            }
            Button("Stay on this hole", role: .cancel) {}
        } message: {
            Text("It looks like you've reached the next tee.")
        }
        .confirmationDialog("Finish Round?", isPresented: $showFinishConfirmation, titleVisibility: .visible) {
            Button("Finish Round", role: .destructive) {
                Task { try? await roundManager.finishRound() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will save your round and upload your score.")
        }
        .onChange(of: roundManager.state) { _, newState in
            if case .active = newState {
                pendingHoleEntry = .init()
            }
        }
    }

    // MARK: - Hole Header

    private var holeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(roundManager.courseDetail?.course.name ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    if let hole = currentHole {
                        Text("Par \(hole.par)")
                            .font(.subheadline.weight(.semibold))
                        if let hcp = hole.handicap {
                            Text("SI \(hcp)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let yds = hole.yardage {
                            Text("\(yds) yds")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatScore(runningScoreVsPar))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(scoreColor(runningScoreVsPar))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Score Entry

    private var scoreEntryArea: some View {
        VStack(spacing: 20) {
            Text("Strokes on Hole \(currentHoleNumber)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Large stroke counter
            HStack(spacing: 32) {
                Button {
                    if pendingHoleEntry.strokes > 1 {
                        pendingHoleEntry.strokes -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(pendingHoleEntry.strokes > 1 ? Color.accentColor : Color.secondary)
                }
                .disabled(pendingHoleEntry.strokes <= 1)

                Text("\(pendingHoleEntry.strokes)")
                    .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())

                Button {
                    pendingHoleEntry.strokes += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)
                }
            }

            if let hole = currentHole {
                let vsPar = pendingHoleEntry.strokes - hole.par
                Text(holeScoreLabel(vsPar: vsPar))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(holeScoreColor(vsPar: vsPar))
                    .animation(.easeInOut(duration: 0.15), value: vsPar)
            }
        }
        .padding(.vertical, 28)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HoleStatsView(entry: $pendingHoleEntry)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                let totalHoles = roundManager.courseDetail?.holes.count ?? 18
                if currentHoleNumber < totalHoles {
                    Task { await submitAndAdvance() }
                } else {
                    showFinishConfirmation = true
                }
            } label: {
                let isLast = currentHoleNumber >= (roundManager.courseDetail?.holes.count ?? 18)
                Label(isLast ? "Finish" : "Next Hole", systemImage: isLast ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("GPS") {
                // Navigate to HoleOverviewView (handled by parent coordinator)
            }
        }
    }

    // MARK: - Actions

    private func submitAndAdvance() async {
        let entry = RoundManager.HoleScoreEntry(
            strokes: pendingHoleEntry.strokes,
            putts: pendingHoleEntry.putts,
            fairwayHit: pendingHoleEntry.fairwayHit,
            greenInRegulation: pendingHoleEntry.greenInRegulation
        )
        await roundManager.recordHoleScore(entry)
    }

    // MARK: - Formatting Helpers

    private func formatScore(_ v: Int) -> String {
        if v == 0 { return "E" }
        return v > 0 ? "+\(v)" : "\(v)"
    }

    private func scoreColor(_ v: Int) -> Color {
        if v < 0 { return .green }
        if v > 0 { return .red }
        return .primary
    }

    private func holeScoreLabel(vsPar: Int) -> String {
        switch vsPar {
        case ..<(-2): return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double Bogey"
        case 3: return "Triple Bogey"
        default: return "+\(vsPar)"
        }
    }

    private func holeScoreColor(vsPar: Int) -> Color {
        if vsPar < 0 { return .green }
        if vsPar == 0 { return .primary }
        if vsPar == 1 { return .orange }
        return .red
    }
}

// MARK: - HoleEntryState

struct HoleEntryState {
    var strokes: Int = 4
    var putts: Int? = nil
    var fairwayHit: String? = nil
    var greenInRegulation: Bool? = nil
}
