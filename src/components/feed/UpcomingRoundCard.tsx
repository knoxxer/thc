"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { UpcomingRound, UpcomingRoundRsvp } from "@/lib/types";

interface RsvpWithPlayer extends UpcomingRoundRsvp {
  player_name: string;
}

interface UpcomingRoundCardProps {
  round: UpcomingRound & { organizer_name: string };
  rsvps: RsvpWithPlayer[];
  currentPlayerId: string | null;
}

function formatTeeTime(dateStr: string): string {
  const d = new Date(dateStr);
  const day = d.toLocaleDateString("en-US", {
    weekday: "long",
    month: "short",
    day: "numeric",
  });
  const time = d.toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
  });
  return `${day} \u00b7 ${time}`;
}

const STATUS_OPTIONS: { value: UpcomingRoundRsvp["status"]; label: string }[] =
  [
    { value: "in", label: "I'm In" },
    { value: "maybe", label: "Maybe" },
    { value: "out", label: "Can't" },
  ];

export default function UpcomingRoundCard({
  round,
  rsvps: initialRsvps,
  currentPlayerId,
}: UpcomingRoundCardProps) {
  const [rsvps, setRsvps] = useState(initialRsvps);
  const [loading, setLoading] = useState(false);

  const myRsvp = rsvps.find((r) => r.player_id === currentPlayerId);
  const goingPlayers = rsvps.filter((r) => r.status === "in");
  const maybePlayers = rsvps.filter((r) => r.status === "maybe");

  async function handleRsvp(status: UpcomingRoundRsvp["status"]) {
    if (!currentPlayerId || loading) return;
    setLoading(true);

    const supabase = createClient();

    if (myRsvp && myRsvp.status === status) {
      // Remove RSVP
      setRsvps((prev) => prev.filter((r) => r.id !== myRsvp.id));

      const { error } = await supabase
        .from("upcoming_round_rsvps")
        .delete()
        .eq("id", myRsvp.id);

      if (error) {
        setRsvps((prev) => [...prev, myRsvp]);
      }
    } else {
      // Upsert RSVP
      const { data, error } = await supabase
        .from("upcoming_round_rsvps")
        .upsert(
          {
            upcoming_round_id: round.id,
            player_id: currentPlayerId,
            status,
          },
          { onConflict: "upcoming_round_id,player_id" }
        )
        .select()
        .single();

      if (!error && data) {
        setRsvps((prev) => {
          const filtered = prev.filter(
            (r) => r.player_id !== currentPlayerId
          );
          return [
            ...filtered,
            { ...data, player_name: "You" } as RsvpWithPlayer,
          ];
        });

        // Notify organizer (if not self)
        if (currentPlayerId !== round.player_id) {
          fetch("/api/notifications", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              type: "rsvp",
              targetPlayerId: round.player_id,
              title: `Someone RSVP'd "${status}" to your round at ${round.course_name}`,
              link: "/feed",
            }),
          }).catch(() => {});
        }
      }
    }

    setLoading(false);
  }

  return (
    <div className="bg-surface rounded-xl border border-accent-light/30 p-4 sm:p-5">
      <div className="flex items-center gap-2 mb-2">
        <span className="text-xs font-semibold uppercase tracking-wider text-accent-light">
          Upcoming
        </span>
      </div>

      <h3 className="text-lg font-semibold text-white mb-1">
        {round.course_name}
      </h3>
      <p className="text-sm text-muted mb-1">{formatTeeTime(round.tee_time)}</p>
      <p className="text-xs text-muted mb-2">
        Posted by {round.organizer_name}
      </p>

      {round.notes && (
        <p className="text-sm text-white/70 mb-3 italic">
          &ldquo;{round.notes}&rdquo;
        </p>
      )}

      {/* RSVP buttons */}
      {currentPlayerId && (
        <div className="flex gap-2 mb-3">
          {STATUS_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              onClick={() => handleRsvp(opt.value)}
              disabled={loading}
              className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
                myRsvp?.status === opt.value
                  ? opt.value === "in"
                    ? "bg-green-600/30 border border-green-500/50 text-green-300"
                    : opt.value === "maybe"
                      ? "bg-yellow-600/30 border border-yellow-500/50 text-yellow-300"
                      : "bg-red-600/30 border border-red-500/50 text-red-300"
                  : "bg-surface-light/50 border border-surface-light text-white/60 hover:text-white hover:bg-surface-light"
              }`}
            >
              {opt.label}
            </button>
          ))}
        </div>
      )}

      {/* Who's going */}
      {goingPlayers.length > 0 && (
        <p className="text-xs text-muted">
          <span className="text-green-400">{goingPlayers.length} going</span>
          {": "}
          {goingPlayers.map((r) => r.player_name).join(", ")}
        </p>
      )}
      {maybePlayers.length > 0 && (
        <p className="text-xs text-muted mt-0.5">
          <span className="text-yellow-400">{maybePlayers.length} maybe</span>
          {": "}
          {maybePlayers.map((r) => r.player_name).join(", ")}
        </p>
      )}
    </div>
  );
}
