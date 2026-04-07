import { createClient } from "@supabase/supabase-js";

function getServiceClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}

interface CreateNotificationParams {
  playerId: string;
  type: "new_round" | "reaction" | "comment" | "rsvp" | "upcoming_round";
  title: string;
  body?: string;
  link?: string;
  metadata?: Record<string, unknown>;
}

export async function createNotification(params: CreateNotificationParams) {
  const supabase = getServiceClient();
  const { error } = await supabase.from("notifications").insert({
    player_id: params.playerId,
    type: params.type,
    title: params.title,
    body: params.body || null,
    link: params.link || null,
    metadata: params.metadata || null,
  });
  if (error) console.error("Failed to create notification:", error);
}

export async function createNotificationsForAll(
  excludePlayerId: string,
  params: Omit<CreateNotificationParams, "playerId">
) {
  const supabase = getServiceClient();
  const { data: players } = await supabase
    .from("players")
    .select("id")
    .eq("is_active", true)
    .neq("id", excludePlayerId);

  if (!players?.length) return;

  const rows = players.map((p) => ({
    player_id: p.id,
    type: params.type,
    title: params.title,
    body: params.body || null,
    link: params.link || null,
    metadata: params.metadata || null,
  }));

  const { error } = await supabase.from("notifications").insert(rows);
  if (error) console.error("Failed to create notifications:", error);
}
