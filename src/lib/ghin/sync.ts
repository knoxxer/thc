import { createClient } from "@supabase/supabase-js";
import { lookupGolfer, getScores } from "./client";
import { calculatePoints } from "../points";

function getServiceClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}

export interface SyncResult {
  player: string;
  scoresFound: number;
  scoresImported: number;
  handicapIndex: number | null;
  errors: string[];
}

export async function syncPlayer(
  playerId: string,
  ghinNumber: string,
  seasonId: string,
  seasonStart: string,
  seasonEnd: string
): Promise<SyncResult> {
  const result: SyncResult = {
    player: "",
    scoresFound: 0,
    scoresImported: 0,
    handicapIndex: null,
    errors: [],
  };

  const supabase = getServiceClient();

  try {
    // Look up golfer info and update handicap
    const golfer = await lookupGolfer(Number(ghinNumber));
    if (golfer) {
      result.player = `${golfer.first_name} ${golfer.last_name}`;
      const hi =
        typeof golfer.handicap_index === "string"
          ? parseFloat(golfer.handicap_index)
          : golfer.handicap_index;
      result.handicapIndex = hi;

      if (hi != null && !isNaN(hi)) {
        await supabase
          .from("players")
          .update({
            handicap_index: hi,
            handicap_updated_at: new Date().toISOString(),
          })
          .eq("id", playerId);
      }
    }

    // Get scores
    const scores = await getScores(Number(ghinNumber), 50);
    result.scoresFound = scores.length;

    // Filter to season range and 18-hole rounds only
    const seasonScores = scores.filter((s) => {
      if (s.number_of_holes !== 18) return false;
      const playedDate = s.played_at;
      return playedDate >= seasonStart && playedDate <= seasonEnd;
    });

    for (const score of seasonScores) {
      // Check if already imported
      const { data: existing } = await supabase
        .from("rounds")
        .select("id")
        .eq("ghin_score_id", String(score.id))
        .maybeSingle();

      if (existing) continue;

      // Calculate course handicap from handicap index
      const hi = result.handicapIndex || 0;
      const courseHandicap = Math.round(
        hi * (score.slope_rating / 113) + (score.course_rating - 72)
      );
      const par = 72; // default, GHIN doesn't provide par directly
      const netVsPar = score.adjusted_gross_score - courseHandicap - par;
      const points = calculatePoints(netVsPar);

      const { error } = await supabase.from("rounds").insert({
        player_id: playerId,
        season_id: seasonId,
        played_at: score.played_at,
        course_name: score.course_name,
        tee_name: score.tee_name,
        course_rating: score.course_rating,
        slope_rating: score.slope_rating,
        par,
        gross_score: score.adjusted_gross_score,
        course_handicap: courseHandicap,
        points,
        ghin_score_id: String(score.id),
        source: "ghin",
      });

      if (error) {
        result.errors.push(`Score ${score.id}: ${error.message}`);
      } else {
        result.scoresImported++;
      }
    }
  } catch (err) {
    result.errors.push(String(err));
  }

  return result;
}

export async function syncAllPlayers(): Promise<SyncResult[]> {
  const supabase = getServiceClient();

  // Get active season
  const { data: season } = await supabase
    .from("seasons")
    .select("*")
    .eq("is_active", true)
    .single();

  if (!season) throw new Error("No active season found");

  // Get all players with GHIN numbers
  const { data: players } = await supabase
    .from("players")
    .select("*")
    .eq("is_active", true)
    .not("ghin_number", "is", null);

  if (!players || players.length === 0) {
    return [];
  }

  const results: SyncResult[] = [];

  for (const player of players) {
    const result = await syncPlayer(
      player.id,
      player.ghin_number,
      season.id,
      season.starts_at,
      season.ends_at
    );
    result.player = player.name;
    results.push(result);
  }

  return results;
}
