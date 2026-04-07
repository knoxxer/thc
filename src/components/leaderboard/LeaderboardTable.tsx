"use client";

import Link from "next/link";
import { SeasonStanding } from "@/lib/types";
import { formatVsPar } from "@/lib/format";

function RankBadge({ rank }: { rank: number }) {
  if (rank === 1)
    return <span className="text-gold font-bold text-lg">1st</span>;
  if (rank === 2)
    return <span className="text-gray-300 font-semibold">2nd</span>;
  if (rank === 3)
    return <span className="text-amber-500 font-semibold">3rd</span>;
  return <span className="text-muted">{rank}th</span>;
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
        <p className="text-muted text-sm">
          Be the first to{" "}
          <Link href="/rounds/new" className="text-gold hover:text-gold-light">
            post a score
          </Link>
          .
        </p>
      </div>
    );
  }

  const sorted = [...standings].sort((a, b) => {
    // Primary: best N points (descending)
    if (b.best_n_points !== a.best_n_points) return b.best_n_points - a.best_n_points;
    // Tiebreaker 1: best single round net vs par (lower is better)
    if (a.best_net_vs_par !== b.best_net_vs_par) return a.best_net_vs_par - b.best_net_vs_par;
    // Tiebreaker 2: most rounds played (descending)
    return b.total_rounds - a.total_rounds;
  });

  return (
    <>
      {/* Mobile: card layout */}
      <div className="sm:hidden divide-y divide-surface-light/50">
        {sorted.map((s, i) => {
          const rank = i + 1;
          const isLeader = rank === 1;
          return (
            <Link
              key={s.player_id}
              href={`/players/${s.player_slug}`}
              className={`flex items-center justify-between px-4 py-3 active:bg-surface-light/30 ${
                isLeader ? "bg-gold/5" : ""
              }`}
            >
              <div className="flex items-center gap-3">
                <div className="w-8 text-center">
                  <RankBadge rank={rank} />
                </div>
                <div>
                  <span className={`font-semibold ${isLeader ? "text-gold" : ""}`}>
                    {s.player_name}
                  </span>
                  <div className="flex gap-3 text-xs text-muted mt-0.5">
                    <span>{s.total_rounds} rnd{s.total_rounds !== 1 ? "s" : ""}</span>
                    {s.handicap_index != null && <span>HCP {s.handicap_index}</span>}
                    {!s.is_eligible && (
                      <span className="text-gold/60">{5 - s.total_rounds} more to qualify</span>
                    )}
                  </div>
                </div>
              </div>
              <span className={`text-xl font-bold tabular-nums ${isLeader ? "text-gold" : "text-white"}`}>
                {s.best_n_points}
              </span>
            </Link>
          );
        })}
      </div>

      {/* Desktop: table layout */}
      <div className="hidden sm:block overflow-x-auto">
        <table className="w-full">
          <caption className="sr-only">Season leaderboard standings</caption>
          <thead>
            <tr className="border-b border-surface-light text-muted text-xs uppercase tracking-wider">
              <th className="text-left py-3 px-4 w-16">Rank</th>
              <th className="text-left py-3 px-4">Player</th>
              <th className="text-center py-3 px-4">Rounds</th>
              <th className="text-center py-3 px-4">HCP</th>
              <th className="text-center py-3 px-4 hidden md:table-cell">Best Round</th>
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
                    <RankBadge rank={rank} />
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
                  <td className="py-4 px-4 text-center text-muted tabular-nums hidden md:table-cell">
                    {formatVsPar(s.best_net_vs_par)}{" "}
                    <span className="text-muted">({s.best_round_points}pts)</span>
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
    </>
  );
}
