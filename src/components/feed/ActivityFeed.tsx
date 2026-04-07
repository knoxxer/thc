"use client";

import FeedCard from "./FeedCard";
import MilestoneCard from "./MilestoneCard";
import WeeklyRecapCard from "./WeeklyRecapCard";
import UpcomingRoundCard from "./UpcomingRoundCard";
import PostUpcomingForm from "./PostUpcomingForm";
import type {
  FeedRound,
  RoundReaction,
  CommentWithPlayer,
  Milestone,
  UpcomingRoundWithOrganizer,
  RsvpWithPlayer,
  WeeklyRecapData,
} from "@/lib/types";

interface ActivityFeedProps {
  rounds: FeedRound[];
  reactionsByRound: Record<string, RoundReaction[]>;
  commentsByRound: Record<string, CommentWithPlayer[]>;
  upcomingRounds: UpcomingRoundWithOrganizer[];
  rsvpsByRound: Record<string, RsvpWithPlayer[]>;
  milestones: Milestone[];
  weeklyRecap: WeeklyRecapData | null;
  currentPlayerId: string | null;
}

export default function ActivityFeed({
  rounds,
  reactionsByRound,
  commentsByRound,
  upcomingRounds,
  rsvpsByRound,
  milestones,
  weeklyRecap,
  currentPlayerId,
}: ActivityFeedProps) {
  return (
    <div className="space-y-4">
      <PostUpcomingForm currentPlayerId={currentPlayerId} />

      {upcomingRounds.map((ur) => (
        <UpcomingRoundCard
          key={ur.id}
          round={ur}
          rsvps={rsvpsByRound[ur.id] || []}
          currentPlayerId={currentPlayerId}
        />
      ))}

      {weeklyRecap && <WeeklyRecapCard recap={weeklyRecap} />}

      {milestones.map((m, i) => (
        <MilestoneCard key={`milestone-${i}`} milestone={m} />
      ))}

      {rounds.length === 0 ? (
        <div className="bg-surface rounded-xl border border-surface-light p-8 text-center">
          <p className="text-muted">No rounds posted yet this season.</p>
        </div>
      ) : (
        rounds.map((round) => (
          <FeedCard
            key={round.id}
            round={round}
            reactions={reactionsByRound[round.id] || []}
            comments={commentsByRound[round.id] || []}
            currentPlayerId={currentPlayerId}
          />
        ))
      )}
    </div>
  );
}
