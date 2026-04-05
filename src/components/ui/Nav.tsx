"use client";

import Link from "next/link";
import Image from "next/image";
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
    <nav className="border-b border-surface-light bg-accent/90 backdrop-blur-sm">
      <div className="max-w-5xl mx-auto px-4 py-2 flex items-center justify-between">
        <Link href="/" className="flex items-center gap-3 group">
          <Image
            src="/logo.png"
            alt="The Homie Cup"
            width={44}
            height={44}
            className="rounded-full"
          />
          <span className="font-[var(--font-heading)] font-bold text-lg text-white uppercase tracking-wider group-hover:text-gold transition-colors hidden sm:inline">
            The Homie Cup
          </span>
        </Link>
        <div className="flex items-center gap-6 text-sm">
          <Link
            href="/"
            className="text-white/70 hover:text-white transition-colors"
          >
            Leaderboard
          </Link>
          <Link
            href="/players"
            className="text-white/70 hover:text-white transition-colors"
          >
            Players
          </Link>
          {!loading && (
            <>
              {user ? (
                <>
                  <Link
                    href="/rounds/new"
                    className="bg-gold hover:bg-gold-light text-accent px-3 py-1.5 rounded-md transition-colors text-sm font-semibold"
                  >
                    Post Score
                  </Link>
                  <button
                    onClick={handleSignOut}
                    className="text-white/70 hover:text-white transition-colors"
                  >
                    Sign Out
                  </button>
                </>
              ) : (
                <Link
                  href="/login"
                  className="bg-gold hover:bg-gold-light text-accent px-3 py-1.5 rounded-md transition-colors text-sm font-semibold"
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
