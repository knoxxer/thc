import SwiftUI
import Shared

struct NotificationBellView: View {
    @Bindable var viewModel: FeedViewModel
    @State private var showNotifications = false

    var body: some View {
        Button { showNotifications = true } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.body)
                if viewModel.unreadCount > 0 {
                    Text(viewModel.unreadCount > 9 ? "9+" : "\(viewModel.unreadCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(.red, in: Circle())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationListView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Notification List

struct NotificationListView: View {
    @Bindable var viewModel: FeedViewModel
    @Environment(\.dismiss) private var dismiss

    private let typeIcons: [String: String] = [
        "new_round": "⛳",
        "reaction": "🔥",
        "comment": "💬",
        "rsvp": "📅",
        "upcoming_round": "📅",
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.notifications.isEmpty {
                    ContentUnavailableView("No notifications", systemImage: "bell.slash", description: Text("You're all caught up"))
                } else {
                    List(viewModel.notifications) { notif in
                        HStack(alignment: .top, spacing: 8) {
                            Text(typeIcons[notif.type] ?? "🔔")
                                .font(.callout)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(notif.title)
                                    .font(.subheadline)
                                    .foregroundStyle(notif.isRead ? .secondary : .primary)
                                if let body = notif.body {
                                    Text(body)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Text(timeAgo(notif.createdAt))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .listRowBackground(notif.isRead ? Color.clear : Color.accentColor.opacity(0.05))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if viewModel.unreadCount > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Mark all read") {
                            Task { await viewModel.markAllRead() }
                        }
                        .font(.caption)
                    }
                }
            }
            .task {
                await viewModel.loadNotifications()
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}
