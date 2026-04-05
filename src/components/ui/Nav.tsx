import Link from "next/link";

export default function Nav() {
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
          <Link
            href="/rounds/new"
            className="bg-accent hover:bg-accent-light text-white px-3 py-1.5 rounded-md transition-colors text-sm font-medium"
          >
            Post Score
          </Link>
        </div>
      </div>
    </nav>
  );
}
