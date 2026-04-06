import SwiftUI
import Shared

/// Form for submitting a completed round after the fact.
/// Mirrors the web app's `/rounds/new` page.
struct PostRoundView: View {
    @State var viewModel: ScoreEntryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showSuccess = false

    init(player: Player, season: Season,
         offlineStorage: OfflineStorageProviding,
         syncService: SyncServiceProviding) {
        _viewModel = State(initialValue: ScoreEntryViewModel(
            player: player,
            season: season,
            offlineStorage: offlineStorage,
            syncService: syncService
        ))
    }

    var body: some View {
        Form {
            courseSection
            scoreSection
            calculatedSection
        }
        .navigationTitle("Log Round")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onChange(of: viewModel.submitResult) { _, result in
            if case .success = result {
                showSuccess = true
            }
        }
        .alert("Round Saved!", isPresented: $showSuccess) {
            Button("Done") {
                viewModel.reset()
                dismiss()
            }
        } message: {
            if case .success(let pts) = viewModel.submitResult {
                Text("You earned \(pts) point\(pts == 1 ? "" : "s").")
            }
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            if case .error(let msg) = viewModel.submitResult {
                Text(msg)
            }
        }
    }

    // MARK: - Course Section

    private var courseSection: some View {
        Section("Course") {
            TextField("Course name", text: $viewModel.courseName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            DatePicker("Date played", selection: $viewModel.playedAt, displayedComponents: .date)
            Stepper("Par: \(viewModel.par)", value: $viewModel.par, in: 27...90, step: 1)
        }
    }

    // MARK: - Score Section

    private var scoreSection: some View {
        Section("Score") {
            HStack {
                Text("Gross score")
                Spacer()
                TextField("Score", value: $viewModel.grossScore, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .foregroundStyle(viewModel.grossScore == nil ? Color.secondary : Color.primary)
            }
            HStack {
                Text("Course handicap")
                Spacer()
                TextField("Handicap", value: $viewModel.courseHandicap, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .foregroundStyle(viewModel.courseHandicap == nil ? Color.secondary : Color.primary)
            }
        }
    }

    // MARK: - Calculated Section

    private var calculatedSection: some View {
        Section {
            calculatedRow(label: "Net score", value: viewModel.netScore.map { "\($0)" })
            calculatedRow(label: "Net vs par", value: viewModel.netVsPar.map { formatVsPar($0) })
            pointsRow
        } header: {
            Text("Calculated")
        } footer: {
            if let error = viewModel.validationError {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }

    private func calculatedRow(label: String, value: String?) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value ?? "—")
                .foregroundStyle(value == nil ? .tertiary : .primary)
                .fontWeight(.medium)
        }
    }

    private var pointsRow: some View {
        HStack {
            Text("Points")
                .foregroundStyle(.secondary)
            Spacer()
            if let pts = viewModel.points {
                Text("\(pts)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(pointsColor(pts))
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await viewModel.submitPostRound() }
            } label: {
                if viewModel.isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                } else {
                    Text("Save")
                        .fontWeight(.semibold)
                }
            }
            .disabled(!viewModel.canSubmit)
        }
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel", role: .cancel) { dismiss() }
        }
    }

    // MARK: - Helpers

    private func formatVsPar(_ v: Int) -> String {
        if v == 0 { return "Even" }
        return v > 0 ? "+\(v)" : "\(v)"
    }

    private func pointsColor(_ pts: Int) -> Color {
        if pts >= 12 { return .green }
        if pts >= 8 { return .primary }
        return .secondary
    }

    private var errorBinding: Binding<Bool> {
        Binding {
            if case .error = viewModel.submitResult { return true }
            return false
        } set: { _ in }
    }
}
