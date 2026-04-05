/**
 * Calculate points for a round based on net score vs par.
 *
 * Net par (0) = 10 points. Each stroke under adds a point, each over loses one.
 * Floor of 1 (you always get credit for playing), ceiling of 15.
 */
export function calculatePoints(netVsPar: number): number {
  const points = 10 - netVsPar;
  return Math.max(1, Math.min(15, points));
}
