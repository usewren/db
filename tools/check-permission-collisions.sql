-- READ-ONLY check for rules affected by the old global UNIQUE (principal, resource).
--
-- Before migration 011, creating a rule upserted on (principal, resource) across all
-- orgs: org B creating '*' on 'tree:site' updated org A's rule instead. Symptoms:
--   1. a rule whose tree/collection doesn't exist in the rule's own org (often the
--      other org's resource name that happened to match), and
--   2. orgs that have a public tree/collection but no '*' rule of their own for it.
-- Prints findings with RAISE NOTICE; changes nothing.
--
-- Run:  docker exec -i wren-db-1 psql -U wren -d wren < check-permission-collisions.sql

DO $$
DECLARE
  r record;
  schema_name text;
  found boolean;
  issues int := 0;
BEGIN
  FOR r IN
    SELECT p.id, p.org_id, p.principal, p.resource, p.access, p.label_filter, s.slug
    FROM common.permissions p LEFT JOIN common.org_slugs s ON s.org_id = p.org_id
    WHERE p.resource LIKE 'tree:%' OR p.resource LIKE 'collection:%'
  LOOP
    IF r.resource LIKE '%:*' THEN CONTINUE; END IF;
    -- same rule as sanitizeSchemaName() in db/runner.ts
    schema_name := 'tenant_' || regexp_replace(lower(r.org_id), '[^a-z0-9]', '_', 'g');
    BEGIN
      IF r.resource LIKE 'tree:%' THEN
        EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I.paths WHERE tree = $1)', schema_name)
          INTO found USING substr(r.resource, 6);
      ELSE
        EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I.documents WHERE collection = $1)', schema_name)
          INTO found USING substr(r.resource, 12);
      END IF;
    EXCEPTION WHEN undefined_table OR invalid_schema_name THEN
      found := false;
    END;
    IF NOT found THEN
      issues := issues + 1;
      RAISE NOTICE 'Rule % (org %, slug %): % % % (labelFilter %) names a % that does not exist in this org',
        r.id, r.org_id, coalesce(r.slug, '?'), r.principal, r.access, r.resource, coalesce(r.label_filter, '-'),
        split_part(r.resource, ':', 1);
    END IF;
  END LOOP;
  RAISE NOTICE 'Checked permission rules: % naming a missing resource', issues;
END $$;

-- The old upsert left org A's row in place (A's org, A's resource) with org B's
-- settings, so it looks valid. The fingerprint is a tree/collection NAME used by
-- more than one org: list every such name with each org's rule (or "no rule"),
-- so a human can confirm the settings are what each org intended.
DO $$
DECLARE
  t record;
  r record;
  n int;
  shared int := 0;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS _names (org_id text, slug text, kind text, name text) ON COMMIT DROP;
  FOR t IN
    SELECT u.id AS org_id, s.slug, 'tenant_' || regexp_replace(lower(u.id), '[^a-z0-9]', '_', 'g') AS sch
    FROM "user" u LEFT JOIN common.org_slugs s ON s.org_id = u.id
  LOOP
    BEGIN
      EXECUTE format('INSERT INTO _names SELECT %L, %L, ''tree'', tree FROM (SELECT DISTINCT tree FROM %I.paths) x', t.org_id, t.slug, t.sch);
      EXECUTE format('INSERT INTO _names SELECT %L, %L, ''collection'', collection FROM (SELECT DISTINCT collection FROM %I.documents) x', t.org_id, t.slug, t.sch);
    EXCEPTION WHEN undefined_table OR invalid_schema_name THEN NULL;
    END;
  END LOOP;

  FOR t IN
    SELECT kind, name, count(*) AS orgs FROM _names GROUP BY kind, name HAVING count(*) > 1 ORDER BY kind, name
  LOOP
    SELECT count(*) INTO n FROM common.permissions p WHERE p.resource = t.kind || ':' || t.name;
    IF n = 0 THEN CONTINUE; END IF;   -- shared name but nobody has rules on it: nothing to check
    shared := shared + 1;
    RAISE NOTICE '% "%" exists in % orgs:', t.kind, t.name, t.orgs;
    FOR r IN
      SELECT nm.slug, nm.org_id,
             (SELECT string_agg(format('%s %s%s', p.principal, p.access, coalesce(' label=' || p.label_filter, '')), '; ')
                FROM common.permissions p WHERE p.org_id = nm.org_id AND p.resource = t.kind || ':' || t.name) AS rules
      FROM _names nm WHERE nm.kind = t.kind AND nm.name = t.name
    LOOP
      RAISE NOTICE '    org % (%): %', coalesce(r.slug, '?'), r.org_id, coalesce(r.rules, 'no rule');
    END LOOP;
  END LOOP;
  RAISE NOTICE 'Names shared by several orgs with rules on them: % (review the settings above)', shared;
END $$;
