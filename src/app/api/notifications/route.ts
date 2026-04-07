import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import {
  createNotification,
  createNotificationsForAll,
} from "@/lib/notifications";
import type { Notification } from "@/lib/types";

type NotificationType = Notification["type"];

const VALID_TYPES: Set<NotificationType> = new Set<NotificationType>([
  "new_round", "reaction", "comment", "rsvp", "upcoming_round",
]);

async function getAuthenticatedPlayer(supabase: Awaited<ReturnType<typeof createClient>>, fields = "id"):
  Promise<{ player: { id: string; display_name?: string }; error: null } | { player: null; error: NextResponse }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return { player: null, error: NextResponse.json({ error: "Unauthorized" }, { status: 401 }) };
  }

  const { data: player } = await supabase
    .from("players")
    .select(fields)
    .eq("auth_user_id", user.id)
    .single();

  if (!player) {
    return { player: null, error: NextResponse.json({ error: "Player not found" }, { status: 404 }) };
  }

  return { player: player as unknown as { id: string; display_name?: string }, error: null };
}

export async function GET() {
  const supabase = await createClient();
  const { player, error: authError } = await getAuthenticatedPlayer(supabase);
  if (authError) return authError;

  const [notifResult, countResult] = await Promise.all([
    supabase
      .from("notifications")
      .select("*")
      .eq("player_id", player.id)
      .order("created_at", { ascending: false })
      .limit(30),
    supabase
      .from("notifications")
      .select("*", { count: "exact", head: true })
      .eq("player_id", player.id)
      .eq("is_read", false),
  ]);

  if (notifResult.error) {
    return NextResponse.json({ error: notifResult.error.message }, { status: 500 });
  }

  return NextResponse.json({
    notifications: notifResult.data,
    unreadCount: countResult.count ?? 0,
  });
}

export async function PATCH(request: Request) {
  const supabase = await createClient();
  const { player, error: authError } = await getAuthenticatedPlayer(supabase);
  if (authError) return authError;

  const body = await request.json();
  const { id, all } = body as { id?: string; all?: boolean };

  if (all) {
    const { error } = await supabase
      .from("notifications")
      .update({ is_read: true })
      .eq("player_id", player.id)
      .eq("is_read", false);

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }
  } else if (id) {
    const { error } = await supabase
      .from("notifications")
      .update({ is_read: true })
      .eq("id", id)
      .eq("player_id", player.id);

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }
  }

  return NextResponse.json({ success: true });
}

export async function POST(request: Request) {
  const supabase = await createClient();
  const { player, error: authError } = await getAuthenticatedPlayer(supabase, "id, display_name");
  if (authError) return authError;

  const body = await request.json();
  const { type, targetPlayerId, title, notifBody, link, metadata, notifyAll } =
    body as {
      type: string;
      targetPlayerId?: string;
      title: string;
      notifBody?: string;
      link?: string;
      metadata?: Record<string, unknown>;
      notifyAll?: boolean;
    };

  if (!VALID_TYPES.has(type as NotificationType)) {
    return NextResponse.json({ error: "Invalid notification type" }, { status: 400 });
  }

  const validType = type as NotificationType;

  if (notifyAll) {
    await createNotificationsForAll(player.id, {
      type: validType,
      title,
      body: notifBody,
      link,
      metadata,
    });
  } else if (targetPlayerId) {
    await createNotification({
      playerId: targetPlayerId,
      type: validType,
      title,
      body: notifBody,
      link,
      metadata,
    });
  }

  return NextResponse.json({ success: true });
}
