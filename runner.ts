import postgres, { type Sql } from "postgres";
import { readFileSync, readdirSync } from "fs";
import { join } from "path";

const MIGRATIONS_DIR = join(import.meta.dir, "migrations");

// -------------------------------------------------------
// Helpers
// -------------------------------------------------------

function loadSql(dir: string, filename: string): string {
  return readFileSync(join(MIGRATIONS_DIR, dir, filename), "utf8");
}

function listMigrations(dir: string): string[] {
  return readdirSync(join(MIGRATIONS_DIR, dir))
    .filter(f => f.endsWith(".sql"))
    .sort();
}

function versionFromFilename(filename: string): number {
  return parseInt(filename.split("_")[0], 10);
}

function descriptionFromFilename(filename: string): string {
  return filename.replace(/^\d+_/, "").replace(".sql", "").replace(/_/g, " ");
}

// -------------------------------------------------------
// Common schema setup
// -------------------------------------------------------

export async function setupCommon(sql: Sql): Promise<void> {
  console.log("Setting up common schema...");

  const migrations = listMigrations("common");

  for (const filename of migrations) {
    const version = versionFromFilename(filename);
    const description = descriptionFromFilename(filename);

    // Check if already applied (schema might not exist yet on first run)
    const exists = await sql`
      SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'common' AND table_name = 'schema_versions'
      ) AS exists
    `;

    if (exists[0].exists) {
      const applied = await sql`
        SELECT 1 FROM common.schema_versions WHERE version = ${version}
      `;
      if (applied.length > 0) {
        console.log(`  [common] v${version} already applied — skipping`);
        continue;
      }
    }

    console.log(`  [common] applying v${version}: ${description}`);
    const ddl = loadSql("common", filename);
    await sql.unsafe(ddl);
    console.log(`  [common] v${version} done`);
  }
}

// -------------------------------------------------------
// Tenant schema management
// -------------------------------------------------------

export async function createTenant(sql: Sql, orgId: string, createdBy?: string): Promise<string> {
  const schemaName = sanitizeSchemaName(orgId);

  console.log(`Creating tenant schema: ${schemaName}`);

  // Create the schema
  await sql.unsafe(`CREATE SCHEMA IF NOT EXISTS ${schemaName}`);

  // Apply all tenant migrations
  await migrateTenant(sql, orgId, createdBy);

  // Register in common.tenant_versions
  const commonVersion = await getCurrentCommonVersion(sql);
  await sql`
    INSERT INTO common.tenant_versions (org_id, common_version, schema_name, migrated_by)
    VALUES (${orgId}, ${commonVersion}, ${schemaName}, ${createdBy ?? null})
    ON CONFLICT (org_id) DO NOTHING
  `;

  console.log(`Tenant ${orgId} created as schema ${schemaName}`);
  return schemaName;
}

export async function migrateTenant(sql: Sql, orgId: string, appliedBy?: string): Promise<void> {
  const schemaName = sanitizeSchemaName(orgId);
  const migrations = listMigrations("tenant");

  for (const filename of migrations) {
    const version = versionFromFilename(filename);
    const description = descriptionFromFilename(filename);

    // Check if already applied
    const applied = await sql`
      SELECT 1 FROM common.tenant_migration_log
      WHERE org_id = ${orgId} AND tenant_version = ${version}
    `;

    if (applied.length > 0) {
      console.log(`  [${orgId}] v${version} already applied — skipping`);
      continue;
    }

    console.log(`  [${orgId}] applying v${version}: ${description}`);

    const ddl = loadSql("tenant", filename);
    await sql.begin(async (tx) => {
      await tx.unsafe(`SET LOCAL search_path TO ${schemaName}, common, public`);
      await tx.unsafe(ddl);
      await tx`
        INSERT INTO common.tenant_migration_log (org_id, tenant_version, description, applied_by)
        VALUES (${orgId}, ${version}, ${description}, ${appliedBy ?? null})
      `;
    });

    console.log(`  [${orgId}] v${version} done`);
  }
}

export async function migrateAllTenants(sql: Sql, appliedBy?: string): Promise<void> {
  const tenants = await sql<{ org_id: string }[]>`
    SELECT org_id FROM common.tenant_versions ORDER BY org_id
  `;

  console.log(`Migrating ${tenants.length} tenant(s)...`);

  for (const { org_id } of tenants) {
    try {
      await migrateTenant(sql, org_id, appliedBy);
    } catch (err) {
      console.error(`  [${org_id}] migration failed:`, err);
      throw err; // Stop on failure — don't silently skip
    }
  }
}

export async function listTenants(sql: Sql) {
  return sql<{ org_id: string; schema_name: string; common_version: number; migrated_at: Date }[]>`
    SELECT org_id, schema_name, common_version, migrated_at
    FROM common.tenant_versions
    ORDER BY org_id
  `;
}

// -------------------------------------------------------
// Utilities
// -------------------------------------------------------

export function sanitizeSchemaName(orgId: string): string {
  return "tenant_" + orgId.toLowerCase().replace(/[^a-z0-9]/g, "_");
}

export async function getCurrentCommonVersion(sql: Sql): Promise<number> {
  const result = await sql`SELECT common.current_version() AS version`;
  return result[0].version;
}

export function connect(url?: string): Sql {
  return postgres(url ?? process.env.DATABASE_URL ?? "postgres://wren:wren@localhost:5432/wren");
}
