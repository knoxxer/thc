"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { sendNotification } from "@/lib/format";

interface PostUpcomingFormProps {
  currentPlayerId: string | null;
}

export default function PostUpcomingForm({
  currentPlayerId,
}: PostUpcomingFormProps) {
  const [open, setOpen] = useState(false);
  const [courseName, setCourseName] = useState("");
  const [teeTime, setTeeTime] = useState("");
  const [notes, setNotes] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);

  if (!currentPlayerId) return null;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!courseName.trim() || !teeTime || submitting) return;

    setSubmitting(true);
    const supabase = createClient();

    const { error } = await supabase.from("upcoming_rounds").insert({
      player_id: currentPlayerId,
      course_name: courseName.trim(),
      tee_time: new Date(teeTime).toISOString(),
      notes: notes.trim() || null,
    });

    if (!error) {
      // Notify all other players
      sendNotification({
        type: "upcoming_round",
        notifyAll: true,
        title: `Upcoming round at ${courseName.trim()}`,
        notifBody: new Date(teeTime).toLocaleDateString("en-US", { weekday: "long", month: "short", day: "numeric" }),
        link: "/feed",
      });

      setCourseName("");
      setTeeTime("");
      setNotes("");
      setSuccess(true);
      setTimeout(() => {
        setSuccess(false);
        setOpen(false);
      }, 2000);
    }

    setSubmitting(false);
  }

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className="w-full bg-surface rounded-xl border border-dashed border-surface-light p-4 text-sm text-muted hover:text-white hover:border-accent-light/50 transition-colors text-center"
      >
        + Post an upcoming round
      </button>
    );
  }

  return (
    <div className="bg-surface rounded-xl border border-surface-light p-4 sm:p-5">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-semibold text-white">
          Post Upcoming Round
        </h3>
        <button
          onClick={() => setOpen(false)}
          className="text-muted hover:text-white text-sm transition-colors"
        >
          Cancel
        </button>
      </div>

      {success ? (
        <p className="text-green-400 text-sm py-4 text-center">
          Posted! Your homies will be notified.
        </p>
      ) : (
        <form onSubmit={handleSubmit} className="space-y-3">
          <div>
            <label className="block text-xs text-muted mb-1">Course</label>
            <input
              type="text"
              value={courseName}
              onChange={(e) => setCourseName(e.target.value)}
              placeholder="e.g. Torrey Pines South"
              required
              className="w-full bg-surface-light/30 border border-surface-light rounded-lg px-3 py-2 text-sm text-white placeholder:text-muted/60 focus:outline-none focus:border-gold/50 transition-colors"
            />
          </div>

          <div>
            <label className="block text-xs text-muted mb-1">
              Tee Time
            </label>
            <input
              type="datetime-local"
              value={teeTime}
              onChange={(e) => setTeeTime(e.target.value)}
              required
              className="w-full bg-surface-light/30 border border-surface-light rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-gold/50 transition-colors"
            />
          </div>

          <div>
            <label className="block text-xs text-muted mb-1">
              Notes (optional)
            </label>
            <input
              type="text"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="e.g. Walking, room for 2 more"
              maxLength={200}
              className="w-full bg-surface-light/30 border border-surface-light rounded-lg px-3 py-2 text-sm text-white placeholder:text-muted/60 focus:outline-none focus:border-gold/50 transition-colors"
            />
          </div>

          <button
            type="submit"
            disabled={submitting || !courseName.trim() || !teeTime}
            className="w-full bg-gold hover:bg-gold-light text-accent px-4 py-2 rounded-lg text-sm font-semibold transition-colors disabled:opacity-50"
          >
            {submitting ? "Posting..." : "Post"}
          </button>
        </form>
      )}
    </div>
  );
}
