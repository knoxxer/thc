"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { calculatePoints } from "@/lib/points";
import { Player, Season } from "@/lib/types";
import Link from "next/link";

export default function NewRoundPage() {
  const router = useRouter();
  const [currentPlayer, setCurrentPlayer] = useState<Player | null>(null);
  const [season, setSeason] = useState<Season | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);

  const [playedAt, setPlayedAt] = useState(
    new Date().toISOString().split("T")[0]
  );
  const [courseName, setCourseName] = useState("");
  const [par, setPar] = useState(72);
  const [grossScore, setGrossScore] = useState<number | "">("");
  const [courseHandicap, setCourseHandicap] = useState<number | "">("");

  const netScore =
    grossScore !== "" && courseHandicap !== ""
      ? grossScore - courseHandicap
      : null;
  const netVsPar = netScore !== null ? netScore - par : null;
  const points = netVsPar !== null ? calculatePoints(netVsPar) : null;

  useEffect(() => {
    async function load() {
      const supabase = createClient();

      // Check auth
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        router.push("/login");
        return;
      }

      // Find the player matching the logged-in user's email
      const { data: player } = await supabase
        .from("players")
        .select("*")
        .eq("email", user.email)
        .single<Player>();

      if (!player) {
        // Logged in but not a registered player
        setLoading(false);
        return;
      }

      setCurrentPlayer(player);

      const { data: s } = await supabase
        .from("seasons")
        .select("*")
        .eq("is_active", true)
        .single<Season>();

      setSeason(s as Season | null);
      setLoading(false);
    }
    load();
  }, [router]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!season || !currentPlayer || grossScore === "" || courseHandicap === "")
      return;

    setSubmitting(true);
    const supabase = createClient();

    const { error } = await supabase.from("rounds").insert({
      player_id: currentPlayer.id,
      season_id: season.id,
      played_at: playedAt,
      course_name: courseName,
      par,
      gross_score: grossScore,
      course_handicap: courseHandicap,
      points,
      source: "manual",
    });

    setSubmitting(false);

    if (error) {
      alert(`Error: ${error.message}`);
    } else {
      setSuccess(true);
      setGrossScore("");
      setCourseHandicap("");
      setCourseName("");
    }
  }

  if (loading) {
    return (
      <div className="max-w-lg mx-auto px-4 py-8 text-center text-muted">
        Loading...
      </div>
    );
  }

  if (!currentPlayer) {
    return (
      <div className="max-w-lg mx-auto px-4 py-16 text-center">
        <p className="text-2xl mb-4">🚫</p>
        <h2 className="text-xl font-bold mb-2">Not a registered player</h2>
        <p className="text-muted">
          Your Google account isn&apos;t linked to a Homie Cup player. Talk to
          Brian K.
        </p>
      </div>
    );
  }

  if (success) {
    return (
      <div className="max-w-lg mx-auto px-4 py-16 text-center">
        <p className="text-4xl mb-4">🎉</p>
        <h2 className="text-2xl font-bold mb-2">Score Posted!</h2>
        <p className="text-muted mb-2">
          {points} point{points !== 1 ? "s" : ""} earned
        </p>
        <div className="flex gap-4 justify-center mt-6">
          <button
            onClick={() => setSuccess(false)}
            className="bg-accent hover:bg-accent-light text-white px-4 py-2 rounded-md transition-colors"
          >
            Post Another
          </button>
          <Link
            href="/"
            className="bg-surface border border-surface-light hover:bg-surface-light text-foreground px-4 py-2 rounded-md transition-colors"
          >
            View Leaderboard
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-lg mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-2 text-gold">Post a Score</h1>
      <p className="text-muted mb-8">
        Posting as <span className="text-foreground font-medium">{currentPlayer.display_name}</span>
      </p>

      <form onSubmit={handleSubmit} className="space-y-5">
        {/* Date */}
        <div>
          <label htmlFor="played-at" className="block text-sm font-medium mb-1">Date Played</label>
          <input
            id="played-at"
            type="date"
            value={playedAt}
            onChange={(e) => setPlayedAt(e.target.value)}
            required
            className="w-full bg-surface border border-surface-light rounded-md px-3 py-2 text-foreground focus:outline-none focus:border-accent"
          />
        </div>

        {/* Course */}
        <div>
          <label htmlFor="course-name" className="block text-sm font-medium mb-1">Course Name</label>
          <input
            id="course-name"
            type="text"
            value={courseName}
            onChange={(e) => setCourseName(e.target.value)}
            required
            placeholder="e.g. Torrey Pines South"
            className="w-full bg-surface border border-surface-light rounded-md px-3 py-2 text-foreground placeholder:text-muted focus:outline-none focus:border-accent"
          />
        </div>

        {/* Par */}
        <div>
          <label htmlFor="course-par" className="block text-sm font-medium mb-1">Course Par</label>
          <input
            id="course-par"
            type="number"
            value={par}
            onChange={(e) => setPar(Number(e.target.value))}
            required
            min={60}
            max={80}
            className="w-full bg-surface border border-surface-light rounded-md px-3 py-2 text-foreground focus:outline-none focus:border-accent"
          />
        </div>

        {/* Gross Score */}
        <div>
          <label htmlFor="gross-score" className="block text-sm font-medium mb-1">Gross Score</label>
          <input
            id="gross-score"
            type="number"
            value={grossScore}
            onChange={(e) =>
              setGrossScore(e.target.value ? Number(e.target.value) : "")
            }
            required
            min={50}
            max={200}
            placeholder="e.g. 92"
            className="w-full bg-surface border border-surface-light rounded-md px-3 py-2 text-foreground placeholder:text-muted focus:outline-none focus:border-accent"
          />
        </div>

        {/* Course Handicap */}
        <div>
          <label htmlFor="course-handicap" className="block text-sm font-medium mb-1">
            Course Handicap
          </label>
          <p className="text-xs text-muted mb-1" id="handicap-help">
            Your course handicap for the tees you played (check your GHIN app)
          </p>
          <input
            id="course-handicap"
            type="number"
            value={courseHandicap}
            onChange={(e) =>
              setCourseHandicap(e.target.value ? Number(e.target.value) : "")
            }
            required
            min={-5}
            max={54}
            placeholder="e.g. 18"
            aria-describedby="handicap-help"
            className="w-full bg-surface border border-surface-light rounded-md px-3 py-2 text-foreground placeholder:text-muted focus:outline-none focus:border-accent"
          />
        </div>

        {/* Live calculation preview */}
        {netScore !== null && (
          <div className="bg-surface-light rounded-lg p-4 border border-surface-light">
            <div className="flex justify-between items-center">
              <div>
                <p className="text-sm text-muted">Net Score</p>
                <p className="text-lg font-bold">
                  {netScore}{" "}
                  <span className="text-sm text-muted font-normal">
                    ({netVsPar !== null && netVsPar > 0 ? "+" : ""}
                    {netVsPar === 0 ? "E" : netVsPar})
                  </span>
                </p>
              </div>
              <div className="text-right">
                <p className="text-sm text-muted">Points</p>
                <p className="text-2xl font-bold text-gold">{points}</p>
              </div>
            </div>
          </div>
        )}

        <button
          type="submit"
          disabled={submitting || grossScore === "" || courseHandicap === ""}
          className="w-full disabled:opacity-50 disabled:cursor-not-allowed py-3 rounded-md transition-colors font-medium bg-gold hover:bg-gold-light text-background"
        >
          {submitting ? "Posting..." : "Post Score"}
        </button>
      </form>
    </div>
  );
}
