-- Migration: create_course_tables.sql
-- Creates course_data, course_holes, and app_config tables with RLS policies.
-- Also enables required extensions and installs update triggers.
-- Covers: M6.6

-- ============================================================
-- Prerequisites: enable required extensions
-- ============================================================

-- pg_trgm: fuzzy text search for course name lookups.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- earthdistance (CASCADE also installs cube): geographic distance queries.
-- Used by the GiST index on course_data for radius-based course lookup.
CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE;


-- ============================================================
-- Shared updated_at trigger function
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- course_data: Course metadata (seeded from GolfCourseAPI or OSM)
-- ============================================================

CREATE TABLE IF NOT EXISTS course_data (
  id               uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  golfcourseapi_id int          UNIQUE,
  name             text         NOT NULL,
  club_name        text,
  address          text,
  lat              double precision NOT NULL,
  lon              double precision NOT NULL,
  hole_count       int          NOT NULL DEFAULT 18,
  par              int          NOT NULL DEFAULT 72,
  osm_id           text,
  has_green_data   boolean      NOT NULL DEFAULT false,
  created_at       timestamptz  NOT NULL DEFAULT now(),
  updated_at       timestamptz  NOT NULL DEFAULT now()
);

-- Geographic distance index (requires earthdistance extension).
CREATE INDEX IF NOT EXISTS idx_course_data_location
  ON course_data USING gist (ll_to_earth(lat, lon));

-- Fallback bounding-box index if ll_to_earth is unavailable.
CREATE INDEX IF NOT EXISTS idx_course_data_lat_lon
  ON course_data (lat, lon);

-- Trigram index for fuzzy course name search.
CREATE INDEX IF NOT EXISTS idx_course_data_name
  ON course_data USING gin (name gin_trgm_ops);

-- Automatically stamp updated_at on any update.
DROP TRIGGER IF EXISTS course_data_updated_at ON course_data;
CREATE TRIGGER course_data_updated_at
  BEFORE UPDATE ON course_data
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- RLS: authenticated users read, insert, and update.
ALTER TABLE course_data ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read course_data" ON course_data;
CREATE POLICY "Authenticated users can read course_data"
  ON course_data FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert course_data" ON course_data;
CREATE POLICY "Authenticated users can insert course_data"
  ON course_data FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can update course_data" ON course_data;
CREATE POLICY "Authenticated users can update course_data"
  ON course_data FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);


-- ============================================================
-- course_holes: Per-hole data (from OSM or tap-and-save pins)
-- ============================================================

CREATE TABLE IF NOT EXISTS course_holes (
  id             uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id      uuid         NOT NULL REFERENCES course_data(id) ON DELETE CASCADE,
  hole_number    int          NOT NULL CHECK (hole_number BETWEEN 1 AND 18),
  par            int          NOT NULL CHECK (par BETWEEN 3 AND 6),
  yardage        int,
  handicap       int          CHECK (handicap BETWEEN 1 AND 18),
  green_lat      double precision,
  green_lon      double precision,
  green_polygon  jsonb,
  tee_lat        double precision,
  tee_lon        double precision,
  source         text         NOT NULL CHECK (source IN ('osm', 'tap_and_save')),
  saved_by       uuid         REFERENCES auth.users(id),
  created_at     timestamptz  NOT NULL DEFAULT now(),
  updated_at     timestamptz  NOT NULL DEFAULT now(),
  UNIQUE (course_id, hole_number)
);

CREATE INDEX IF NOT EXISTS idx_course_holes_course
  ON course_holes (course_id);

-- Automatically stamp updated_at on any update.
DROP TRIGGER IF EXISTS course_holes_updated_at ON course_holes;
CREATE TRIGGER course_holes_updated_at
  BEFORE UPDATE ON course_holes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- RLS: authenticated users read, insert, update, and delete.
ALTER TABLE course_holes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read course_holes" ON course_holes;
CREATE POLICY "Authenticated users can read course_holes"
  ON course_holes FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert course_holes" ON course_holes;
CREATE POLICY "Authenticated users can insert course_holes"
  ON course_holes FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can update course_holes" ON course_holes;
CREATE POLICY "Authenticated users can update course_holes"
  ON course_holes FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can delete course_holes" ON course_holes;
CREATE POLICY "Authenticated users can delete course_holes"
  ON course_holes FOR DELETE
  TO authenticated
  USING (true);


-- ============================================================
-- has_green_data trigger: auto-update course_data when all
-- holes for a course have green coordinates saved.
-- Fires after INSERT or UPDATE on course_holes.
-- ============================================================

CREATE OR REPLACE FUNCTION sync_course_has_green_data()
RETURNS TRIGGER AS $$
DECLARE
  v_hole_count    int;
  v_holes_with_green int;
BEGIN
  -- Determine how many holes the course is expected to have.
  SELECT hole_count INTO v_hole_count
  FROM course_data
  WHERE id = NEW.course_id;

  -- Count how many holes currently have green coordinates.
  SELECT COUNT(*) INTO v_holes_with_green
  FROM course_holes
  WHERE course_id = NEW.course_id
    AND green_lat IS NOT NULL
    AND green_lon IS NOT NULL;

  -- Update the flag: true when every expected hole has green data.
  UPDATE course_data
  SET has_green_data = (v_holes_with_green >= v_hole_count)
  WHERE id = NEW.course_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS course_holes_sync_green_data ON course_holes;
CREATE TRIGGER course_holes_sync_green_data
  AFTER INSERT OR UPDATE OF green_lat, green_lon ON course_holes
  FOR EACH ROW EXECUTE FUNCTION sync_course_has_green_data();


-- ============================================================
-- app_config: Runtime configuration (API keys, feature flags)
-- Only service_role may write; authenticated users may read.
-- ============================================================

CREATE TABLE IF NOT EXISTS app_config (
  key        text        PRIMARY KEY,
  value      text        NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Seed GolfCourseAPI key placeholder.
-- Replace 'YOUR_KEY_HERE' with the real key via the Supabase dashboard
-- or a service-role SQL call — never commit the live key to version control.
INSERT INTO app_config (key, value)
VALUES ('golfcourseapi_key', 'YOUR_KEY_HERE')
ON CONFLICT (key) DO NOTHING;

-- RLS: authenticated users can read; no client writes allowed.
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read app_config" ON app_config;
CREATE POLICY "Authenticated users can read app_config"
  ON app_config FOR SELECT
  TO authenticated
  USING (true);

-- Writes are intentionally withheld from all non-service-role callers.
-- The service_role key bypasses RLS by design in Supabase.
