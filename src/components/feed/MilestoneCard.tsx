import Link from "next/link";
import type { Milestone } from "@/lib/types";

const typeEmojis: Record<Milestone["type"], string> = {
  season_best: "\ud83c\udfc6",
  rank_change: "\ud83d\udcc8",
  streak: "\ud83d\udd25",
  first_round: "\ud83d\udc4b",
  eligibility: "\u2705",
  points_milestone: "\ud83d\udcaf",
};

interface MilestoneCardProps {
  milestone: Milestone;
}

export default function MilestoneCard({ milestone }: MilestoneCardProps) {
  return (
    <div className="bg-gold/5 rounded-xl border border-gold/30 p-4 sm:p-5">
      <div className="flex items-start gap-3">
        <span className="text-xl mt-0.5">
          {typeEmojis[milestone.type] || "\u2b50"}
        </span>
        <div className="flex-1">
          <h3 className="text-sm font-bold text-gold">{milestone.title}</h3>
          <p className="text-sm text-white/80 mt-0.5">
            {milestone.description}
          </p>
          <Link
            href={`/players/${milestone.playerSlug}`}
            className="text-xs text-gold/70 hover:text-gold transition-colors mt-1 inline-block"
          >
            View profile
          </Link>
        </div>
      </div>
    </div>
  );
}
