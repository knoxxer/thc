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

    </div>
  );
}
