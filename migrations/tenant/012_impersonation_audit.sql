-- Record changes made while an org admin impersonates a member.
-- Migration: 012_impersonation_audit
--
-- During an impersonated request the server runs each transaction with
--   SET LOCAL wren.impersonated_by = '<admin user id>'
-- and these column defaults pick it up, so every write path (new versions, label
-- moves, tree assignments) records the impersonating admin without each INSERT
-- having to remember. created_by stays the impersonated member.
-- current_setting(..., true) returns NULL when unset; NULLIF covers '' after reset.

ALTER TABLE versions ADD COLUMN IF NOT EXISTS impersonated_by TEXT
  DEFAULT NULLIF(current_setting('wren.impersonated_by', true), '');
ALTER TABLE labels   ADD COLUMN IF NOT EXISTS impersonated_by TEXT
  DEFAULT NULLIF(current_setting('wren.impersonated_by', true), '');
ALTER TABLE paths    ADD COLUMN IF NOT EXISTS impersonated_by TEXT
  DEFAULT NULLIF(current_setting('wren.impersonated_by', true), '');
