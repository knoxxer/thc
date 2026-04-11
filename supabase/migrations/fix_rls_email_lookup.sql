-- Migration: fix_rls_email_lookup.sql
-- Fix RLS policies to use auth.jwt()->>'email' to get the current user's email
-- from the JWT token (not auth.users table, which requires elevated permissions).

-- round_reactions
DROP POLICY IF EXISTS "Players can insert own reactions" ON round_reactions;
CREATE POLICY "Players can insert own reactions" ON round_reactions FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM players pl WHERE pl.id = player_id AND pl.email = auth.jwt()->>'email'));

DROP POLICY IF EXISTS "Players can delete own reactions" ON round_reactions;
CREATE POLICY "Players can delete own reactions" ON round_reactions FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM players pl WHERE pl.id = player_id AND pl.email = auth.jwt()->>'email'));

-- round_comments
DROP POLICY IF EXISTS "Players can insert own comments" ON round_comments;
CREATE POLICY "Players can insert own comments" ON round_comments FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM players pl WHERE pl.id = player_id AND pl.email = auth.jwt()->>'email'));

DROP POLICY IF EXISTS "Players can delete own comments" ON round_comments;
CREATE POLICY "Players can delete own comments" ON round_comments FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM players pl WHERE pl.id = player_id AND pl.email = auth.jwt()->>'email'));

-- upcoming_rounds
DROP POLICY IF EXISTS "Players can insert own upcoming_rounds" ON upcoming_rounds;
CREATE POLICY "Players can insert own upcoming_rounds" ON upcoming_rounds FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM players pl WHERE pl.id = player_id AND pl.email = auth.jwt()->>'email'));

DROP POLICY IF EXISTS "Players can delete own upcoming_rounds" ON upcoming_rounds;
CREATE POLICY "Players can delete own upcoming_rounds" ON upcoming_rounds FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM players pl WHERE pl.id = player_id AND pl.email = auth.jwt()->>'email'));

-- upcoming_round_rsvps
DROP POLICY IF EXISTS "Players can manage own rsvps" ON upcoming_round_rsvps;
CREATE POLICY "Players can manage own rsvps" ON upcoming_round_rsvps FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM players pl WHERE pl.id = player_id AND pl.email = auth.jwt()->>'email'))
  WITH CHECK (EXISTS (SELECT 1 FROM players pl WHERE pl.id = player_id AND pl.email = auth.jwt()->>'email'));

-- notifications
DROP POLICY IF EXISTS "Players can read own notifications" ON notifications;
CREATE POLICY "Players can read own notifications" ON notifications FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM players pl WHERE pl.id = player_id AND pl.email = auth.jwt()->>'email'));

DROP POLICY IF EXISTS "Players can update own notifications" ON notifications;
CREATE POLICY "Players can update own notifications" ON notifications FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM players pl WHERE pl.id = player_id AND pl.email = auth.jwt()->>'email'))
  WITH CHECK (EXISTS (SELECT 1 FROM players pl WHERE pl.id = player_id AND pl.email = auth.jwt()->>'email'));
