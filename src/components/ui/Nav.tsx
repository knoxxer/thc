"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { User } from "@supabase/supabase-js";

export default function Nav() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(({ data }) => {
      setUser(data.user);
      setLoading(false);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
    });

    return () => subscription.unsubscribe();
  }, []);

  async function handleSignOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    window.location.href = "/";
  }

  return (
    <nav className="border-b border-surface-light bg-surface/80 backdrop-blur-sm">
      <div className="max-w-5xl mx-auto px-4 py-3 flex items-center justify-between">
        <Link href="/" className="flex items-center gap-2 group">
          <span className="text-2xl">🏆</span>
          <span className="font-bold text-lg text-gold group-hover:text-gold-light transition-colors">
            The Homie Cup
          </span>
        </Link>
        <div className="flex items-center gap-6 text-sm">
          <Link
            href="/"
            className="text-muted hover:text-foreground transition-colors"
          >
            Leaderboard
          </Link>
          <Link
            href="/players"
            className="text-muted hover:text-foreground transition-colors"
          >
            Players
          </Link>
          {!loading && (
            <>
              {user ? (
                <>
                  <Link
                    href="/rounds/new"
                    className="bg-accent hover:bg-accent-light text-white px-3 py-1.5 rounded-md transition-colors text-sm font-medium"
                  >
                    Post Score
                  </Link>
                  <button
                    onClick={handleSignOut}
                    className="text-muted hover:text-foreground transition-colors"
                  >
                    Sign Out
                  </button>
                </>
              ) : (
                <Link
                  href="/login"
                  className="bg-accent hover:bg-accent-light text-white px-3 py-1.5 rounded-md transition-colors text-sm font-medium"
                >
                  Sign In
                </Link>
              )}
            </>
          )}
        </div>
      </div>
    </nav>
  );
}
