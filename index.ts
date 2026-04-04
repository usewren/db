#!/usr/bin/env bun
import { connect, setupCommon, createTenant, migrateTenant, migrateAllTenants, listTenants } from "./runner";

const [command, ...args] = process.argv.slice(2);

const sql = connect();

switch (command) {
  case "setup":
    // Set up the common schema
    await setupCommon(sql);
    break;

  case "create-tenant": {
    // Create a new tenant schema
    // Usage: bun run index.ts create-tenant <org_id>
    const orgId = args[0];
    if (!orgId) { console.error("Usage: create-tenant <org_id>"); process.exit(1); }
    await setupCommon(sql);
    await createTenant(sql, orgId);
    break;
  }

  case "migrate": {
    // Migrate a specific tenant or all tenants
    // Usage: bun run index.ts migrate [org_id]
    const orgId = args[0];
    if (orgId) {
      await migrateTenant(sql, orgId);
    } else {
      await migrateAllTenants(sql);
    }
    break;
  }

  case "list":
    // List all tenants and their migration status
    const tenants = await listTenants(sql);
    if (tenants.length === 0) {
      console.log("No tenants found.");
    } else {
      console.table(tenants.map(t => ({
        org_id: t.org_id,
        schema: t.schema_name,
        common_v: t.common_version,
        migrated_at: t.migrated_at.toISOString(),
      })));
    }
    break;

  default:
    console.log(`
Wren DB — migration runner

Commands:
  setup                   Set up the common schema
  create-tenant <org_id>  Create a new tenant schema and run migrations
  migrate [org_id]        Run pending migrations (all tenants or one)
  list                    List all tenants and their migration status
    `);
    process.exit(command ? 1 : 0);
}

await sql.end();
