-- Migration: create_round_comments.sql
-- Creates round_comments table for text comments on posted rounds.
-- Separate from round_reactions (emojis) to allow multiple comments per player.

CREATE TABLE IF NOT EXISTS round_comments (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id   uuid        NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
  player_id  uuid        NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  body       text        NOT NULL CHECK (char_length(body) BETWEEN 1 AND 500),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_round_comments_round
  ON round_comments (round_id, created_at);

-- RLS: all authenticated users can read; players insert/delete their own comments.
ALTER TABLE round_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read round_comments" ON round_comments;
CREATE POLICY "Authenticated users can read round_comments"
  ON round_comments FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Players can insert own comments" ON round_comments;
CREATE POLICY "Players can insert own comments"
  ON round_comments FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM players p
      WHERE p.id = player_id
        AND p.auth_user_id = auth.uid()::text
    )
  );

DROP POLICY IF EXISTS "Players can delete own comments" ON round_comments;
CREATE POLICY "Players can delete own comments"
  ON round_comments FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM players p
      WHERE p.id = player_id
        AND p.auth_user_id = auth.uid()::text
    )
  );
