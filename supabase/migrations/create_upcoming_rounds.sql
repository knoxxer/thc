-- Migration: create_upcoming_rounds.sql
-- Creates upcoming_rounds and upcoming_round_rsvps tables with RLS policies.
-- Allows players to post future tee times and friends to RSVP.

-- ============================================================
-- upcoming_rounds: Future tee times posted by players
-- ============================================================

CREATE TABLE IF NOT EXISTS upcoming_rounds (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id   uuid        NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  course_name text        NOT NULL,
  tee_time    timestamptz NOT NULL,
  notes       text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_upcoming_rounds_tee_time
  ON upcoming_rounds (tee_time);

-- RLS: all authenticated users can read; players manage their own posts.
ALTER TABLE upcoming_rounds ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read upcoming_rounds" ON upcoming_rounds;
CREATE POLICY "Authenticated users can read upcoming_rounds"
  ON upcoming_rounds FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Players can insert own upcoming_rounds" ON upcoming_rounds;
CREATE POLICY "Players can insert own upcoming_rounds"
  ON upcoming_rounds FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM players p
      WHERE p.id = player_id
        AND p.auth_user_id = auth.uid()::text
    )
  );

DROP POLICY IF EXISTS "Players can delete own upcoming_rounds" ON upcoming_rounds;
CREATE POLICY "Players can delete own upcoming_rounds"
  ON upcoming_rounds FOR DELETE
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
-- upcoming_round_rsvps: RSVPs to upcoming rounds
-- ============================================================

CREATE TABLE IF NOT EXISTS upcoming_round_rsvps (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  upcoming_round_id uuid        NOT NULL REFERENCES upcoming_rounds(id) ON DELETE CASCADE,
  player_id         uuid        NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  status            text        NOT NULL CHECK (status IN ('in', 'maybe', 'out')),
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (upcoming_round_id, player_id)
);

CREATE INDEX IF NOT EXISTS idx_upcoming_round_rsvps_round
  ON upcoming_round_rsvps (upcoming_round_id);

-- RLS: all authenticated users can read; players manage their own RSVPs.
ALTER TABLE upcoming_round_rsvps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read upcoming_round_rsvps" ON upcoming_round_rsvps;
CREATE POLICY "Authenticated users can read upcoming_round_rsvps"
  ON upcoming_round_rsvps FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Players can manage own rsvps" ON upcoming_round_rsvps;
CREATE POLICY "Players can manage own rsvps"
  ON upcoming_round_rsvps FOR ALL
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


-- ============================================================
-- Cleanup function: remove past upcoming_rounds older than 24 hours.
-- ============================================================

CREATE OR REPLACE FUNCTION cleanup_past_upcoming_rounds()
RETURNS void AS $$
BEGIN
  DELETE FROM upcoming_rounds
  WHERE tee_time < now() - interval '24 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
