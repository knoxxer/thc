import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { getServiceClient } from "@/lib/supabase/service";

async function getPlayerByEmail(supabase: Awaited<ReturnType<typeof createClient>>) {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user?.email) return null;

  const service = getServiceClient();
  const { data: player } = await service
    .from("players")
    .select("id, display_name")
    .eq("email", user.email)
    .single();

  return player as { id: string; display_name: string } | null;
}

// POST /api/social — handle reactions and comments via service client (bypasses RLS)
export async function POST(request: Request) {
  const supabase = await createClient();
  const player = await getPlayerByEmail(supabase);

  if (!player) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json();
  const { action } = body as { action: string };
  const service = getServiceClient();

  if (action === "add_reaction") {
    const { roundId, emoji } = body as { roundId: string; emoji: string };
    const { data, error } = await service
      .from("round_reactions")
      .insert({ round_id: roundId, player_id: player.id, emoji })
      .select()
      .single();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }
    return NextResponse.json({ data });
  }

  if (action === "remove_reaction") {
    const { reactionId } = body as { reactionId: string };
    const { error } = await service
      .from("round_reactions")
      .delete()
      .eq("id", reactionId)
      .eq("player_id", player.id);

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }
    return NextResponse.json({ success: true });
  }

  if (action === "add_comment") {
    const { roundId, commentBody } = body as { roundId: string; commentBody: string };
    const { data, error } = await service
      .from("round_comments")
      .insert({ round_id: roundId, player_id: player.id, body: commentBody })
      .select()
      .single();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }
    return NextResponse.json({ data });
  }

  return NextResponse.json({ error: "Unknown action" }, { status: 400 });
}
