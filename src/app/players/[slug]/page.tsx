import { createClient } from "@/lib/supabase/server";
import { notFound } from "next/navigation";
import Link from "next/link";
import { Player, Round, Season } from "@/lib/types";

export const revalidate = 60;

function formatNetVsPar(n: number) {
  if (n === 0) return "E";
  return n > 0 ? `+${n}` : `${n}`;
}

function formatDate(d: string) {
  return new Date(d + "T00:00:00").toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

export default async function PlayerPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const supabase = await createClient();

  const { data: player } = await supabase
    .from("players")
    .select("*")
    .eq("slug", slug)
    .single<Player>();

  if (!player) notFound();

  const { data: season } = await supabase
    .from("seasons")
    .select("*")
    .eq("is_active", true)
    .single<Season>();

  let rounds: Round[] = [];
  if (season) {
    const { data } = await supabase
      .from("rounds")
      .select("*")
      .eq("player_id", player.id)
      .eq("season_id", season.id)
      .order("played_at", { ascending: false });
    rounds = (data as Round[]) || [];
  }

  const sortedByPoints = [...rounds].sort(
    (a, b) => (b.points || 0) - (a.points || 0)
  );
  const best10 = sortedByPoints.slice(0, 10);
  const totalPoints = best10.reduce((sum, r) => sum + (r.points || 0), 0);
  const isEligible = rounds.length >= (season?.min_rounds || 5);

  return (
    <div className="max-w-5xl mx-auto px-4 py-8">
      <Link
        href="/"
        className="text-sm text-muted hover:text-foreground transition-colors"
      >
        &larr; Back to Leaderboard
      </Link>

      {/* Player header */}
      <div className="mt-6 mb-8">
        <h1 className="text-3xl font-bold">{player.display_name}</h1>
        <div className="flex items-center gap-4 mt-2 text-muted text-sm">
          {player.handicap_index != null && (
            <span>HCP: {player.handicap_index}</span>
          )}
          {player.ghin_number && <span>GHIN: {player.ghin_number}</span>}
        </div>
      </div>

      {/* Season summary */}
      {season && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <div className="bg-surface rounded-lg border border-surface-light p-4">
            <p className="text-sm text-muted">Season Points</p>
            <p className="text-2xl font-bold text-gold">{totalPoints}</p>
          </div>
          <div className="bg-surface rounded-lg border border-surface-light p-4">
            <p className="text-sm text-muted">Rounds Played</p>
            <p className="text-2xl font-bold">{rounds.length}</p>
          </div>
          <div className="bg-surface rounded-lg border border-surface-light p-4">
            <p className="text-sm text-muted">Best Round</p>
            <p className="text-2xl font-bold">
              {rounds.length > 0
                ? `${Math.max(...rounds.map((r) => r.points || 0))} pts`
                : "—"}
            </p>
          </div>
          <div className="bg-surface rounded-lg border border-surface-light p-4">
            <p className="text-sm text-muted">Status</p>
            <p className="text-2xl font-bold">
              {isEligible ? (
                <span className="text-accent-light">Eligible</span>
              ) : (
                <span className="text-muted">
                  {(season?.min_rounds || 5) - rounds.length} more
                </span>
              )}
            </p>
          </div>
        </div>
      )}

      {/* Round history */}
      <div className="bg-surface rounded-xl border border-surface-light overflow-hidden">
        <div className="px-4 py-3 border-b border-surface-light">
          <h2 className="font-semibold text-lg">Round History</h2>
        </div>
        {rounds.length === 0 ? (
          <div className="p-8 text-center text-muted">
            No rounds posted yet this season.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-surface-light text-muted text-sm">
                  <th className="text-left py-3 px-3">Date</th>
                  <th className="text-left py-3 px-3">Course</th>
                  <th className="text-center py-3 px-3">Gross</th>
                  <th className="text-center py-3 px-3">HCP</th>
                  <th className="text-center py-3 px-3">Net</th>
                  <th className="text-center py-3 px-3">vs Par</th>
                  <th className="text-right py-3 px-3">Points</th>
                </tr>
              </thead>
              <tbody>
                {rounds.map((round) => {
                  const isTop10 = best10.some((r) => r.id === round.id);
                  return (
                    <tr
                      key={round.id}
                      className={`border-b border-surface-light/50 ${
                        isTop10 ? "bg-surface-light/20" : "opacity-60"
                      }`}
                    >
                      <td className="py-3 px-3 text-sm">
                        {formatDate(round.played_at)}
                      </td>
                      <td className="py-3 px-3 text-sm">
                        {round.course_name}
                      </td>
                      <td className="py-3 px-3 text-center text-sm">
                        {round.gross_score}
                      </td>
                      <td className="py-3 px-3 text-center text-sm text-muted">
                        {round.course_handicap}
                      </td>
                      <td className="py-3 px-3 text-center text-sm font-medium">
                        {round.net_score}
                      </td>
                      <td className="py-3 px-3 text-center text-sm">
                        {formatNetVsPar(round.net_vs_par)}
                      </td>
                      <td className="py-3 px-3 text-right font-bold text-gold">
                        {round.points}
                        {isTop10 && (
                          <span className="ml-1 text-xs text-accent-light">
                            *
                          </span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
        {rounds.length > 10 && (
          <div className="px-4 py-2 text-xs text-muted border-t border-surface-light">
            * = counts toward season total (best 10)
          </div>
        )}
      </div>
    </div>
  );
}
