-- Fix calculate_round_points trigger.
--
-- Bug: net_vs_par is a GENERATED ALWAYS column, which Postgres evaluates AFTER
-- BEFORE INSERT triggers fire. So NEW.net_vs_par is NULL inside this trigger,
-- and `10 - NULL` is NULL. LEAST/GREATEST silently ignore NULLs, so every new
-- round was getting clamped to the ceiling (15) regardless of actual score.
--
-- Fix: compute net_vs_par inline from the source columns, which ARE populated
-- in the BEFORE INSERT trigger.

CREATE OR REPLACE FUNCTION calculate_round_points()
RETURNS TRIGGER AS $$
BEGIN
  NEW.points = GREATEST(
    1,
    LEAST(
      15,
      10 - ((NEW.gross_score - NEW.course_handicap) - NEW.par)
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
