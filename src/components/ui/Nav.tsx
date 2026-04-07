"use client";

import Link from "next/link";
import Image from "next/image";
import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { User } from "@supabase/supabase-js";
import NotificationBell from "./NotificationBell";

export default function Nav() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [menuOpen, setMenuOpen] = useState(false);

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
        <Link href="/" className="flex items-center gap-2 sm:gap-3 group shrink-0">
          <Image
            src="/logo.png"
            alt="The Homie Cup"
            width={40}
            height={40}
            className="rounded-full sm:w-[44px] sm:h-[44px]"
          />
          <span className="font-[var(--font-heading)] font-bold text-base sm:text-lg text-white uppercase tracking-wider group-hover:text-gold transition-colors hidden sm:inline">
            The Homie Cup
          </span>
          <span className="font-[var(--font-heading)] font-bold text-base text-white uppercase tracking-wider group-hover:text-gold transition-colors sm:hidden">
            THC
          </span>
        </Link>

        {/* Desktop nav */}
        <div className="hidden md:flex items-center gap-6 text-sm">
          <Link href="/" className="text-white/70 hover:text-white transition-colors">
            Leaderboard
          </Link>
          <Link href="/feed" className="text-white/70 hover:text-white transition-colors">
            Feed
          </Link>
          <Link href="/rules" className="text-white/70 hover:text-white transition-colors">
            Rules
          </Link>
          <Link href="/players" className="text-white/70 hover:text-white transition-colors">
            Players
          </Link>
          {!loading && (
            <>
              {user ? (
                <>
                  <NotificationBell />
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

        {/* Mobile hamburger */}
        <button
          onClick={() => setMenuOpen(!menuOpen)}
          className="md:hidden text-white/70 hover:text-white p-1"
          aria-label="Menu"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            {menuOpen ? (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            ) : (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            )}
          </svg>
        </button>
      </div>

      {/* Mobile menu */}
      {menuOpen && (
        <div className="md:hidden border-t border-surface-light bg-accent/95 px-4 py-3 space-y-3">
          <Link href="/" onClick={() => setMenuOpen(false)} className="block text-white/80 hover:text-white text-sm">
            Leaderboard
          </Link>
          <Link href="/feed" onClick={() => setMenuOpen(false)} className="block text-white/80 hover:text-white text-sm">
            Feed
          </Link>
          <Link href="/rules" onClick={() => setMenuOpen(false)} className="block text-white/80 hover:text-white text-sm">
            Rules
          </Link>
          <Link href="/players" onClick={() => setMenuOpen(false)} className="block text-white/80 hover:text-white text-sm">
            Players
          </Link>
          {!loading && (
            <>
              {user ? (
                <>
                  <Link
                    href="/rounds/new"
                    onClick={() => setMenuOpen(false)}
                    className="block bg-gold hover:bg-gold-light text-accent px-3 py-2 rounded-md text-sm font-semibold text-center"
                  >
                    Post Score
                  </Link>
                  <button
                    onClick={() => { handleSignOut(); setMenuOpen(false); }}
                    className="block text-white/60 hover:text-white text-sm"
                  >
                    Sign Out
                  </button>
                </>
              ) : (
                <Link
                  href="/login"
                  onClick={() => setMenuOpen(false)}
                  className="block bg-gold hover:bg-gold-light text-accent px-3 py-2 rounded-md text-sm font-semibold text-center"
                >
                  Sign In
                </Link>
              )}
            </>
          )}
        </div>
      )}
    </nav>
  );
}
