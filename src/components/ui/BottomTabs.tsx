"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";

function TabIcon({ name, active }: { name: string; active: boolean }) {
  const cls = `w-5 h-5 ${active ? "text-gold" : "text-white/50"}`;

  if (name === "leaderboard") {
    return (
      <svg className={cls} fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
      </svg>
    );
  }
  if (name === "rules") {
    return (
      <svg className={cls} fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
      </svg>
    );
  }
  if (name === "players") {
    return (
      <svg className={cls} fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
      </svg>
    );
  }
  // post score (plus icon)
  return (
    <svg className="w-5 h-5 text-background" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M12 4v16m8-8H4" />
    </svg>
  );
}

export default function BottomTabs() {
  const pathname = usePathname();
  const [isAuthed, setIsAuthed] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(({ data }) => {
      setIsAuthed(!!data.user);
    });
  }, []);

  const tabs = [
    { name: "leaderboard", label: "Standings", href: "/" },
    { name: "rules", label: "Rules", href: "/rules" },
    { name: "players", label: "Players", href: "/players" },
  ];

  const isActive = (href: string) => {
    if (href === "/") return pathname === "/";
    return pathname.startsWith(href);
  };

  return (
    <nav className="md:hidden fixed bottom-0 left-0 right-0 z-50 bg-accent/95 backdrop-blur-sm border-t border-surface-light safe-area-bottom">
      <div className="flex items-stretch justify-around">
        {tabs.map((tab) => (
          <Link
            key={tab.name}
            href={tab.href}
            className={`flex flex-col items-center justify-center gap-0.5 py-2 px-3 min-h-[56px] flex-1 transition-colors ${
              isActive(tab.href) ? "text-gold" : "text-white/50"
            }`}
          >
            <TabIcon name={tab.name} active={isActive(tab.href)} />
            <span className="text-[10px] font-medium">{tab.label}</span>
          </Link>
        ))}
        <Link
          href={isAuthed ? "/rounds/new" : "/login"}
          className="flex flex-col items-center justify-center gap-0.5 py-2 px-3 min-h-[56px] flex-1"
        >
          <span className="w-8 h-8 rounded-full bg-gold flex items-center justify-center">
            <TabIcon name="post" active={false} />
          </span>
          <span className="text-[10px] font-medium text-gold">Post</span>
        </Link>
      </div>
    </nav>
  );
}
