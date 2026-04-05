import { createClient } from "@/lib/supabase/server";
import Link from "next/link";
import { Player } from "@/lib/types";

export const revalidate = 60;

export default async function PlayersPage() {
  const supabase = await createClient();

  const { data } = await supabase
    .from("players")
    .select("*")
    .eq("is_active", true)
    .order("name");

  const players = (data as Player[]) || [];

  return (
    <div className="max-w-5xl mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-8 text-white">The Homies</h1>
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
        {players.map((player) => (
          <Link
            key={player.id}
            href={`/players/${player.slug}`}
            className="bg-surface rounded-xl border border-surface-light p-4 sm:p-5 hover:border-accent-light transition-all active:scale-[0.98] md:hover:-translate-y-0.5 group"
          >
            <div className="w-10 h-10 bg-accent rounded-full flex items-center justify-center text-white font-bold mb-3">
              {player.display_name.charAt(0)}
            </div>
            <h2 className="font-semibold group-hover:text-gold transition-colors">
              {player.display_name}
            </h2>
            {player.handicap_index != null && (
              <p className="text-sm text-muted mt-1">
                HCP: {player.handicap_index}
              </p>
            )}
          </Link>
        ))}
      </div>
    </div>
  );
}
