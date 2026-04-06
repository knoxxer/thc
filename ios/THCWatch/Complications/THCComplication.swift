import WidgetKit
import SwiftUI
import Shared

// MARK: - Timeline Entry

/// Snapshot of data to display in the watch face complication.
struct THCComplicationEntry: TimelineEntry {
    let date: Date
    /// Player's current rank in the season standings. Nil when no standings are cached.
    let rank: Int?
    /// Distance to the green center in yards. Nil when not in an active round.
    let distanceToGreen: Int?
    /// Par for the current hole. Nil when not in an active round.
    let currentHolePar: Int?
}

// MARK: - Timeline Provider

/// Provides timeline entries for the THC watch face complication.
///
/// The complication refreshes every 15 minutes during a round (frequent enough to
/// reflect hole changes) and once per hour when idle (standings rarely change mid-day).
struct THCComplicationProvider: TimelineProvider {

    typealias Entry = THCComplicationEntry

    func placeholder(in context: Context) -> THCComplicationEntry {
        THCComplicationEntry(
            date: .now,
            rank: 3,
            distanceToGreen: 187,
            currentHolePar: 4
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (THCComplicationEntry) -> Void
    ) {
        completion(loadCurrentEntry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<THCComplicationEntry>) -> Void
    ) {
        let entry = loadCurrentEntry()

        // Refresh interval: 15 min during an active round, 60 min when idle.
        let refreshInterval: TimeInterval = entry.distanceToGreen != nil ? 15 * 60 : 60 * 60
        let nextUpdate = Date(timeIntervalSinceNow: refreshInterval)

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // MARK: - Private

    /// Loads cached complication state from UserDefaults shared with the watch app.
    private func loadCurrentEntry() -> THCComplicationEntry {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard

        let rank = defaults.object(forKey: DefaultsKey.complicationRank) as? Int
        let distance = defaults.object(forKey: DefaultsKey.complicationDistance) as? Int
        let par = defaults.object(forKey: DefaultsKey.complicationPar) as? Int

        return THCComplicationEntry(
            date: .now,
            rank: rank,
            distanceToGreen: distance,
            currentHolePar: par
        )
    }
}

// MARK: - Complication Views

/// Renders the complication for all supported watch face families.
struct THCComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: THCComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    // MARK: - Circular (most common watch face slot)

    private var circularView: some View {
        ZStack {
            if let distance = entry.distanceToGreen {
                // Active round: show distance to green
                VStack(spacing: 1) {
                    Text("\(distance)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.green)
                        .minimumScaleFactor(0.7)
                    Text("yds")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else if let rank = entry.rank {
                // No active round: show standings rank
                VStack(spacing: 1) {
                    Text("#\(rank)")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(rankColor(rank))
                        .minimumScaleFactor(0.7)
                    Text("THC")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "flag.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Corner

    private var cornerView: some View {
        ZStack {
            if let distance = entry.distanceToGreen {
                Text("\(distance)y")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
            } else if let rank = entry.rank {
                Text("#\(rank)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(rankColor(rank))
            } else {
                Image(systemName: "flag.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Rectangular (large slot, shows more info)

    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.fill")
                .font(.caption)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 1) {
                if let distance = entry.distanceToGreen {
                    HStack(spacing: 3) {
                        Text("\(distance) yds")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                        if let par = entry.currentHolePar {
                            Text("Par \(par)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("To Green")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if let rank = entry.rank {
                    Text("Rank #\(rank)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(rankColor(rank))
                    Text("Homie Cup")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("THC Golf")
                        .font(.system(size: 14, weight: .bold))
                    Text("Start a round")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Inline (single-line text)

    private var inlineView: some View {
        Group {
            if let distance = entry.distanceToGreen {
                Text("THC \(distance)y")
            } else if let rank = entry.rank {
                Text("THC #\(rank)")
            } else {
                Text("THC Golf")
            }
        }
        .font(.caption)
    }

    // MARK: - Helpers

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .primary
        }
    }
}

// MARK: - Widget Configuration

// NOTE: This widget is intended for a separate WidgetKit extension target
// (THCWatchComplication) in Xcode, NOT the main THCWatch app target.
// The @main attribute lives here for illustration; in the actual Xcode project,
// a WidgetBundle entry point (THCComplicationBundle.swift) in the extension
// target will reference this widget.
struct THCComplication: Widget {
    static let kind = "THCComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: THCComplicationProvider()) { entry in
            THCComplicationView(entry: entry)
        }
        .configurationDisplayName("Homie Cup")
        .description("Current rank and distance to green during your round.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Shared Keys

/// App Group suite for sharing UserDefaults between the watch app and complication.
enum AppGroup {
    static let identifier = "group.com.thc.golf"
}

enum DefaultsKey {
    static let complicationRank = "complication_rank"
    static let complicationDistance = "complication_distance"
    static let complicationPar = "complication_par"
}

// MARK: - Complication Updater

/// Call this from PhoneConnectivityService whenever round state changes
/// to keep the complication in sync.
enum THCComplicationUpdater {
    /// Write current state to shared UserDefaults and reload all complication timelines.
    static func update(roundState: WatchRoundState?, rank: Int?) {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard

        if let rank = rank {
            defaults.set(rank, forKey: DefaultsKey.complicationRank)
        } else {
            defaults.removeObject(forKey: DefaultsKey.complicationRank)
        }

        if let state = roundState,
           let greenLat = state.greenLat,
           let greenLon = state.greenLon {
            // Distance is recalculated from cached GPS in the provider;
            // for complication we store the last known distance written by the app.
            // This is updated from IndependentGPSService / PhoneConnectivityService.
            defaults.set(state.par, forKey: DefaultsKey.complicationPar)
        } else {
            defaults.removeObject(forKey: DefaultsKey.complicationDistance)
            defaults.removeObject(forKey: DefaultsKey.complicationPar)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: THCComplication.kind)
    }

    /// Write the current distance to green so the complication reflects the latest GPS fix.
    static func updateDistance(_ distanceYards: Int) {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        defaults.set(distanceYards, forKey: DefaultsKey.complicationDistance)
        WidgetCenter.shared.reloadTimelines(ofKind: THCComplication.kind)
    }
}

// MARK: - Previews

#Preview("Circular — Active Round", as: .accessoryCircular) {
    THCComplication()
} timeline: {
    THCComplicationEntry(date: .now, rank: 2, distanceToGreen: 187, currentHolePar: 4)
}

#Preview("Circular — No Round", as: .accessoryCircular) {
    THCComplication()
} timeline: {
    THCComplicationEntry(date: .now, rank: 1, distanceToGreen: nil, currentHolePar: nil)
}

#Preview("Rectangular — Active Round", as: .accessoryRectangular) {
    THCComplication()
} timeline: {
    THCComplicationEntry(date: .now, rank: 3, distanceToGreen: 210, currentHolePar: 5)
}
