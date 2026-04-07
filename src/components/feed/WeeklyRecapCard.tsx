import type { WeeklyRecapData } from "@/lib/types";

interface WeeklyRecapCardProps {
  recap: WeeklyRecapData;
}

export default function WeeklyRecapCard({ recap }: WeeklyRecapCardProps) {
  return (
    <div className="bg-surface rounded-xl border border-accent-light/20 p-4 sm:p-5">
      <h3 className="text-sm font-bold text-accent-light mb-3">
        Week in Review ({recap.weekLabel})
      </h3>

      <div className="space-y-1.5 text-sm">
        <p className="text-white/80">
          <span className="text-white font-medium">{recap.roundsPosted}</span>{" "}
          round{recap.roundsPosted !== 1 ? "s" : ""} posted
        </p>

        {recap.bestRound && (
          <p className="text-white/80">
            Best:{" "}
            <span className="text-white font-medium">
              {recap.bestRound.playerName}
            </span>{" "}
            &mdash; {recap.bestRound.courseName} (
            <span className="text-gold font-medium">
              {recap.bestRound.points} pts
            </span>
            )
          </p>
        )}

        {recap.biggestMover && (
          <p className="text-white/80">
            Most active:{" "}
            <span className="text-white font-medium">
              {recap.biggestMover.playerName}
            </span>{" "}
            &rarr; #{recap.biggestMover.rank}
          </p>
        )}

        <p className="text-white/80">
          <span className="text-gold font-medium">{recap.totalPoints}</span>{" "}
          total points earned
        </p>
      </div>
    </div>
  );
}
