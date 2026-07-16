# Master Module - Mappings

## Overview
This folder contains mapping documentation for tables migrating to the **smac_master_migration** database.

## Target Database
- **Database**: smac_master_migration (local docs); **`07-orchestration/migration_config_smac_master.json`** defines the real target (e.g. `navitasai_masters`) for runs.
- **Host**: localhost
- **Port**: 5432

## Module Purpose
The Master module contains reference/master data tables that are shared across the SMAC system. These include:
- Country and location data (countries, states, ports, airports)
- Vessel-related master data (vessels, flags, categories, classes)
- Seafarer-related master data (ranks, nationalities, religions, genders)
- Document management master data
- Company and agent master data
- And many other reference tables

## Table Count
The orchestration config lists **186** table entries for this module (**176** with `migration_enabled: true`). Mapping docs may not exist for every entry; see `07-orchestration/migration_config_smac_master.json`.

## Migration Order
Tables should be migrated in dependency order:
1. **Independent tables** (no dependencies): countries, currencies, agent_types, etc.
2. **Level 2** (depend on level 1): ports (depends on countries), flags (depends on countries), etc.
3. **Level 3** (depend on level 2): vessels (depends on countries, flags, ports, categories), etc.

## File Naming Convention
- Mapping files: `{table_name}_mapping.md`
- Example: `countries_mapping.md`, `vessels_mapping.md`
- Each mapping doc references its migration script: `04-migration-scripts/master/{table_name}_migration.sql`

## Sync From Migration Scripts

Mapping docs are generated from SQL sources:

```bash
python scripts/sync_mappings_from_migrations.py
```

Sources scanned:

| Source | Output folder |
|--------|----------------|
| `04-migration-scripts/master/*.sql` | `03-mappings/master/` |
| `04-migration-scripts/crewing/*.sql` | `03-mappings/crewing/` |
| `11-archived/*_migration.sql` (if not in master) | `03-mappings/master/` |
| `08-seed-data/**/**_seed_data.sql` (crane_types, profile_remark_types) | `03-mappings/master/` |

Also writes **alias** stubs in `03-mappings/master/` for orchestration name mismatches (`vct_requests` → `vessel_details_vct`, `owners` → `vessel_owners`, `ship_management_companies` → `companies`, etc.).

Restores archived scripts into `04-migration-scripts/master/` when missing: `airports`, `reimbursement_types`, `competency_types`, `dg_statuses`.

Each mapping doc includes:

- **Overview** — legacy/new paths from script header
- **Business Key** — from `07-orchestration/migration_config_*.json` (composite keys when applicable)
- **Migration Notes** — script header notes (`-- Note:`, bullets) plus orchestration `notes`
- **Special Considerations** — `IMPORTANT` / `Excludes` / `Includes` comments, Rule 2.x references, TRUNCATE reload, JSONB/unpivot hints, orchestration dependencies
- **ID Mappings** — **all** FK/UUID lookup temp tables from the migration script: `*_mapping`, `*_lookup`, `*_id_map`, `owner_id_mapping`, `service_type_*_lookup`, `rank_identifier_to_target`, etc. (summary table + SQL + numbered Data Transformation Rules). Pure data-staging tables (`staging_*`, `inserted_*`, …) are excluded.
- **Column Mapping** — main `INSERT … SELECT` column transforms

Re-run after migration script changes. Complex migrations (multi-INSERT, unpivot) may need manual review.

### Non-standard docs

- `agents_table_comparison.md`
- `vessels_mainengine_analysis.md`

### Crewing module mappings

Crewing table mappings live in `03-mappings/crewing/`. Master folder may contain alias stubs pointing to crewing docs for tables migrated from `04-migration-scripts/crewing/`.

## Related Folders
- Migration scripts: `04-migration-scripts/master/`
- Validation scripts: `05-validation/master/`
- Rollback scripts: `06-rollback/master/`

## Configuration
Table configuration is defined in `07-orchestration/migration_config_smac_master.json`.

