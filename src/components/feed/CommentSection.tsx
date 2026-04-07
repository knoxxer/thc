"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { RoundComment } from "@/lib/types";

function timeAgo(dateStr: string): string {
  const seconds = Math.floor(
    (Date.now() - new Date(dateStr).getTime()) / 1000
  );
  if (seconds < 60) return "just now";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  return `${days}d`;
}

interface CommentWithPlayer extends RoundComment {
  player_name: string;
}

interface CommentSectionProps {
  roundId: string;
  comments: CommentWithPlayer[];
  currentPlayerId: string | null;
  roundOwnerId: string;
}

export default function CommentSection({
  roundId,
  comments: initialComments,
  currentPlayerId,
  roundOwnerId,
}: CommentSectionProps) {
  const [comments, setComments] = useState(initialComments);
  const [input, setInput] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const body = input.trim();
    if (!body || !currentPlayerId || submitting) return;

    setSubmitting(true);
    setInput("");

    const supabase = createClient();
    const { data, error } = await supabase
      .from("round_comments")
      .insert({
        round_id: roundId,
        player_id: currentPlayerId,
        body,
      })
      .select()
      .single();

    if (error) {
      setInput(body);
    } else if (data) {
      setComments((prev) => [
        ...prev,
        { ...data, player_name: "You" } as CommentWithPlayer,
      ]);

      // Notify round owner (if not self)
      if (currentPlayerId !== roundOwnerId) {
        fetch("/api/notifications", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            type: "comment",
            targetPlayerId: roundOwnerId,
            title: `Someone commented on your round`,
            notifBody: body.length > 80 ? body.slice(0, 80) + "..." : body,
            link: "/feed",
          }),
        }).catch(() => {});
      }
    }

    setSubmitting(false);
  }

  return (
    <div className="mt-2">
      {comments.length > 0 && (
        <div className="space-y-1.5 mb-2">
          {comments.map((c) => (
            <div key={c.id} className="text-sm">
              <span className="text-white/80 font-medium">
                {c.player_name}
              </span>
              <span className="text-white/60 mx-1">{c.body}</span>
              <span className="text-muted text-xs">
                {timeAgo(c.created_at)}
              </span>
            </div>
          ))}
        </div>
      )}

      {currentPlayerId && (
        <form onSubmit={handleSubmit} className="flex gap-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Add comment..."
            maxLength={500}
            className="flex-1 bg-surface-light/30 border border-surface-light rounded-lg px-3 py-1.5 text-sm text-white placeholder:text-muted/60 focus:outline-none focus:border-gold/50 transition-colors"
          />
          <button
            type="submit"
            disabled={!input.trim() || submitting}
            className="text-gold hover:text-gold-light text-sm font-medium transition-colors disabled:opacity-30"
          >
            Post
          </button>
        </form>
      )}
    </div>
  );
}
