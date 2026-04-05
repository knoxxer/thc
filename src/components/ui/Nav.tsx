"use client";

import Link from "next/link";
import Image from "next/image";
import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { DesignSwitch, useDesign } from "@/components/ui/DesignToggle";
import type { User } from "@supabase/supabase-js";

export default function Nav() {
  const pathname = usePathname();
  const { design } = useDesign();
  const v2 = design === "v2";
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
          <Link href="/" className={`transition-colors ${pathname === "/" ? "text-white font-medium" : "text-white/80 hover:text-white"}`}>
            Leaderboard
          </Link>
          <Link href="/rules" className={`transition-colors ${pathname === "/rules" ? "text-white font-medium" : "text-white/80 hover:text-white"}`}>
            Rules
          </Link>
          <Link href="/players" className={`transition-colors ${pathname.startsWith("/players") ? "text-white font-medium" : "text-white/80 hover:text-white"}`}>
            Players
          </Link>
          <DesignSwitch />
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

        {/* v2 mobile: show design switch inline since no hamburger */}
        {v2 && <div className="md:hidden"><DesignSwitch /></div>}

        {/* Mobile hamburger (hidden in v2 — bottom tabs replace it) */}
        <button
          onClick={() => setMenuOpen(!menuOpen)}
          className={`md:hidden text-white/70 hover:text-white p-2 min-h-[44px] min-w-[44px] flex items-center justify-center ${v2 ? "hidden" : ""}`}
          aria-label="Menu"
          aria-expanded={menuOpen}
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

      {/* Mobile menu (classic only — v2 uses bottom tabs) */}
      {menuOpen && !v2 && (
        <div className="md:hidden border-t border-surface-light bg-accent/95 px-4 py-3 space-y-3">
          <Link href="/" onClick={() => setMenuOpen(false)} className={`block text-sm ${pathname === "/" ? "text-white font-medium" : "text-white/80 hover:text-white"}`}>
            Leaderboard
          </Link>
          <Link href="/rules" onClick={() => setMenuOpen(false)} className={`block text-sm ${pathname === "/rules" ? "text-white font-medium" : "text-white/80 hover:text-white"}`}>
            Rules
          </Link>
          <Link href="/players" onClick={() => setMenuOpen(false)} className={`block text-sm ${pathname.startsWith("/players") ? "text-white font-medium" : "text-white/80 hover:text-white"}`}>
            Players
          </Link>
          <div className="pt-1">
            <DesignSwitch />
          </div>
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
