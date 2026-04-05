"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
} from "react";

type Design = "classic" | "v2";

const DesignContext = createContext<{
  design: Design;
  toggle: () => void;
}>({ design: "classic", toggle: () => {} });

export function useDesign() {
  return useContext(DesignContext);
}

export function DesignProvider({ children }: { children: React.ReactNode }) {
  const [design, setDesign] = useState<Design>("classic");
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    const stored = localStorage.getItem("thc-design") as Design | null;
    if (stored === "v2") setDesign("v2");
    setMounted(true);
  }, []);

  useEffect(() => {
    if (!mounted) return;
    const root = document.documentElement;
    if (design === "v2") {
      root.classList.add("theme-v2");
    } else {
      root.classList.remove("theme-v2");
    }
    localStorage.setItem("thc-design", design);
  }, [design, mounted]);

  const toggle = useCallback(() => {
    setDesign((d) => (d === "classic" ? "v2" : "classic"));
  }, []);

  return (
    <DesignContext.Provider value={{ design, toggle }}>
      {children}
    </DesignContext.Provider>
  );
}

export function DesignSwitch() {
  const { design, toggle } = useDesign();

  return (
    <button
      onClick={toggle}
      className="flex items-center gap-1.5 text-xs text-white/60 hover:text-white transition-colors px-2 py-1 rounded border border-surface-light/50 hover:border-surface-light"
      title={`Switch to ${design === "classic" ? "refreshed" : "classic"} design`}
    >
      <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01" />
      </svg>
      {design === "classic" ? "Try v2" : "Classic"}
    </button>
  );
}
