import { createClient } from "@/lib/supabase/server";
import LeaderboardTable from "@/components/leaderboard/LeaderboardTable";
import { Season, SeasonStanding, Player } from "@/lib/types";

export const revalidate = 60;

export default async function Home() {
  const supabase = await createClient();

  const { data: season } = await supabase
    .from("seasons")
    .select("*")
    .eq("is_active", true)
    .single<Season>();

  let standings: SeasonStanding[] = [];
  if (season) {
    const { data } = await supabase
      .from("season_standings")
      .select("*")
      .eq("season_id", season.id);
    standings = (data as SeasonStanding[]) || [];
  }

  const { data: allPlayers } = await supabase
    .from("players")
    .select("*")
    .eq("is_active", true);

  const playersWithoutRounds = ((allPlayers as Player[]) || []).filter(
    (p) => !standings.some((s) => s.player_id === p.id)
  );

  return (
    <div className="max-w-5xl mx-auto px-4 py-8">
      {/* Hero */}
      <div className="text-center mb-10">
        <h1 className="text-4xl font-bold mb-2">
          <span className="text-gold">The Homie Cup</span>
        </h1>
        {season && (
          <p className="text-muted">
            {season.name} &middot; Best {season.top_n_rounds} of your rounds
            &middot; Min {season.min_rounds} to qualify
          </p>
        )}
      </div>

      {/* Leaderboard */}
      <div className="bg-surface rounded-xl border border-surface-light overflow-hidden">
        <div className="px-4 py-3 border-b border-surface-light flex items-center justify-between">
          <h2 className="font-semibold text-lg">Season Standings</h2>
          <span className="text-xs text-muted">
            Points = 10 - (net vs par), min 1, max 15
          </span>
        </div>
        <LeaderboardTable standings={standings} />
      </div>

      {/* Players who haven't posted yet */}
      {playersWithoutRounds.length > 0 && (
        <div className="mt-6 text-center">
          <p className="text-sm text-muted">
            Still waiting on:{" "}
            {playersWithoutRounds.map((p) => p.display_name).join(", ")}
          </p>
        </div>
      )}

      {/* How it works */}
      <div className="mt-12 grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-surface rounded-lg border border-surface-light p-5">
          <p className="text-2xl mb-2">🏌️</p>
          <h3 className="font-semibold mb-1">Play Anywhere</h3>
          <p className="text-sm text-muted">
            Play any course, any time, with anyone. Every round counts toward
            the cup.
          </p>
        </div>
        <div className="bg-surface rounded-lg border border-surface-light p-5">
          <p className="text-2xl mb-2">📊</p>
          <h3 className="font-semibold mb-1">Handicap Adjusted</h3>
          <p className="text-sm text-muted">
            Points are based on your net score. A 20-handicap has the same shot
            at winning as a scratch golfer.
          </p>
        </div>
        <div className="bg-surface rounded-lg border border-surface-light p-5">
          <p className="text-2xl mb-2">🏆</p>
          <h3 className="font-semibold mb-1">Best 10 Count</h3>
          <p className="text-sm text-muted">
            Your top 10 rounds score. Play at least 5 to qualify. Quality and
            consistency win the cup.
          </p>
        </div>
      </div>
    </div>
  );
}
