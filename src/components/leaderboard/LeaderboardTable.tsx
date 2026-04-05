"use client";

import Link from "next/link";
import { SeasonStanding } from "@/lib/types";

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
      <div className="text-center py-16 px-4">
        <p className="text-muted text-lg mb-1">No rounds posted yet.</p>
        <p className="text-muted/60 text-sm">
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
          <tr className="border-b border-surface-light text-muted text-xs uppercase tracking-wider">
            <th className="text-left py-3 px-4 w-16">Rank</th>
            <th className="text-left py-3 px-4">Player</th>
            <th className="text-center py-3 px-4">Rounds</th>
            <th className="text-center py-3 px-4">HCP</th>
            <th className="text-center py-3 px-4 hidden sm:table-cell">Best Round</th>
            <th className="text-right py-3 px-4">Points</th>
          </tr>
        </thead>
        <tbody>
          {sorted.map((s, i) => {
            const rank = i + 1;
            const isLeader = rank === 1;

            return (
              <tr
                key={s.player_id}
                className={`border-b border-surface-light/50 transition-colors hover:bg-surface-light/30 ${
                  isLeader ? "bg-gold/5" : ""
                }`}
              >
                <td className="py-4 px-4">
                  {isLeader ? (
                    <span className="text-gold font-bold text-lg">1st</span>
                  ) : rank === 2 ? (
                    <span className="text-gray-300 font-semibold">2nd</span>
                  ) : rank === 3 ? (
                    <span className="text-amber-700 font-semibold">3rd</span>
                  ) : (
                    <span className="text-muted">{rank}th</span>
                  )}
                </td>
                <td className="py-4 px-4">
                  <Link
                    href={`/players/${s.player_slug}`}
                    className="hover:text-gold transition-colors"
                  >
                    <span className={`font-semibold ${isLeader ? "text-gold" : ""}`}>
                      {s.player_name}
                    </span>
                  </Link>
                  {!s.is_eligible && (
                    <span className="ml-2 text-[10px] uppercase tracking-wider bg-surface-light text-muted px-1.5 py-0.5 rounded">
                      {5 - s.total_rounds} more
                    </span>
                  )}
                </td>
                <td className="py-4 px-4 text-center text-muted tabular-nums">
                  {s.total_rounds}
                </td>
                <td className="py-4 px-4 text-center text-muted tabular-nums">
                  {s.handicap_index != null ? s.handicap_index : "—"}
                </td>
                <td className="py-4 px-4 text-center text-muted tabular-nums hidden sm:table-cell">
                  {formatNetVsPar(s.best_net_vs_par)}{" "}
                  <span className="text-muted/60">({s.best_round_points}pts)</span>
                </td>
                <td className="py-4 px-4 text-right">
                  <span className={`text-xl font-bold tabular-nums ${isLeader ? "text-gold" : "text-white"}`}>
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
