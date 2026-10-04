-- Send change notifications for live event streams and webhooks
-- Migration: 013_change_events
--
-- Attaches common.wren_notify_change() (common migration 014). AFTER triggers, so a
-- failed statement sends nothing; NOTIFY itself waits for the commit.

DROP TRIGGER IF EXISTS wren_change_versions ON versions;
CREATE TRIGGER wren_change_versions AFTER INSERT ON versions
  FOR EACH ROW EXECUTE FUNCTION common.wren_notify_change();

DROP TRIGGER IF EXISTS wren_change_documents ON documents;
CREATE TRIGGER wren_change_documents AFTER UPDATE OF deleted_at ON documents
  FOR EACH ROW EXECUTE FUNCTION common.wren_notify_change();

DROP TRIGGER IF EXISTS wren_change_labels ON labels;
CREATE TRIGGER wren_change_labels AFTER INSERT OR UPDATE OR DELETE ON labels
  FOR EACH ROW EXECUTE FUNCTION common.wren_notify_change();

DROP TRIGGER IF EXISTS wren_change_paths ON paths;
CREATE TRIGGER wren_change_paths AFTER INSERT OR UPDATE OR DELETE ON paths
  FOR EACH ROW EXECUTE FUNCTION common.wren_notify_change();

DROP TRIGGER IF EXISTS wren_change_schemas ON collection_schemas;
CREATE TRIGGER wren_change_schemas AFTER INSERT OR UPDATE OR DELETE ON collection_schemas
  FOR EACH ROW EXECUTE FUNCTION common.wren_notify_change();
