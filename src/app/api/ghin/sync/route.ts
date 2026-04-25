import { NextResponse } from "next/server";
import { syncAllPlayers, syncPlayer, type SyncResult } from "@/lib/ghin/sync";
import { getServiceClient } from "@/lib/supabase/service";

type SyncStatus = "success" | "partial" | "failed";

async function recordSyncRun(
  status: SyncStatus,
  playersSynced: number,
  scoresImported: number,
  errorMessage: string | null
) {
  try {
    const supabase = getServiceClient();
    await supabase.from("ghin_sync_runs").insert({
      status,
      players_synced: playersSynced,
      scores_imported: scoresImported,
      error_message: errorMessage,
    });
  } catch (err) {
    console.error("[ghin/sync] failed to record run:", err);
  }
}

function summarize(results: SyncResult[]): {
  status: SyncStatus;
  imported: number;
  errorMessage: string | null;
} {
  const imported = results.reduce((s, r) => s + r.scoresImported, 0);
  const allErrors = results.flatMap((r) =>
    r.errors.map((e) => `${r.player}: ${e}`)
  );
  return {
    status: allErrors.length > 0 ? "partial" : "success",
    imported,
    errorMessage: allErrors.length > 0 ? allErrors.join("\n") : null,
  };
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
    const { status, imported, errorMessage } = summarize(results);
    await recordSyncRun(status, results.length, imported, errorMessage);
    return NextResponse.json({ results });
  } catch (err) {
    console.error("[ghin/sync] cron failed:", err);
    await recordSyncRun("failed", 0, 0, String(err));
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
      const { status, imported, errorMessage } = summarize(results);
      await recordSyncRun(status, results.length, imported, errorMessage);
      return NextResponse.json({ results });
    }
  } catch (err) {
    console.error("[ghin/sync] manual sync failed:", err);
    await recordSyncRun("failed", 0, 0, String(err));
    return NextResponse.json(
      { error: String(err) },
      { status: 500 }
    );
  }
}
