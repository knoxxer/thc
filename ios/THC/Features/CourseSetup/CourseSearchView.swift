import SwiftUI
import CoreLocation
import Shared

/// Course search: text search, nearby courses, and favorites.
struct CourseSearchView: View {
    let player: Player
    let offlineStorage: OfflineStorageProviding
    let syncService: SyncServiceProviding
    let season: Season?

    @State private var viewModel: CourseSetupViewModel
    @State private var searchText: String = ""
    @State private var showingMultiPicker: Bool = false
    @State private var selectedDetail: CourseDetail?
    @State private var showRoundStart: Bool = false
    @State private var navigationPath = NavigationPath()

    init(
        player: Player,
        courseDataService: CourseDataServiceProviding,
        locationManager: LocationManager,
        offlineStorage: OfflineStorageProviding,
        syncService: SyncServiceProviding,
        season: Season? = nil
    ) {
        self.player = player
        self.offlineStorage = offlineStorage
        self.syncService = syncService
        self.season = season
        _viewModel = State(initialValue: CourseSetupViewModel(
            courseDataService: courseDataService,
            locationManager: locationManager
        ))
    }

    var body: some View {
        List {
            // Auto-detected course banner
            if let detected = viewModel.detectedCourse {
                detectedCourseBanner(detected)
            }

            // Multiple courses nearby → resort picker
            if !viewModel.multipleCourseNearby.isEmpty {
                nearbyPickerSection
            }

            // Search results
            if !searchText.isEmpty {
                searchResultsSection
            } else {
                // Nearby section (when not searching)
                nearbySection
                // Favorites section
                favoritesSection
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search courses")
        .onChange(of: searchText) { _, text in
            Task { await viewModel.search(query: text) }
        }
        .task {
            viewModel.loadFavorites()
            await viewModel.detectNearbyCourse()
        }
        .confirmationDialog(
            "Multiple Courses Nearby",
            isPresented: $showingMultiPicker,
            titleVisibility: .visible
        ) {
            ForEach(viewModel.multipleCourseNearby) { course in
                Button(course.name) {
                    Task { await loadAndNavigate(courseId: course.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showRoundStart) {
            if let detail = selectedDetail {
                roundStartSheet(for: detail)
            }
        }
    }

    // MARK: - Detected Course Banner

    private func detectedCourseBanner(_ course: CourseData) -> some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .foregroundStyle(.green)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Looks like you're at")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(course.name)
                        .font(.subheadline.weight(.semibold))
                }

                Spacer()

                Button("Start") {
                    Task { await loadAndNavigate(courseId: course.id) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Nearby Picker

    private var nearbyPickerSection: some View {
        Section("Multiple Courses Nearby") {
            ForEach(viewModel.multipleCourseNearby) { course in
                nearbyPickerRow(for: course)
            }
        }
    }

    private func nearbyPickerRow(for course: CourseData) -> some View {
        let isFav = viewModel.isFavorite(courseId: course.id)
        return Button {
            Task { await loadAndNavigate(courseId: course.id) }
        } label: {
            CourseRow(course: course, isFavorite: isFav) {
                viewModel.toggleFavorite(courseId: course.id)
            }
        }
        .tint(.primary)
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        Section {
            if viewModel.isSearching {
                HStack {
                    Spacer()
                    ProgressView("Searching…")
                    Spacer()
                }
            } else if viewModel.searchResults.isEmpty {
                Text("No courses found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.searchResults, id: \.golfcourseapiId) { result in
                    Button {
                        Task {
                            if let detail = try? await viewModel.selectCourse(result) {
                                selectedDetail = detail
                                showRoundStart = true
                            }
                        }
                    } label: {
                        SearchResultRow(result: result)
                    }
                    .tint(.primary)
                }
            }
        } header: {
            Text("Search Results")
        }
    }

    // MARK: - Nearby Section

    private var nearbySection: some View {
        Group {
            if viewModel.isLoadingNearby {
                Section("Nearby") {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if !viewModel.nearbyCourses.isEmpty {
                Section("Nearby") {
                    ForEach(viewModel.nearbyCourses) { course in
                        Button {
                            Task { await loadAndNavigate(courseId: course.id) }
                        } label: {
                            CourseRow(course: course, isFavorite: viewModel.isFavorite(courseId: course.id)) {
                                viewModel.toggleFavorite(courseId: course.id)
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
        }
    }

    // MARK: - Favorites Section

    private var favoritesSection: some View {
        let favorites = viewModel.nearbyCourses.filter { viewModel.isFavorite(courseId: $0.id) }
        return Group {
            if !favorites.isEmpty {
                Section("Favorites") {
                    ForEach(favorites) { course in
                        Button {
                            Task { await loadAndNavigate(courseId: course.id) }
                        } label: {
                            CourseRow(course: course, isFavorite: true) {
                                viewModel.toggleFavorite(courseId: course.id)
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
        }
    }

    // MARK: - Round Start Sheet

    private func roundStartSheet(for detail: CourseDetail) -> some View {
        NavigationStack {
            if let s = season {
                PostRoundView(
                    player: player,
                    season: s,
                    offlineStorage: offlineStorage,
                    syncService: syncService
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            selectedDetail = nil
                            showRoundStart = false
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("No active season")
                        .font(.headline)
                    Text("Rounds can only be logged during an active season.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Navigation

    private func loadAndNavigate(courseId: UUID) async {
        if let detail = try? await viewModel.loadCourseDetail(courseId: courseId) {
            selectedDetail = detail
            showRoundStart = true
        }
    }
}

// MARK: - CourseRow

private struct CourseRow: View {
    let course: CourseData
    let isFavorite: Bool
    let onFavoriteTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(course.name)
                    .font(.subheadline.weight(.medium))
                if let club = course.clubName, club != course.name {
                    Text(club)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Text("Par \(course.par)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(course.holeCount) holes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if course.hasGreenData {
                        Label("GPS", systemImage: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .labelStyle(.iconOnly)
                    }
                }
            }
            Spacer()
            Button {
                onFavoriteTap()
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - SearchResultRow

private struct SearchResultRow: View {
    let result: CourseSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(result.name)
                .font(.subheadline.weight(.medium))
            if let club = result.clubName {
                Text(club)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Text("Par \(result.par)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(result.holeCount) holes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

