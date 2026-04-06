-- Migration: add_app_source.sql
-- Allow "app" as a valid source value on the rounds table.
-- Applies to: iOS app submissions via SyncService.
--
-- Safety audit: inspect existing source values before adding constraint.
-- Run this manually before applying the migration to confirm no unexpected values:
--
--   SELECT DISTINCT source FROM rounds;
--
-- Expected output: only 'manual' and 'ghin'. If any other values exist, they
-- must be corrected before the CHECK constraint can be added.

-- Drop the constraint if it already exists (idempotent re-run support).
ALTER TABLE rounds
  DROP CONSTRAINT IF EXISTS rounds_source_check;

-- Add CHECK constraint allowing all three valid source values.
ALTER TABLE rounds
  ADD CONSTRAINT rounds_source_check
  CHECK (source IN ('manual', 'ghin', 'app'));
