import { createClient } from "@/lib/supabase/server";
import ActivityFeed from "@/components/feed/ActivityFeed";
import { generateMilestones, generateWeeklyRecap } from "@/lib/milestones";
import type {
  Season,
  FeedRound,
  RoundReaction,
  RoundComment,
  SeasonStanding,
  UpcomingRound,
  UpcomingRoundRsvp,
} from "@/lib/types";

export const revalidate = 60;

interface CommentWithPlayer extends RoundComment {
  player_name: string;
}

interface RsvpWithPlayer extends UpcomingRoundRsvp {
  player_name: string;
}

interface UpcomingRoundWithOrganizer extends UpcomingRound {
  organizer_name: string;
}

export default async function FeedPage() {
  const supabase = await createClient();

  // Get current user + player
  const {
    data: { user },
  } = await supabase.auth.getUser();

  let currentPlayerId: string | null = null;
  if (user) {
    const { data: player } = await supabase
      .from("players")
      .select("id")
      .eq("auth_user_id", user.id)
      .single();
    currentPlayerId = player?.id ?? null;
  }

  // Fetch active season
  const { data: season } = await supabase
    .from("seasons")
    .select("*")
    .eq("is_active", true)
    .single<Season>();

  if (!season) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-8">
        <h1 className="text-2xl font-bold text-white mb-4">Feed</h1>
        <p className="text-muted">No active season.</p>
      </div>
    );
  }

  // Fetch recent rounds with player info
  const { data: roundsRaw } = await supabase
    .from("rounds")
    .select("*, player:players(id, display_name, slug, avatar_url)")
    .eq("season_id", season.id)
    .order("created_at", { ascending: false })
    .limit(30);

  const rounds = (roundsRaw as FeedRound[]) || [];
  const roundIds = rounds.map((r) => r.id);

  // Fetch reactions + comments + standings + upcoming rounds in parallel
  const [reactionsResult, commentsResult, standingsResult, upcomingResult] =
    await Promise.all([
      roundIds.length > 0
        ? supabase
            .from("round_reactions")
            .select("*")
            .in("round_id", roundIds)
        : Promise.resolve({ data: [] }),
      roundIds.length > 0
        ? supabase
            .from("round_comments")
            .select("*, player:players(display_name)")
            .in("round_id", roundIds)
            .order("created_at", { ascending: true })
        : Promise.resolve({ data: [] }),
      supabase
        .from("season_standings")
        .select("*")
        .eq("season_id", season.id),
      supabase
        .from("upcoming_rounds")
        .select("*, organizer:players(display_name)")
        .gte("tee_time", new Date().toISOString())
        .order("tee_time", { ascending: true }),
    ]);

  const reactions = (reactionsResult.data as RoundReaction[]) || [];
  const standings = (standingsResult.data as SeasonStanding[]) || [];

  // Group reactions by round
  const reactionsByRound: Record<string, RoundReaction[]> = {};
  for (const r of reactions) {
    if (!reactionsByRound[r.round_id]) reactionsByRound[r.round_id] = [];
    reactionsByRound[r.round_id].push(r);
  }

  // Group comments by round with player names
  const commentsByRound: Record<string, CommentWithPlayer[]> = {};
  for (const c of (commentsResult.data || []) as Array<
    RoundComment & { player: { display_name: string } }
  >) {
    const comment: CommentWithPlayer = {
      id: c.id,
      round_id: c.round_id,
      player_id: c.player_id,
      body: c.body,
      created_at: c.created_at,
      player_name: c.player?.display_name ?? "Unknown",
    };
    if (!commentsByRound[c.round_id]) commentsByRound[c.round_id] = [];
    commentsByRound[c.round_id].push(comment);
  }

  // Process upcoming rounds
  const upcomingRoundsRaw = (upcomingResult.data || []) as Array<
    UpcomingRound & { organizer: { display_name: string } }
  >;
  const upcomingRounds: UpcomingRoundWithOrganizer[] = upcomingRoundsRaw.map(
    (ur) => ({
      id: ur.id,
      player_id: ur.player_id,
      course_name: ur.course_name,
      tee_time: ur.tee_time,
      notes: ur.notes,
      created_at: ur.created_at,
      organizer_name: ur.organizer?.display_name ?? "Unknown",
    })
  );

  // Fetch RSVPs for upcoming rounds
  const upcomingIds = upcomingRounds.map((ur) => ur.id);
  const rsvpsByRound: Record<string, RsvpWithPlayer[]> = {};
  if (upcomingIds.length > 0) {
    const { data: rsvpsRaw } = await supabase
      .from("upcoming_round_rsvps")
      .select("*, player:players(display_name)")
      .in("upcoming_round_id", upcomingIds);

    for (const r of (rsvpsRaw || []) as Array<
      UpcomingRoundRsvp & { player: { display_name: string } }
    >) {
      const rsvp: RsvpWithPlayer = {
        id: r.id,
        upcoming_round_id: r.upcoming_round_id,
        player_id: r.player_id,
        status: r.status,
        created_at: r.created_at,
        player_name: r.player?.display_name ?? "Unknown",
      };
      if (!rsvpsByRound[r.upcoming_round_id])
        rsvpsByRound[r.upcoming_round_id] = [];
      rsvpsByRound[r.upcoming_round_id].push(rsvp);
    }
  }

  // Generate milestones and weekly recap
  const milestones = generateMilestones(rounds, standings, season);
  const weeklyRecap = generateWeeklyRecap(rounds, standings);

  return (
    <div className="max-w-2xl mx-auto px-4 py-6 sm:py-8">
      <h1 className="text-2xl sm:text-3xl font-bold text-white mb-6">Feed</h1>

      <ActivityFeed
        rounds={rounds}
        reactionsByRound={reactionsByRound}
        commentsByRound={commentsByRound}
        upcomingRounds={upcomingRounds}
        rsvpsByRound={rsvpsByRound}
        milestones={milestones}
        weeklyRecap={weeklyRecap}
        currentPlayerId={currentPlayerId}
      />
    </div>
  );
}
