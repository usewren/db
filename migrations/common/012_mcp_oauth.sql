-- OAuth for MCP clients ("sign in with WREN" from Claude, Cursor, …)
-- Migration: 012_mcp_oauth
--
-- Tables used by Better Auth's mcp/oidc plugin. They live next to the other Better
-- Auth tables in the public schema; column names are snake_case (Kysely CamelCase).

CREATE TABLE IF NOT EXISTS public.oauth_application (
  id            TEXT        PRIMARY KEY,
  name          TEXT        NOT NULL,
  icon          TEXT,
  metadata      TEXT,
  client_id     TEXT        NOT NULL UNIQUE,
  client_secret TEXT,
  redirect_urls TEXT        NOT NULL,
  type          TEXT        NOT NULL,
  disabled      BOOLEAN     DEFAULT FALSE,
  user_id       TEXT        REFERENCES public."user"(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS oauth_application_user_id ON public.oauth_application (user_id);

CREATE TABLE IF NOT EXISTS public.oauth_access_token (
  id                       TEXT        PRIMARY KEY,
  access_token             TEXT        UNIQUE,
  refresh_token            TEXT        UNIQUE,
  access_token_expires_at  TIMESTAMPTZ,
  refresh_token_expires_at TIMESTAMPTZ,
  client_id                TEXT        REFERENCES public.oauth_application(client_id) ON DELETE CASCADE,
  user_id                  TEXT        REFERENCES public."user"(id) ON DELETE CASCADE,
  scopes                   TEXT,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS oauth_access_token_client_id ON public.oauth_access_token (client_id);
CREATE INDEX IF NOT EXISTS oauth_access_token_user_id   ON public.oauth_access_token (user_id);

CREATE TABLE IF NOT EXISTS public.oauth_consent (
  id            TEXT        PRIMARY KEY,
  client_id     TEXT        REFERENCES public.oauth_application(client_id) ON DELETE CASCADE,
  user_id       TEXT        REFERENCES public."user"(id) ON DELETE CASCADE,
  scopes        TEXT,
  consent_given BOOLEAN,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS oauth_consent_client_id ON public.oauth_consent (client_id);
CREATE INDEX IF NOT EXISTS oauth_consent_user_id   ON public.oauth_consent (user_id);

-- Which org a signed-in MCP connection acts in. Chosen on WREN's consent page;
-- one per (user, client): each configured MCP server entry registers its own client,
-- so working in two orgs = two entries, each approved for its org.
CREATE TABLE IF NOT EXISTS common.mcp_grants (
  user_id    TEXT        NOT NULL,
  client_id  TEXT        NOT NULL,
  org_id     TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, client_id)
);

INSERT INTO common.schema_versions (version, description)
VALUES (12, 'OAuth for MCP clients')
ON CONFLICT (version) DO NOTHING;
