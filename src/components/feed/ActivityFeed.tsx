"use client";

import FeedCard from "./FeedCard";
import MilestoneCard from "./MilestoneCard";
import WeeklyRecapCard from "./WeeklyRecapCard";
import UpcomingRoundCard from "./UpcomingRoundCard";
import PostUpcomingForm from "./PostUpcomingForm";
import type {
  FeedRound,
  RoundReaction,
  RoundComment,
  Milestone,
  UpcomingRound,
  UpcomingRoundRsvp,
} from "@/lib/types";

interface CommentWithPlayer extends RoundComment {
  player_name: string;
}

interface RsvpWithPlayer extends UpcomingRoundRsvp {
  player_name: string;
}

interface UpcomingRoundWithOrganizer extends UpcomingRound {
  organizer_name: string;
}

interface WeeklyRecapData {
  weekLabel: string;
  roundsPosted: number;
  bestRound: { playerName: string; courseName: string; points: number } | null;
  totalPoints: number;
  biggestMover: { playerName: string; rank: number } | null;
}

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
      {/* Post upcoming round form */}
      <PostUpcomingForm currentPlayerId={currentPlayerId} />

      {/* Upcoming rounds */}
      {upcomingRounds.map((ur) => (
        <UpcomingRoundCard
          key={ur.id}
          round={ur}
          rsvps={rsvpsByRound[ur.id] || []}
          currentPlayerId={currentPlayerId}
        />
      ))}

      {/* Weekly recap */}
      {weeklyRecap && <WeeklyRecapCard recap={weeklyRecap} />}

      {/* Milestones */}
      {milestones.map((m, i) => (
        <MilestoneCard key={`milestone-${i}`} milestone={m} />
      ))}

      {/* Round feed */}
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
