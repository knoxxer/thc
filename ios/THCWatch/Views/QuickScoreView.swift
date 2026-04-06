import SwiftUI
import Shared

/// Digital Crown score entry for the current hole.
/// Crown scrolls stroke count (1-15); tap confirms and sends to phone.
struct QuickScoreView: View {
    let holeNumber: Int
    let par: Int

    @EnvironmentObject private var connectivityService: PhoneConnectivityService
    @Environment(\.dismiss) private var dismiss

    /// Crown binding uses Double; display rounds to nearest Int.
    @State private var crownValue: Double
    @State private var isSending = false
    @State private var sendError: String?
    @State private var didConfirm = false

    private static let minStrokes: Double = 1
    private static let maxStrokes: Double = 15

    /// Integer strokes derived from the crown double.
    private var strokes: Int { Int(crownValue.rounded()) }

    init(holeNumber: Int, par: Int) {
        self.holeNumber = holeNumber
        self.par = par
        // Default crown to par
        _crownValue = State(initialValue: Double(par))
    }

    var body: some View {
        VStack(spacing: 8) {
            holeHeader

            strokePicker

            scoreSummary

            confirmButton
        }
        .padding(.horizontal, 8)
        .navigationTitle("Hole \(holeNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: Self.minStrokes,
            through: Self.maxStrokes,
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .alert("Send Error", isPresented: Binding(
            get: { sendError != nil },
            set: { if !$0 { sendError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = sendError {
                Text(error)
            }
        }
    }

    // MARK: - Components

    private var holeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("HOLE \(holeNumber)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Par \(par)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }
            Spacer()
        }
    }

    private var strokePicker: some View {
        VStack(spacing: 4) {
            Text("\(strokes)")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(strokeColor)
                .contentTransition(.numericText())
                .animation(.bouncy, value: strokes)

            Text("strokes")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(strokeColor.opacity(0.12))
        )
    }

    private var scoreSummary: some View {
        let vsParValue = strokes - par
        let vsParText: String
        let vsParColor: Color

        if vsParValue == 0 {
            vsParText = "Par"
            vsParColor = .primary
        } else if vsParValue < 0 {
            vsParText = "\(vsParValue) (Under)"
            vsParColor = .green
        } else {
            vsParText = "+\(vsParValue) (Over)"
            vsParColor = .red
        }

        return Text(vsParText)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(vsParColor)
    }

    private var confirmButton: some View {
        Group {
            if didConfirm {
                Label("Sent", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            } else {
                Button {
                    confirmScore()
                } label: {
                    Group {
                        if isSending {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Confirm")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(isSending)
            }
        }
    }

    // MARK: - Helpers

    private var strokeColor: Color {
        let vsPar = strokes - par
        if vsPar < 0 { return .green }
        if vsPar == 0 { return .primary }
        if vsPar == 1 { return .yellow }
        return .red
    }

    // MARK: - Actions

    private func confirmScore() {
        isSending = true
        let entry = WatchScoreEntry(holeNumber: holeNumber, strokes: strokes)
        do {
            try connectivityService.sendScore(entry)
            didConfirm = true
            isSending = false
            // Auto-dismiss after brief confirmation display
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                dismiss()
            }
        } catch {
            isSending = false
            sendError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        QuickScoreView(holeNumber: 7, par: 4)
            .environmentObject(PhoneConnectivityService())
    }
}
