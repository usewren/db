# WREN Database

Postgres database layer for [WREN](https://wren.aemwip.com).

Contains the migration runner and all SQL migrations for both the shared `common` schema (users, API keys, permissions, invites, org members) and per-tenant schemas (documents, versions, labels, paths, collection schemas, asset contents).

## Migrations

Migrations are applied automatically on server start. Each tenant schema is migrated independently.

- `migrations/common/` — shared tables (run once)
- `migrations/tenant/` — per-org tables (run per schema)

## Links

- **Website:** https://wren.aemwip.com
- **All repos:** [github.com/usewren](https://github.com/usewren)
- **Tutorial:** https://wren.aemwip.com/tutorial
- **API Docs:** https://wren.aemwip.com/docs

## License

Apache-2.0
