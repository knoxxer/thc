-- Migration: fix_rls_email_lookup.sql
-- Fix RLS policies to look up players by email (via auth.users)
-- instead of auth_user_id, which may not be populated.

-- ============================================================
-- round_reactions: fix insert and delete policies
-- ============================================================

DROP POLICY IF EXISTS "Players can insert own reactions" ON round_reactions;
CREATE POLICY "Players can insert own reactions"
  ON round_reactions FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM players p
      WHERE p.id = player_id
        AND p.email = (SELECT email FROM auth.users WHERE id = auth.uid())
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
        AND p.email = (SELECT email FROM auth.users WHERE id = auth.uid())
    )
  );

-- ============================================================
-- round_comments: fix insert and delete policies
-- ============================================================

DROP POLICY IF EXISTS "Players can insert own comments" ON round_comments;
CREATE POLICY "Players can insert own comments"
  ON round_comments FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM players p
      WHERE p.id = player_id
        AND p.email = (SELECT email FROM auth.users WHERE id = auth.uid())
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
        AND p.email = (SELECT email FROM auth.users WHERE id = auth.uid())
    )
  );

-- ============================================================
-- upcoming_rounds: fix insert and delete policies
-- ============================================================

DROP POLICY IF EXISTS "Players can insert own upcoming_rounds" ON upcoming_rounds;
CREATE POLICY "Players can insert own upcoming_rounds"
  ON upcoming_rounds FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM players p
      WHERE p.id = player_id
        AND p.email = (SELECT email FROM auth.users WHERE id = auth.uid())
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
        AND p.email = (SELECT email FROM auth.users WHERE id = auth.uid())
    )
  );

-- ============================================================
-- upcoming_round_rsvps: fix manage policy
-- ============================================================

DROP POLICY IF EXISTS "Players can manage own rsvps" ON upcoming_round_rsvps;
CREATE POLICY "Players can manage own rsvps"
  ON upcoming_round_rsvps FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM players p
      WHERE p.id = player_id
        AND p.email = (SELECT email FROM auth.users WHERE id = auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM players p
      WHERE p.id = player_id
        AND p.email = (SELECT email FROM auth.users WHERE id = auth.uid())
    )
  );
