import http from "node:http";

const MOCK_SEASON = {
  id: "season-1",
  name: "2024 Season",
  starts_at: "2024-01-01T00:00:00Z",
  ends_at: "2024-12-31T23:59:59Z",
  is_active: true,
  min_rounds: 5,
  top_n_rounds: 10,
  created_at: "2024-01-01T00:00:00Z",
};

const MOCK_PLAYERS = [
  { id: "p1", name: "Jake", display_name: "Jake", slug: "jake", email: "jake@test.com", ghin_number: null, handicap_index: 10.2, handicap_updated_at: null, avatar_url: null, is_active: true, role: "admin", auth_user_id: null, created_at: "2024-01-01T00:00:00Z" },
  { id: "p2", name: "Mike", display_name: "Mike", slug: "mike", email: "mike@test.com", ghin_number: null, handicap_index: 15.0, handicap_updated_at: null, avatar_url: null, is_active: true, role: "contributor", auth_user_id: null, created_at: "2024-01-01T00:00:00Z" },
];

const MOCK_ROUNDS = [
  {
    id: "r1", player_id: "p1", season_id: "season-1", played_at: "2024-06-14", course_name: "Torrey Pines South", tee_name: null, course_rating: 74.6, slope_rating: 136, par: 72, gross_score: 82, course_handicap: 10, net_score: 72, net_vs_par: 0, points: 10, ghin_score_id: null, source: "manual", entered_by: null, created_at: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
    player: { id: "p1", display_name: "Jake", slug: "jake", avatar_url: null },
  },
  {
    id: "r2", player_id: "p2", season_id: "season-1", played_at: "2024-06-13", course_name: "Riviera Country Club", tee_name: null, course_rating: 75.0, slope_rating: 140, par: 71, gross_score: 91, course_handicap: 15, net_score: 76, net_vs_par: 5, points: 5, ghin_score_id: null, source: "manual", entered_by: null, created_at: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
    player: { id: "p2", display_name: "Mike", slug: "mike", avatar_url: null },
  },
];

const MOCK_STANDINGS = [
  { player_id: "p1", season_id: "season-1", player_name: "Jake", player_slug: "jake", handicap_index: 10.2, avatar_url: null, total_rounds: 6, is_eligible: true, best_n_points: 85, best_round_points: 12, best_net_vs_par: -2 },
  { player_id: "p2", season_id: "season-1", player_name: "Mike", player_slug: "mike", handicap_index: 15.0, avatar_url: null, total_rounds: 4, is_eligible: false, best_n_points: 35, best_round_points: 10, best_net_vs_par: 0 },
];

function parseSupabaseQuery(url: URL): { table: string; params: URLSearchParams } {
  // PostgREST URLs: /rest/v1/table_name?filters
  const path = url.pathname;
  const match = path.match(/\/rest\/v1\/(\w+)/);
  const table = match?.[1] ?? "";
  return { table, params: url.searchParams };
}

function handleRestRequest(url: URL): unknown {
  const { table, params } = parseSupabaseQuery(url);
  const select = params.get("select") ?? "*";

  switch (table) {
    case "seasons": {
      const single = params.has("is_active");
      return single ? MOCK_SEASON : [MOCK_SEASON];
    }
    case "players": {
      return MOCK_PLAYERS;
    }
    case "rounds": {
      return MOCK_ROUNDS;
    }
    case "season_standings": {
      return MOCK_STANDINGS;
    }
    case "round_reactions":
      return [];
    case "round_comments":
      return [];
    case "upcoming_rounds":
      return [];
    case "upcoming_round_rsvps":
      return [];
    case "notifications":
      return [];
    default:
      return [];
  }
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url ?? "/", `http://localhost:54321`);
  const path = url.pathname;

  // CORS
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Headers", "*");
  res.setHeader("Access-Control-Allow-Methods", "*");

  if (req.method === "OPTIONS") {
    res.writeHead(200);
    res.end();
    return;
  }

  // Auth endpoints — return no user (unauthenticated)
  if (path.startsWith("/auth/v1")) {
    res.writeHead(200, { "Content-Type": "application/json" });
    if (path.includes("/user")) {
      res.end(JSON.stringify({ data: { user: null }, error: null }));
    } else if (path.includes("/token")) {
      res.end(JSON.stringify({ access_token: "", refresh_token: "", user: null }));
    } else {
      res.end(JSON.stringify({}));
    }
    return;
  }

  // PostgREST endpoints
  if (path.startsWith("/rest/v1/")) {
    const data = handleRestRequest(url);
    const accept = req.headers["accept"] ?? "";
    const isSingle = accept.includes("vnd.pgrst.object");

    res.writeHead(200, {
      "Content-Type": "application/json",
      "Content-Range": "0-0/*",
    });

    if (isSingle && Array.isArray(data)) {
      res.end(JSON.stringify(data[0] ?? null));
    } else {
      res.end(JSON.stringify(Array.isArray(data) ? data : [data]));
    }
    return;
  }

  // Fallback
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify({}));
});

server.listen(54321, () => {
  console.log("Mock Supabase server running on http://localhost:54321");
});
