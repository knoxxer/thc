"use client";

import Link from "next/link";
import ReactionBar from "./ReactionBar";
import CommentSection from "./CommentSection";
import type { FeedRound, RoundReaction, RoundComment } from "@/lib/types";

interface CommentWithPlayer extends RoundComment {
  player_name: string;
}

interface FeedCardProps {
  round: FeedRound;
  reactions: RoundReaction[];
  comments: CommentWithPlayer[];
  currentPlayerId: string | null;
}

function formatDate(dateStr: string): string {
  const d = new Date(dateStr);
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

function formatVsPar(netVsPar: number): string {
  if (netVsPar === 0) return "E";
  return netVsPar > 0 ? `+${netVsPar}` : `${netVsPar}`;
}

export default function FeedCard({
  round,
  reactions,
  comments,
  currentPlayerId,
}: FeedCardProps) {
  return (
    <div className="bg-surface rounded-xl border border-surface-light p-4 sm:p-5">
      {/* Header: avatar + name + date */}
      <div className="flex items-center gap-3 mb-3">
        <Link href={`/players/${round.player.slug}`}>
          <div className="w-9 h-9 bg-accent rounded-full flex items-center justify-center text-white font-bold text-sm shrink-0">
            {round.player.display_name.charAt(0)}
          </div>
        </Link>
        <div className="flex-1 min-w-0">
          <Link
            href={`/players/${round.player.slug}`}
            className="text-sm font-semibold text-white hover:text-gold transition-colors"
          >
            {round.player.display_name}
          </Link>
          <p className="text-xs text-muted">{round.course_name}</p>
        </div>
        <span className="text-xs text-muted whitespace-nowrap">
          {formatDate(round.played_at)}
        </span>
      </div>

      {/* Score breakdown */}
      <div className="flex items-center gap-2 text-sm mb-3">
        <span className="text-white/70">{round.gross_score} gross</span>
        <span className="text-muted">&middot;</span>
        <span className="text-white/70">{round.net_score} net</span>
        <span className="text-muted">&middot;</span>
        <span className="text-white/90">{formatVsPar(round.net_vs_par)}</span>
        <span className="text-muted">&middot;</span>
        <span className="text-gold font-bold">{round.points ?? 0} pts</span>
      </div>

      {/* Reactions */}
      <ReactionBar
        roundId={round.id}
        reactions={reactions}
        currentPlayerId={currentPlayerId}
        roundOwnerId={round.player_id}
      />

      {/* Comments */}
      <CommentSection
        roundId={round.id}
        comments={comments}
        currentPlayerId={currentPlayerId}
        roundOwnerId={round.player_id}
      />
    </div>
  );
}
