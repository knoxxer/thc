"use client";

import { useState, useMemo } from "react";
import { createClient } from "@/lib/supabase/client";
import { sendNotification } from "@/lib/format";
import type { RoundReaction } from "@/lib/types";

const EMOJI_OPTIONS = ["\u26f3", "\ud83d\udd25", "\ud83c\udfcc\ufe0f", "\ud83d\udc80", "\ud83c\udfaf", "\ud83d\udc4f", "\ud83e\udd2e", "\ud83d\ude24"];

interface ReactionBarProps {
  roundId: string;
  reactions: RoundReaction[];
  currentPlayerId: string | null;
  roundOwnerId: string;
}

interface GroupedReaction {
  emoji: string;
  count: number;
  playerIds: string[];
}

function groupReactions(reactions: RoundReaction[]): GroupedReaction[] {
  const map = new Map<string, GroupedReaction>();
  for (const r of reactions) {
    const existing = map.get(r.emoji);
    if (existing) {
      existing.count++;
      existing.playerIds.push(r.player_id);
    } else {
      map.set(r.emoji, {
        emoji: r.emoji,
        count: 1,
        playerIds: [r.player_id],
      });
    }
  }
  return Array.from(map.values());
}

export default function ReactionBar({
  roundId,
  reactions: initialReactions,
  currentPlayerId,
  roundOwnerId,
}: ReactionBarProps) {
  const [reactions, setReactions] = useState(initialReactions);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [loading, setLoading] = useState(false);

  const grouped = useMemo(() => groupReactions(reactions), [reactions]);

  function findMyReaction(emoji: string) {
    return reactions.find(
      (r) => r.emoji === emoji && r.player_id === currentPlayerId
    );
  }

  async function toggleReaction(emoji: string) {
    if (!currentPlayerId || loading) return;

    const existing = findMyReaction(emoji);
    setLoading(true);
    const supabase = createClient();

    if (existing) {
      setReactions((prev) => prev.filter((r) => r.id !== existing.id));

      const { error } = await supabase
        .from("round_reactions")
        .delete()
        .eq("id", existing.id);

      if (error) {
        setReactions((prev) => [...prev, existing]);
      }
    } else {
      const tempId = crypto.randomUUID();
      const newReaction: RoundReaction = {
        id: tempId,
        round_id: roundId,
        player_id: currentPlayerId,
        emoji,
        comment: null,
        created_at: new Date().toISOString(),
      };
      setReactions((prev) => [...prev, newReaction]);

      const { data, error } = await supabase
        .from("round_reactions")
        .insert({
          round_id: roundId,
          player_id: currentPlayerId,
          emoji,
        })
        .select()
        .single();

      if (error) {
        setReactions((prev) => prev.filter((r) => r.id !== tempId));
      } else if (data) {
        setReactions((prev) =>
          prev.map((r) => (r.id === tempId ? { ...r, id: data.id } : r))
        );

        if (currentPlayerId !== roundOwnerId) {
          sendNotification({
            type: "reaction",
            targetPlayerId: roundOwnerId,
            title: `Someone reacted ${emoji} to your round`,
            link: "/feed",
          });
        }
      }
    }

    setPickerOpen(false);
    setLoading(false);
  }

  return (
    <div className="flex items-center gap-1.5 flex-wrap">
      {grouped.map((g) => {
        const isMine = currentPlayerId && g.playerIds.includes(currentPlayerId);
        return (
          <button
            key={g.emoji}
            onClick={() => toggleReaction(g.emoji)}
            disabled={!currentPlayerId}
            className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-sm transition-colors ${
              isMine
                ? "bg-gold/20 border border-gold/50 text-white"
                : "bg-surface-light/50 border border-surface-light text-white/70"
            } ${currentPlayerId ? "hover:bg-gold/30 cursor-pointer" : "cursor-default"}`}
          >
            <span>{g.emoji}</span>
            <span className="text-xs">{g.count}</span>
          </button>
        );
      })}

      {currentPlayerId && (
        <div className="relative">
          <button
            onClick={() => setPickerOpen(!pickerOpen)}
            className="inline-flex items-center justify-center w-7 h-7 rounded-full bg-surface-light/50 border border-surface-light text-white/50 hover:text-white hover:bg-surface-light transition-colors text-sm"
          >
            +
          </button>

          {pickerOpen && (
            <div className="absolute bottom-full left-0 mb-1 flex gap-1 bg-surface border border-surface-light rounded-lg p-1.5 shadow-lg shadow-black/30 z-10">
              {EMOJI_OPTIONS.map((emoji) => (
                <button
                  key={emoji}
                  onClick={() => toggleReaction(emoji)}
                  className="w-8 h-8 rounded hover:bg-surface-light transition-colors flex items-center justify-center text-lg"
                >
                  {emoji}
                </button>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
