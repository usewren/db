-- Tenant schema: multi-tree support
-- Migration: 002_paths_multi_tree
-- Adds a `tree` column to paths so a tenant can have multiple named trees.
-- Existing rows default to 'main'.

ALTER TABLE paths ADD COLUMN IF NOT EXISTS tree TEXT NOT NULL DEFAULT 'main';

-- Drop the old single-column unique constraint and replace with (tree, path)
ALTER TABLE paths DROP CONSTRAINT IF EXISTS paths_path_key;
ALTER TABLE paths ADD CONSTRAINT paths_tree_path_key UNIQUE (tree, path);

-- Drop old prefix index, replace with one that includes tree
DROP INDEX IF EXISTS paths_path_idx;
CREATE INDEX IF NOT EXISTS paths_tree_path_idx ON paths (tree, path text_pattern_ops);
