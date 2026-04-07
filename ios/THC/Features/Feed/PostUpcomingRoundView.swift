import SwiftUI

struct PostUpcomingRoundView: View {
    let onPost: (String, Date, String?) -> Void

    @State private var courseName = ""
    @State private var teeTime = Date().addingTimeInterval(24 * 60 * 60)
    @State private var notes = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Course") {
                    TextField("Course name", text: $courseName)
                }
                Section("Tee Time") {
                    DatePicker("Date & Time", selection: $teeTime, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                }
                Section("Notes (optional)") {
                    TextField("e.g. Walking, room for 2 more", text: $notes)
                }
            }
            .navigationTitle("Upcoming Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        onPost(courseName.trimmingCharacters(in: .whitespaces), teeTime, notes.isEmpty ? nil : notes)
                    }
                    .disabled(courseName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
