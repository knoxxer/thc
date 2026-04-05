"use client";

import Link from "next/link";
import { SeasonStanding } from "@/lib/types";

function getRankDisplay(rank: number) {
  if (rank === 1) return { label: "1st", style: "text-gold font-bold text-lg" };
  if (rank === 2)
    return { label: "2nd", style: "text-gray-300 font-semibold" };
  if (rank === 3)
    return { label: "3rd", style: "text-amber-600 font-semibold" };
  return { label: `${rank}th`, style: "text-muted" };
}

function formatNetVsPar(n: number) {
  if (n === 0) return "E";
  return n > 0 ? `+${n}` : `${n}`;
}

export default function LeaderboardTable({
  standings,
}: {
  standings: SeasonStanding[];
}) {
  if (standings.length === 0) {
    return (
      <div className="text-center py-16">
        <p className="text-2xl mb-2">🏌️</p>
        <p className="text-muted text-lg">No rounds posted yet this season.</p>
        <p className="text-muted text-sm mt-1">
          Be the first to{" "}
          <Link href="/rounds/new" className="text-gold hover:text-gold-light">
            post a score
          </Link>
          .
        </p>
      </div>
    );
  }

  const sorted = [...standings].sort(
    (a, b) => b.best_n_points - a.best_n_points
  );

  return (
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead>
          <tr className="border-b border-surface-light text-muted text-sm">
            <th className="text-left py-3 px-3 w-16">Rank</th>
            <th className="text-left py-3 px-3">Player</th>
            <th className="text-center py-3 px-3">Rounds</th>
            <th className="text-center py-3 px-3">HCP</th>
            <th className="text-center py-3 px-3">Best Round</th>
            <th className="text-right py-3 px-3">Points</th>
          </tr>
        </thead>
        <tbody>
          {sorted.map((s, i) => {
            const rank = getRankDisplay(i + 1);
            return (
              <tr
                key={s.player_id}
                className="border-b border-surface-light/50 hover:bg-surface-light/30 transition-colors"
              >
                <td className={`py-4 px-3 ${rank.style}`}>{rank.label}</td>
                <td className="py-4 px-3">
                  <Link
                    href={`/players/${s.player_slug}`}
                    className="hover:text-gold transition-colors"
                  >
                    <span className="font-medium">{s.player_name}</span>
                  </Link>
                  {!s.is_eligible && (
                    <span className="ml-2 text-xs bg-surface-light text-muted px-1.5 py-0.5 rounded">
                      needs {5 - s.total_rounds} more
                    </span>
                  )}
                </td>
                <td className="py-4 px-3 text-center text-muted">
                  {s.total_rounds}
                </td>
                <td className="py-4 px-3 text-center text-muted">
                  {s.handicap_index != null ? s.handicap_index : "—"}
                </td>
                <td className="py-4 px-3 text-center text-muted">
                  {formatNetVsPar(s.best_net_vs_par)} ({s.best_round_points}pts)
                </td>
                <td className="py-4 px-3 text-right">
                  <span className="text-xl font-bold text-gold">
                    {s.best_n_points}
                  </span>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
