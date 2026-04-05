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

      {/* Rules & Points */}
      <div className="mt-16 mb-8">
        <h2 className="text-2xl font-bold text-center mb-8 text-white">Rules & Points</h2>

        {/* Season Rules */}
        <div className="bg-surface rounded-xl border border-surface-light p-6 mb-6">
          <h3 className="font-bold text-white mb-4">Season Format</h3>
          <ul className="space-y-3 text-sm">
            <li className="flex items-start gap-3">
              <span className="text-gold font-bold mt-0.5">1.</span>
              <span className="text-muted">
                <span className="text-foreground font-medium">Play any 18-hole round, anywhere, anytime.</span>{" "}
                Solo, with homies, with strangers — doesn&apos;t matter. Every round counts.
              </span>
            </li>
            <li className="flex items-start gap-3">
              <span className="text-gold font-bold mt-0.5">2.</span>
              <span className="text-muted">
                <span className="text-foreground font-medium">Post your score.</span>{" "}
                Scores sync automatically via GHIN, or you can post manually. You need a GHIN handicap.
              </span>
            </li>
            <li className="flex items-start gap-3">
              <span className="text-gold font-bold mt-0.5">3.</span>
              <span className="text-muted">
                <span className="text-foreground font-medium">Minimum 5 rounds to qualify.</span>{" "}
                You must play at least 5 rounds during the season to be eligible for the cup.
              </span>
            </li>
            <li className="flex items-start gap-3">
              <span className="text-gold font-bold mt-0.5">4.</span>
              <span className="text-muted">
                <span className="text-foreground font-medium">Only your best 10 rounds count.</span>{" "}
                Play as many rounds as you want — only your top 10 point scores go toward your season total.
                Bad round? It falls off. Grind more rounds for more chances to post bangers.
              </span>
            </li>
            <li className="flex items-start gap-3">
              <span className="text-gold font-bold mt-0.5">5.</span>
              <span className="text-muted">
                <span className="text-foreground font-medium">Season runs March to March.</span>{" "}
                Season 1: March 2026 – February 2027. Highest point total at season end wins the cup.
              </span>
            </li>
          </ul>
        </div>

        {/* Points Table */}
        <div className="bg-surface rounded-xl border border-surface-light p-6 mb-6">
          <h3 className="font-bold text-white mb-2">Points Per Round</h3>
          <p className="text-sm text-muted mb-4">
            Points are based on your <span className="text-foreground">net score vs par</span>.
            Net score = gross score minus your course handicap.
            A 30-handicap shooting 102 earns the same points as a scratch golfer shooting 72.
          </p>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-surface-light text-muted text-xs uppercase tracking-wider">
                  <th className="text-left py-2 px-3">Net vs Par</th>
                  <th className="text-center py-2 px-3">Points</th>
                  <th className="text-left py-2 px-3 hidden sm:table-cell">Translation</th>
                </tr>
              </thead>
              <tbody className="tabular-nums">
                <tr className="border-b border-surface-light/30">
                  <td className="py-2 px-3 text-gold font-semibold">-5 or better</td>
                  <td className="py-2 px-3 text-center text-gold font-bold">15</td>
                  <td className="py-2 px-3 text-muted hidden sm:table-cell">Legendary round (max points)</td>
                </tr>
                <tr className="border-b border-surface-light/30">
                  <td className="py-2 px-3">-3</td>
                  <td className="py-2 px-3 text-center font-semibold">13</td>
                  <td className="py-2 px-3 text-muted hidden sm:table-cell">Absolutely cooking</td>
                </tr>
                <tr className="border-b border-surface-light/30">
                  <td className="py-2 px-3">-1</td>
                  <td className="py-2 px-3 text-center font-semibold">11</td>
                  <td className="py-2 px-3 text-muted hidden sm:table-cell">Great round</td>
                </tr>
                <tr className="border-b border-surface-light/30 bg-accent/20">
                  <td className="py-2 px-3 font-semibold">Even (E)</td>
                  <td className="py-2 px-3 text-center font-bold">10</td>
                  <td className="py-2 px-3 text-muted hidden sm:table-cell">Played to your handicap — solid</td>
                </tr>
                <tr className="border-b border-surface-light/30">
                  <td className="py-2 px-3">+2</td>
                  <td className="py-2 px-3 text-center font-semibold">8</td>
                  <td className="py-2 px-3 text-muted hidden sm:table-cell">Decent day out</td>
                </tr>
                <tr className="border-b border-surface-light/30">
                  <td className="py-2 px-3">+5</td>
                  <td className="py-2 px-3 text-center font-semibold">5</td>
                  <td className="py-2 px-3 text-muted hidden sm:table-cell">Rough one</td>
                </tr>
                <tr>
                  <td className="py-2 px-3">+10 or worse</td>
                  <td className="py-2 px-3 text-center font-semibold">1</td>
                  <td className="py-2 px-3 text-muted hidden sm:table-cell">You showed up (floor — always get 1)</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p className="text-xs text-muted mt-4">
            Formula: <span className="font-mono text-foreground">points = max(1, min(15, 10 - netVsPar))</span>.
            Theoretical season max: 150 pts (ten rounds at 15). Realistic competitive range: 80–120.
          </p>
        </div>

        {/* Examples */}
        <div className="bg-surface rounded-xl border border-surface-light p-6">
          <h3 className="font-bold text-white mb-4">Example Rounds</h3>
          <div className="space-y-3 text-sm">
            <div className="flex items-center justify-between py-2 border-b border-surface-light/30">
              <div>
                <span className="text-foreground">20-handicap shoots 89 on a par 72</span>
                <span className="text-muted ml-2">→ net 69 → 3 under</span>
              </div>
              <span className="text-gold font-bold">13 pts</span>
            </div>
            <div className="flex items-center justify-between py-2 border-b border-surface-light/30">
              <div>
                <span className="text-foreground">10-handicap shoots 82 on a par 72</span>
                <span className="text-muted ml-2">→ net 72 → even</span>
              </div>
              <span className="text-gold font-bold">10 pts</span>
            </div>
            <div className="flex items-center justify-between py-2 border-b border-surface-light/30">
              <div>
                <span className="text-foreground">30-handicap shoots 107 on a par 72</span>
                <span className="text-muted ml-2">→ net 77 → 5 over</span>
              </div>
              <span className="text-gold font-bold">5 pts</span>
            </div>
            <div className="flex items-center justify-between py-2">
              <div>
                <span className="text-foreground">5-handicap shoots 71 on a par 72</span>
                <span className="text-muted ml-2">→ net 66 → 6 under</span>
              </div>
              <span className="text-gold font-bold">15 pts (capped)</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
