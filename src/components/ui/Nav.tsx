"use client";

import Link from "next/link";
import Image from "next/image";
import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { User } from "@supabase/supabase-js";
import NotificationBell from "./NotificationBell";

export default function Nav() {
  const pathname = usePathname();
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
          <Link href="/feed" className={`transition-colors ${pathname === "/feed" ? "text-white font-medium" : "text-white/80 hover:text-white"}`}>
            Feed
          </Link>
          <Link href="/rules" className={`transition-colors ${pathname === "/rules" ? "text-white font-medium" : "text-white/80 hover:text-white"}`}>
            Rules
          </Link>
          <Link href="/players" className={`transition-colors ${pathname.startsWith("/players") ? "text-white font-medium" : "text-white/80 hover:text-white"}`}>
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
      </div>
    </nav>
  );
}
