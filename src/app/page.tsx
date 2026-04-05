import Image from "next/image";
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
      <div className="text-center mb-12">
        <Image
          src="/logo.png"
          alt="The Homie Cup"
          width={120}
          height={120}
          className="mx-auto mb-4 rounded-full"
          priority
        />
        <h1 className="text-4xl md:text-5xl font-bold mb-3 text-white">
          Season Standings
        </h1>
        {season && (
          <p className="text-muted text-lg">
            {season.name}
          </p>
        )}
        {season && (
          <p className="text-muted/60 text-sm mt-1">
            Best {season.top_n_rounds} rounds count &middot; Min {season.min_rounds} to qualify
          </p>
        )}
      </div>

      {/* Leaderboard */}
      <div className="bg-surface rounded-xl border border-surface-light overflow-hidden shadow-lg shadow-black/20">
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
      <div className="mt-16 mb-8">
        <h2 className="text-2xl font-bold text-center mb-8 text-white">How It Works</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-surface rounded-xl border border-surface-light p-6 text-center">
            <div className="w-12 h-12 bg-accent-light/20 rounded-full flex items-center justify-center mx-auto mb-4">
              <span className="text-accent-light text-xl">1</span>
            </div>
            <h3 className="font-bold mb-2 text-white">Play Anywhere</h3>
            <p className="text-sm text-muted">
              Play any course, any time, with anyone. Every 18-hole round counts.
            </p>
          </div>
          <div className="bg-surface rounded-xl border border-surface-light p-6 text-center">
            <div className="w-12 h-12 bg-accent-light/20 rounded-full flex items-center justify-center mx-auto mb-4">
              <span className="text-accent-light text-xl">2</span>
            </div>
            <h3 className="font-bold mb-2 text-white">Earn Points</h3>
            <p className="text-sm text-muted">
              Points based on your net score vs par. Handicap-adjusted so everyone has a fair shot.
            </p>
          </div>
          <div className="bg-surface rounded-xl border border-surface-light p-6 text-center">
            <div className="w-12 h-12 bg-gold/20 rounded-full flex items-center justify-center mx-auto mb-4">
              <span className="text-gold text-xl">3</span>
            </div>
            <h3 className="font-bold mb-2 text-white">Win The Cup</h3>
            <p className="text-sm text-muted">
              Your top 10 rounds count. Play at least 5 to qualify. Best total wins the cup.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
