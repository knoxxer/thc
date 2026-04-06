import SwiftUI
import Shared

/// Displays a scorecard image and allows sharing via UIActivityViewController.
struct ShareCardView: View {
    let round: Round
    let playerName: String

    @State private var cardImage: UIImage?
    @State private var isSharing: Bool = false
    @State private var holeScores: [HoleScore] = []

    // Inject for testing
    var fetchHoleScores: ((UUID) async -> [HoleScore])?

    var body: some View {
        VStack(spacing: 24) {
            if let image = cardImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 24)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 280)
                    .overlay { ProgressView() }
                    .padding(.horizontal, 24)
            }

            Button {
                isSharing = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .disabled(cardImage == nil)
        }
        .padding(.top, 24)
        .navigationTitle("Share Scorecard")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await renderCard()
        }
        .sheet(isPresented: $isSharing) {
            if let image = cardImage {
                ShareSheet(activityItems: [image])
            }
        }
    }

    // MARK: - Rendering

    private func renderCard() async {
        // Optionally fetch hole scores for the detailed grid
        if let fetcher = fetchHoleScores {
            holeScores = await fetcher(round.id)
        }

        // Look up the player from the round for the card generator.
        // We only have playerName here; build a minimal Player stand-in via
        // the card generator's direct content view.
        let player = Player(
            id: round.playerId,
            name: playerName,
            displayName: playerName,
            slug: playerName.lowercased().replacingOccurrences(of: " ", with: "-"),
            email: nil,
            ghinNumber: nil,
            handicapIndex: nil,
            handicapUpdatedAt: nil,
            avatarUrl: nil,
            isActive: true,
            role: "contributor",
            authUserId: nil,
            createdAt: Date()
        )

        cardImage = await MainActor.run {
            ShareCardGenerator.generateImage(
                player: player,
                round: round,
                holeScores: holeScores.isEmpty ? nil : holeScores
            )
        }
    }
}

// MARK: - ShareSheet

/// Bridges UIActivityViewController into SwiftUI.
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
