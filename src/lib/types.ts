export interface Player {
  id: string;
  name: string;
  display_name: string;
  slug: string;
  email: string | null;
  ghin_number: string | null;
  handicap_index: number | null;
  handicap_updated_at: string | null;
  avatar_url: string | null;
  is_active: boolean;
  role: "admin" | "contributor";
  auth_user_id: string | null;
  created_at: string;
}

export interface Season {
  id: string;
  name: string;
  starts_at: string;
  ends_at: string;
  is_active: boolean;
  min_rounds: number;
  top_n_rounds: number;
  created_at: string;
}

export interface Round {
  id: string;
  player_id: string;
  season_id: string;
  played_at: string;
  course_name: string;
  tee_name: string | null;
  course_rating: number | null;
  slope_rating: number | null;
  par: number;
  gross_score: number;
  course_handicap: number;
  net_score: number;
  net_vs_par: number;
  points: number | null;
  ghin_score_id: string | null;
  source: "manual" | "ghin";
  entered_by: string | null;
  created_at: string;
}

export interface SeasonStanding {
  player_id: string;
  season_id: string;
  player_name: string;
  player_slug: string;
  handicap_index: number | null;
  avatar_url: string | null;
  total_rounds: number;
  is_eligible: boolean;
  best_n_points: number;
  best_round_points: number;
  best_net_vs_par: number;
}

export interface RoundReaction {
  id: string;
  round_id: string;
  player_id: string;
  emoji: string;
  comment: string | null;
  created_at: string;
}

export interface RoundComment {
  id: string;
  round_id: string;
  player_id: string;
  body: string;
  created_at: string;
}

export interface FeedRound extends Round {
  player: Pick<Player, "id" | "display_name" | "slug" | "avatar_url">;
}

export interface UpcomingRound {
  id: string;
  player_id: string;
  course_name: string;
  tee_time: string;
  notes: string | null;
  created_at: string;
}

export interface UpcomingRoundRsvp {
  id: string;
  upcoming_round_id: string;
  player_id: string;
  status: "in" | "maybe" | "out";
  created_at: string;
}

export interface Notification {
  id: string;
  player_id: string;
  type: "new_round" | "reaction" | "comment" | "rsvp" | "upcoming_round";
  title: string;
  body: string | null;
  link: string | null;
  is_read: boolean;
  metadata: Record<string, unknown> | null;
  created_at: string;
}

export interface Milestone {
  type: "season_best" | "rank_change" | "streak" | "first_round" | "eligibility" | "points_milestone";
  title: string;
  description: string;
  playerName: string;
  playerSlug: string;
  timestamp: string;
}

export interface CommentWithPlayer extends RoundComment {
  player_name: string;
}

export interface RsvpWithPlayer extends UpcomingRoundRsvp {
  player_name: string;
}

export interface UpcomingRoundWithOrganizer extends UpcomingRound {
  organizer_name: string;
}

export interface WeeklyRecapData {
  weekLabel: string;
  roundsPosted: number;
  bestRound: { playerName: string; courseName: string; points: number } | null;
  totalPoints: number;
  biggestMover: { playerName: string; rank: number } | null;
}
