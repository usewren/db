-- Link each tree path to a versioned assignment document in the _paths collection
-- Migration: 004_path_assignment_docs

ALTER TABLE paths ADD COLUMN IF NOT EXISTS assignment_doc_id TEXT REFERENCES documents(id);
