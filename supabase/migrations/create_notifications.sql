-- Migration: create_notifications.sql
-- Creates notifications table for in-app notification center.
-- Notifications are created server-side (via API route) when key events occur.

CREATE TABLE IF NOT EXISTS notifications (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id  uuid        NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  type       text        NOT NULL CHECK (type IN ('new_round', 'reaction', 'comment', 'rsvp', 'upcoming_round')),
  title      text        NOT NULL,
  body       text,
  link       text,
  is_read    boolean     NOT NULL DEFAULT false,
  metadata   jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_player_unread
  ON notifications (player_id, is_read, created_at DESC);

-- RLS: players can only read and update their own notifications.
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Players can read own notifications" ON notifications;
CREATE POLICY "Players can read own notifications"
  ON notifications FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM players p
      WHERE p.id = player_id
        AND p.auth_user_id = auth.uid()::text
    )
  );

DROP POLICY IF EXISTS "Players can update own notifications" ON notifications;
CREATE POLICY "Players can update own notifications"
  ON notifications FOR UPDATE
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

-- Service role can insert notifications for any player (used by API route).
DROP POLICY IF EXISTS "Service role can insert notifications" ON notifications;
CREATE POLICY "Service role can insert notifications"
  ON notifications FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Also allow authenticated users to insert (for server-side API route with service key).
DROP POLICY IF EXISTS "Authenticated can insert notifications" ON notifications;
CREATE POLICY "Authenticated can insert notifications"
  ON notifications FOR INSERT
  TO authenticated
  WITH CHECK (true);
