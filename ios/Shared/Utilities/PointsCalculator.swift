import Foundation

/// Exact port of `src/lib/points.ts`.
///
/// Scoring scale:
/// - Net par (0) = 10 points
/// - Each stroke under par adds 1 point (max 15)
/// - Each stroke over par subtracts 1 point (floor 1)
public enum PointsCalculator {
    /// Calculate points for a round based on net score vs par.
    ///
    /// - Parameter netVsPar: Net score minus par. Negative = under par.
    /// - Returns: Points in the range [1, 15].
    public static func calculatePoints(netVsPar: Int) -> Int {
        let points = 10 - netVsPar
        return max(1, min(15, points))
    }
}
