import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import {
  createNotification,
  createNotificationsForAll,
} from "@/lib/notifications";

// GET /api/notifications — fetch current user's notifications
export async function GET() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  // Get the player for this auth user
  const { data: player } = await supabase
    .from("players")
    .select("id")
    .eq("auth_user_id", user.id)
    .single();

  if (!player) {
    return NextResponse.json({ error: "Player not found" }, { status: 404 });
  }

  const { data: notifications, error } = await supabase
    .from("notifications")
    .select("*")
    .eq("player_id", player.id)
    .order("created_at", { ascending: false })
    .limit(30);

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  // Also get unread count
  const { count } = await supabase
    .from("notifications")
    .select("*", { count: "exact", head: true })
    .eq("player_id", player.id)
    .eq("is_read", false);

  return NextResponse.json({ notifications, unreadCount: count ?? 0 });
}

// PATCH /api/notifications — mark notifications as read
export async function PATCH(request: Request) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { data: player } = await supabase
    .from("players")
    .select("id")
    .eq("auth_user_id", user.id)
    .single();

  if (!player) {
    return NextResponse.json({ error: "Player not found" }, { status: 404 });
  }

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

// POST /api/notifications — create notifications (called by other components)
export async function POST(request: Request) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { data: player } = await supabase
    .from("players")
    .select("id, display_name")
    .eq("auth_user_id", user.id)
    .single();

  if (!player) {
    return NextResponse.json({ error: "Player not found" }, { status: 404 });
  }

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

  if (notifyAll) {
    await createNotificationsForAll(player.id, {
      type: type as "new_round" | "reaction" | "comment" | "rsvp" | "upcoming_round",
      title,
      body: notifBody,
      link,
      metadata,
    });
  } else if (targetPlayerId) {
    await createNotification({
      playerId: targetPlayerId,
      type: type as "new_round" | "reaction" | "comment" | "rsvp" | "upcoming_round",
      title,
      body: notifBody,
      link,
      metadata,
    });
  }

  return NextResponse.json({ success: true });
}
