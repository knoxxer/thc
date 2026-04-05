import Link from "next/link";

export default function RulesPage() {
  return (
    <div className="max-w-3xl mx-auto px-4 py-8">
      <Link
        href="/"
        className="text-sm text-muted hover:text-foreground transition-colors"
      >
        &larr; Back to Leaderboard
      </Link>

      <h1 className="text-4xl font-bold mt-6 mb-8 text-white">
        Rules & Points
      </h1>

      {/* Season Rules */}
      <div className="bg-surface rounded-xl border border-surface-light p-4 sm:p-6 mb-6">
        <h2 className="font-bold text-white mb-4 text-xl">Season Format</h2>
        <ul className="space-y-3 text-sm">
          <li className="flex items-start gap-3">
            <span className="text-gold font-bold mt-0.5">1.</span>
            <span className="text-muted">
              <span className="text-foreground font-medium">
                Play any 18-hole round, anywhere, anytime.
              </span>{" "}
              Solo, with homies, with strangers — doesn&apos;t matter. Every
              round counts.
            </span>
          </li>
          <li className="flex items-start gap-3">
            <span className="text-gold font-bold mt-0.5">2.</span>
            <span className="text-muted">
              <span className="text-foreground font-medium">
                Post your score.
              </span>{" "}
              Scores sync automatically via GHIN, or you can post manually. You
              need a GHIN handicap.
            </span>
          </li>
          <li className="flex items-start gap-3">
            <span className="text-gold font-bold mt-0.5">3.</span>
            <span className="text-muted">
              <span className="text-foreground font-medium">
                Minimum 5 rounds to qualify.
              </span>{" "}
              You must play at least 5 rounds during the season to be eligible
              for the cup.
            </span>
          </li>
          <li className="flex items-start gap-3">
            <span className="text-gold font-bold mt-0.5">4.</span>
            <span className="text-muted">
              <span className="text-foreground font-medium">
                Only your best 10 rounds count.
              </span>{" "}
              Play as many rounds as you want — only your top 10 point scores go
              toward your season total. Bad round? It falls off. Grind more
              rounds for more chances to post bangers.
            </span>
          </li>
          <li className="flex items-start gap-3">
            <span className="text-gold font-bold mt-0.5">5.</span>
            <span className="text-muted">
              <span className="text-foreground font-medium">
                Season runs March to March.
              </span>{" "}
              Season 1: March 2026 – February 2027. Highest point total at
              season end wins the cup.
            </span>
          </li>
        </ul>
      </div>

      {/* Points Table */}
      <div className="bg-surface rounded-xl border border-surface-light p-4 sm:p-6 mb-6">
        <h2 className="font-bold text-white mb-2 text-xl">Points Per Round</h2>
        <p className="text-sm text-muted mb-4">
          Points are based on your{" "}
          <span className="text-foreground">net score vs par</span>. Net score =
          gross score minus your course handicap. A 30-handicap shooting 102
          earns the same points as a scratch golfer shooting 72.
        </p>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-surface-light text-muted text-xs uppercase tracking-wider">
                <th className="text-left py-2 px-3">Net vs Par</th>
                <th className="text-center py-2 px-3">Points</th>
                <th className="text-left py-2 px-3 hidden sm:table-cell">
                  Translation
                </th>
              </tr>
            </thead>
            <tbody className="tabular-nums">
              <tr className="border-b border-surface-light/30">
                <td className="py-2 px-3 text-gold font-semibold">
                  -5 or better
                </td>
                <td className="py-2 px-3 text-center text-gold font-bold">
                  15
                </td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  Legendary round (max points)
                </td>
              </tr>
              <tr className="border-b border-surface-light/30">
                <td className="py-2 px-3">-4</td>
                <td className="py-2 px-3 text-center font-semibold">14</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  On fire
                </td>
              </tr>
              <tr className="border-b border-surface-light/30">
                <td className="py-2 px-3">-3</td>
                <td className="py-2 px-3 text-center font-semibold">13</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  Absolutely cooking
                </td>
              </tr>
              <tr className="border-b border-surface-light/30">
                <td className="py-2 px-3">-2</td>
                <td className="py-2 px-3 text-center font-semibold">12</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  Dialed in
                </td>
              </tr>
              <tr className="border-b border-surface-light/30">
                <td className="py-2 px-3">-1</td>
                <td className="py-2 px-3 text-center font-semibold">11</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  Great round
                </td>
              </tr>
              <tr className="border-b border-surface-light/30 bg-accent/20">
                <td className="py-2 px-3 font-semibold">Even (E)</td>
                <td className="py-2 px-3 text-center font-bold">10</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  Played to your handicap — solid
                </td>
              </tr>
              <tr className="border-b border-surface-light/30">
                <td className="py-2 px-3">+1</td>
                <td className="py-2 px-3 text-center font-semibold">9</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  Not bad
                </td>
              </tr>
              <tr className="border-b border-surface-light/30">
                <td className="py-2 px-3">+2</td>
                <td className="py-2 px-3 text-center font-semibold">8</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  Decent day out
                </td>
              </tr>
              <tr className="border-b border-surface-light/30">
                <td className="py-2 px-3">+3</td>
                <td className="py-2 px-3 text-center font-semibold">7</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  Could be worse
                </td>
              </tr>
              <tr className="border-b border-surface-light/30">
                <td className="py-2 px-3">+4</td>
                <td className="py-2 px-3 text-center font-semibold">6</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  Meh
                </td>
              </tr>
              <tr className="border-b border-surface-light/30">
                <td className="py-2 px-3">+5</td>
                <td className="py-2 px-3 text-center font-semibold">5</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  Rough one
                </td>
              </tr>
              <tr className="border-b border-surface-light/30">
                <td className="py-2 px-3">+6</td>
                <td className="py-2 px-3 text-center font-semibold">4</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  Pain
                </td>
              </tr>
              <tr className="border-b border-surface-light/30">
                <td className="py-2 px-3">+7</td>
                <td className="py-2 px-3 text-center font-semibold">3</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  Suffering
                </td>
              </tr>
              <tr className="border-b border-surface-light/30">
                <td className="py-2 px-3">+8</td>
                <td className="py-2 px-3 text-center font-semibold">2</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  At least the beer was cold
                </td>
              </tr>
              <tr className="border-b border-surface-light/30">
                <td className="py-2 px-3">+9</td>
                <td className="py-2 px-3 text-center font-semibold">1</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  Participation trophy
                </td>
              </tr>
              <tr>
                <td className="py-2 px-3">+10 or worse</td>
                <td className="py-2 px-3 text-center font-semibold">1</td>
                <td className="py-2 px-3 text-muted hidden sm:table-cell">
                  You showed up (floor — always get 1)
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <p className="text-xs text-muted mt-4">
          Formula:{" "}
          <span className="font-mono text-foreground">
            points = max(1, min(15, 10 - netVsPar))
          </span>
          . Theoretical season max: 150 pts (ten rounds at 15). Realistic
          competitive range: 80–120.
        </p>
      </div>

      {/* Examples */}
      <div className="bg-surface rounded-xl border border-surface-light p-4 sm:p-6 mb-6">
        <h2 className="font-bold text-white mb-4 text-xl">Example Rounds</h2>
        <div className="space-y-4 text-sm">
          <div className="py-2 border-b border-surface-light/30">
            <div className="flex items-center justify-between">
              <span className="text-foreground">20-hcp shoots 89 (par 72)</span>
              <span className="text-gold font-bold">13 pts</span>
            </div>
            <p className="text-xs text-muted mt-1">89 - 20 = net 69 → 3 under par</p>
          </div>
          <div className="py-2 border-b border-surface-light/30">
            <div className="flex items-center justify-between">
              <span className="text-foreground">10-hcp shoots 82 (par 72)</span>
              <span className="text-gold font-bold">10 pts</span>
            </div>
            <p className="text-xs text-muted mt-1">82 - 10 = net 72 → even par</p>
          </div>
          <div className="py-2 border-b border-surface-light/30">
            <div className="flex items-center justify-between">
              <span className="text-foreground">30-hcp shoots 107 (par 72)</span>
              <span className="text-gold font-bold">5 pts</span>
            </div>
            <p className="text-xs text-muted mt-1">107 - 30 = net 77 → 5 over par</p>
          </div>
          <div className="py-2">
            <div className="flex items-center justify-between">
              <span className="text-foreground">5-hcp shoots 71 (par 72)</span>
              <span className="text-gold font-bold">15 pts</span>
            </div>
            <p className="text-xs text-muted mt-1">71 - 5 = net 66 → 6 under (capped at 15)</p>
          </div>
        </div>
      </div>

      {/* FAQ */}
      <div className="bg-surface rounded-xl border border-surface-light p-4 sm:p-6">
        <h2 className="font-bold text-white mb-4 text-xl">FAQ</h2>
        <div className="space-y-4 text-sm">
          <div>
            <p className="text-foreground font-medium">
              What if I play more than 10 rounds?
            </p>
            <p className="text-muted mt-1">
              Only your best 10 count. Your worst rounds automatically drop off.
              More rounds = more chances to replace a bad score with a good one.
            </p>
          </div>
          <div>
            <p className="text-foreground font-medium">
              Do 9-hole rounds count?
            </p>
            <p className="text-muted mt-1">
              No. Only 18-hole rounds are eligible.
            </p>
          </div>
          <div>
            <p className="text-foreground font-medium">
              What handicap is used?
            </p>
            <p className="text-muted mt-1">
              Your course handicap for the specific tees you played. This is
              your GHIN handicap index adjusted for course rating and slope.
              Check the GHIN app before your round.
            </p>
          </div>
          <div>
            <p className="text-foreground font-medium">
              Can I play the same course every time?
            </p>
            <p className="text-muted mt-1">
              Yes. Play wherever you want, as many times as you want.
            </p>
          </div>
          <div>
            <p className="text-foreground font-medium">
              What happens if two players tie?
            </p>
            <p className="text-muted mt-1">
              Tiebreaker goes to the player with the single best round. If still
              tied, most rounds played wins.
            </p>
          </div>
          <div>
            <p className="text-foreground font-medium">
              Is there a penalty for a bad round?
            </p>
            <p className="text-muted mt-1">
              No. You always earn at least 1 point for showing up. And if it&apos;s
              not in your best 10, it doesn&apos;t hurt your season total at all.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
