-- Migration: create_social_tables.sql
-- Creates hole_scores, round_reactions, and live_rounds tables with RLS policies.
-- Enables Realtime on live_rounds and installs a stale-row cleanup function.
-- Covers: M8.1, M8.2, M8.3, M8.4, M8.5

-- ============================================================
-- hole_scores: Optional per-hole stats linked to rounds
-- ============================================================

CREATE TABLE IF NOT EXISTS hole_scores (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id              uuid        NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
  hole_number           int         NOT NULL CHECK (hole_number BETWEEN 1 AND 18),
  strokes               int         NOT NULL CHECK (strokes BETWEEN 1 AND 20),
  putts                 int         CHECK (putts BETWEEN 0 AND 10),
  fairway_hit           text        CHECK (fairway_hit IN ('hit', 'left', 'right', 'na')),
  green_in_regulation   boolean,
  created_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (round_id, hole_number)
);

CREATE INDEX IF NOT EXISTS idx_hole_scores_round
  ON hole_scores (round_id);

-- RLS: all authenticated users can read; only the round owner can insert.
ALTER TABLE hole_scores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read hole_scores" ON hole_scores;
CREATE POLICY "Authenticated users can read hole_scores"
  ON hole_scores FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert hole_scores" ON hole_scores;
CREATE POLICY "Authenticated users can insert hole_scores"
  ON hole_scores FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM rounds r
      JOIN players p ON r.player_id = p.id
      WHERE r.id = round_id
        AND p.auth_user_id = auth.uid()::text
    )
  );


-- ============================================================
-- round_reactions: Social reactions/comments on posted rounds
-- ============================================================

CREATE TABLE IF NOT EXISTS round_reactions (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id   uuid        NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
  player_id  uuid        NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  emoji      text        NOT NULL,
  comment    text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (round_id, player_id, emoji)
);

CREATE INDEX IF NOT EXISTS idx_round_reactions_round
  ON round_reactions (round_id);

-- RLS: all authenticated users can read; players can only write/delete their own.
ALTER TABLE round_reactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read round_reactions" ON round_reactions;
CREATE POLICY "Authenticated users can read round_reactions"
  ON round_reactions FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Players can insert own reactions" ON round_reactions;
CREATE POLICY "Players can insert own reactions"
  ON round_reactions FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM players p
      WHERE p.id = player_id
        AND p.auth_user_id = auth.uid()::text
    )
  );

DROP POLICY IF EXISTS "Players can delete own reactions" ON round_reactions;
CREATE POLICY "Players can delete own reactions"
  ON round_reactions FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM players p
      WHERE p.id = player_id
        AND p.auth_user_id = auth.uid()::text
    )
  );


-- ============================================================
-- live_rounds: Active round state for live feed (ephemeral)
-- One row per player while a round is in progress.
-- ============================================================

CREATE TABLE IF NOT EXISTS live_rounds (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id      uuid        NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  course_data_id uuid        REFERENCES course_data(id),
  course_name    text        NOT NULL,
  current_hole   int         NOT NULL DEFAULT 1,
  thru_hole      int         NOT NULL DEFAULT 0,
  current_score  int         NOT NULL DEFAULT 0,
  started_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (player_id)
);

-- Automatically stamp updated_at on any update.
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS live_rounds_updated_at ON live_rounds;
CREATE TRIGGER live_rounds_updated_at
  BEFORE UPDATE ON live_rounds
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- RLS: all authenticated users can read; players manage only their own row.
ALTER TABLE live_rounds ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read live_rounds" ON live_rounds;
CREATE POLICY "Authenticated users can read live_rounds"
  ON live_rounds FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Players can manage own live_rounds" ON live_rounds;
CREATE POLICY "Players can manage own live_rounds"
  ON live_rounds FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM players p
      WHERE p.id = player_id
        AND p.auth_user_id = auth.uid()::text
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM players p
      WHERE p.id = player_id
        AND p.auth_user_id = auth.uid()::text
    )
  );

-- Enable Realtime so clients can subscribe to live score updates.
-- This requires the supabase_realtime publication to already exist,
-- which is the case on all Supabase projects.
ALTER PUBLICATION supabase_realtime ADD TABLE live_rounds;


-- ============================================================
-- Cleanup function: remove stale live_rounds older than 12 hours.
-- Handles crashes, force-quits, and abandoned rounds.
-- Call via pg_cron (Pro plan) or a Supabase Edge Function (Free plan).
--
-- To schedule with pg_cron (uncomment on Pro plan):
--   SELECT cron.schedule(
--     'cleanup-live-rounds',
--     '0 */6 * * *',
--     'SELECT cleanup_stale_live_rounds()'
--   );
-- ============================================================

CREATE OR REPLACE FUNCTION cleanup_stale_live_rounds()
RETURNS void AS $$
BEGIN
  DELETE FROM live_rounds
  WHERE updated_at < now() - interval '12 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
