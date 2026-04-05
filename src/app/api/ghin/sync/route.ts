import { NextResponse } from "next/server";
import { syncAllPlayers, syncPlayer } from "@/lib/ghin/sync";
import { createClient } from "@supabase/supabase-js";

function getServiceClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}

// Vercel cron calls GET
export async function GET(request: Request) {
  // Verify cron secret if set
  const authHeader = request.headers.get("authorization");
  if (process.env.CRON_SECRET && authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const results = await syncAllPlayers();
    return NextResponse.json({ results });
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}

export async function POST(request: Request) {
  // Simple API key check for cron/admin calls
  const { searchParams } = new URL(request.url);
  const playerId = searchParams.get("player_id");

  try {
    if (playerId) {
      // Sync a single player
      const supabase = getServiceClient();
      const { data: player } = await supabase
        .from("players")
        .select("*")
        .eq("id", playerId)
        .single();

      if (!player || !player.ghin_number) {
        return NextResponse.json(
          { error: "Player not found or no GHIN number" },
          { status: 404 }
        );
      }

      const { data: season } = await supabase
        .from("seasons")
        .select("*")
        .eq("is_active", true)
        .single();

      if (!season) {
        return NextResponse.json(
          { error: "No active season" },
          { status: 404 }
        );
      }

      const result = await syncPlayer(
        player.id,
        player.ghin_number,
        season.id,
        season.starts_at,
        season.ends_at
      );
      result.player = player.name;

      return NextResponse.json({ results: [result] });
    } else {
      // Sync all players
      const results = await syncAllPlayers();
      return NextResponse.json({ results });
    }
  } catch (err) {
    return NextResponse.json(
      { error: String(err) },
      { status: 500 }
    );
  }
}
