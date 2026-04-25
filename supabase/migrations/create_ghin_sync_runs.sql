-- Track every GHIN sync invocation so we can surface health on the home page.
-- Service role inserts; anyone can read.

CREATE TABLE IF NOT EXISTS ghin_sync_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ran_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL CHECK (status IN ('success', 'partial', 'failed')),
  players_synced int NOT NULL DEFAULT 0,
  scores_imported int NOT NULL DEFAULT 0,
  error_message text
);

CREATE INDEX IF NOT EXISTS ghin_sync_runs_ran_at_idx
  ON ghin_sync_runs (ran_at DESC);

ALTER TABLE ghin_sync_runs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read sync runs" ON ghin_sync_runs;
CREATE POLICY "Anyone can read sync runs"
  ON ghin_sync_runs FOR SELECT
  TO anon, authenticated
  USING (true);
