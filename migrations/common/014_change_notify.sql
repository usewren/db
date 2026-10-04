-- Change notifications for live event streams (/api/v1/_events) and webhooks
-- Migration: 014_change_notify
--
-- One trigger function shared by every tenant schema (tenant migration 013 attaches
-- it). It sends a small JSON message on the 'wren_changes' channel; Postgres delivers
-- NOTIFY only when the transaction commits, so a rolled-back write sends nothing and an
-- atomic promote arrives all at once. The message carries ids, versions and label
-- names, never document data, and stays far below the 8000-byte NOTIFY limit.
--
--   s  tenant schema        t  event type          c  collection
--   d  document id          v  version             l  label
--   k  natural key (if the collection has one)
--   p  [[tree, path], …]    (label events: where the document is mounted, at most 20)
--   tree, path              (tree events)

CREATE OR REPLACE FUNCTION common.wren_notify_change() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  msg   jsonb;
  coll  text;
  nkey  text;
  doc   text;
  mounts jsonb;
BEGIN
  IF TG_TABLE_NAME = 'versions' THEN
    EXECUTE format('SELECT collection, natural_key FROM %I.documents WHERE id = $1', TG_TABLE_SCHEMA)
      INTO coll, nkey USING NEW.document_id;
    msg := jsonb_build_object(
      't', CASE WHEN NEW.version = 1 THEN 'document.created' ELSE 'document.updated' END,
      'c', coll, 'd', NEW.document_id, 'v', NEW.version, 'k', nkey);

  ELSIF TG_TABLE_NAME = 'documents' THEN
    -- soft delete: deleted_at goes from NULL to a timestamp
    IF NEW.deleted_at IS NULL OR OLD.deleted_at IS NOT NULL THEN RETURN NULL; END IF;
    msg := jsonb_build_object('t', 'document.deleted', 'c', NEW.collection, 'd', NEW.id, 'k', NEW.natural_key);

  ELSIF TG_TABLE_NAME = 'labels' THEN
    IF TG_OP = 'UPDATE' AND NEW.version = OLD.version THEN RETURN NULL; END IF;
    doc := CASE WHEN TG_OP = 'DELETE' THEN OLD.document_id ELSE NEW.document_id END;
    EXECUTE format('SELECT collection FROM %I.documents WHERE id = $1', TG_TABLE_SCHEMA)
      INTO coll USING doc;
    IF coll IS NULL THEN RETURN NULL; END IF;  -- document itself is being removed
    EXECUTE format(
      'SELECT coalesce(jsonb_agg(jsonb_build_array(tree, path)), ''[]''::jsonb)
         FROM (SELECT tree, path FROM %I.paths WHERE document_id = $1 ORDER BY tree, path LIMIT 20) m',
      TG_TABLE_SCHEMA) INTO mounts USING doc;
    IF TG_OP = 'DELETE' THEN
      msg := jsonb_build_object('t', 'label.removed', 'c', coll, 'd', doc, 'l', OLD.label, 'p', mounts);
    ELSE
      msg := jsonb_build_object('t', 'label.set', 'c', coll, 'd', doc, 'l', NEW.label, 'v', NEW.version, 'p', mounts);
    END IF;

  ELSIF TG_TABLE_NAME = 'paths' THEN
    IF TG_OP = 'DELETE' THEN
      msg := jsonb_build_object('t', 'tree.removed', 'tree', OLD.tree, 'path', OLD.path, 'd', OLD.document_id);
    ELSE
      IF TG_OP = 'UPDATE' AND NEW.document_id IS NOT DISTINCT FROM OLD.document_id THEN RETURN NULL; END IF;
      msg := jsonb_build_object('t', 'tree.assigned', 'tree', NEW.tree, 'path', NEW.path, 'd', NEW.document_id);
    END IF;

  ELSIF TG_TABLE_NAME = 'collection_schemas' THEN
    IF TG_OP = 'DELETE' THEN
      msg := jsonb_build_object('t', 'schema.updated', 'c', OLD.collection, 'removed', true);
    ELSE
      IF TG_OP = 'UPDATE' AND NEW.schema IS NOT DISTINCT FROM OLD.schema THEN RETURN NULL; END IF;
      msg := jsonb_build_object('t', 'schema.updated', 'c', NEW.collection);
    END IF;

  ELSE
    RETURN NULL;
  END IF;

  PERFORM pg_notify('wren_changes', jsonb_strip_nulls(jsonb_build_object('s', TG_TABLE_SCHEMA) || msg)::text);
  RETURN NULL;
END $$;

INSERT INTO common.schema_versions (version, description)
VALUES (14, 'Change notifications for event streams')
ON CONFLICT (version) DO NOTHING;
