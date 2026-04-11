-- Security fixes: server-side points calculation + restrict notification inserts

-- ============================================================
-- 1. Remove overly permissive notifications INSERT policy
--    Only the service_role client should insert notifications.
-- ============================================================

DROP POLICY IF EXISTS "Authenticated can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Service role can insert notifications" ON notifications;

-- Service role bypasses RLS entirely, so no explicit policy needed.
-- But for clarity, we keep one:
CREATE POLICY "Service role can insert notifications"
  ON notifications FOR INSERT
  TO service_role
  WITH CHECK (true);

-- ============================================================
-- 2. Server-side points calculation trigger
--    Points = max(1, min(15, 10 - net_vs_par))
--    Runs on INSERT and UPDATE, overriding any client-supplied value.
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_round_points()
RETURNS TRIGGER AS $$
BEGIN
  NEW.points = GREATEST(1, LEAST(15, 10 - NEW.net_vs_par));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enforce_round_points ON rounds;
CREATE TRIGGER enforce_round_points
  BEFORE INSERT OR UPDATE ON rounds
  FOR EACH ROW EXECUTE FUNCTION calculate_round_points();
