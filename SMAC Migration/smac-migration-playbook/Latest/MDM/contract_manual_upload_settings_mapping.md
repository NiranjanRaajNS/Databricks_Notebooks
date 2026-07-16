# Table Mapping: vessel_onboarding_statuses → contract_manual_upload_settings

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: vessel_onboarding_statuses
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: contract_manual_upload_settings
- **Source Script**: `04-migration-scripts/master/contract_manual_upload_settings_migration.sql`

- **Legacy Path**: `synergy_master.public.vessel_onboarding_statuses`
- **New Path**: `smac_master_migration.crewing.contract_manual_upload_settings`

## Business Key

- **Business Key**: `vessel_id` (one settings row per vessel)
- **Source (orchestration)**: Contract Manual Upload Settings (`vessel_onboarding_statuses` → `contract_manual_upload_settings`)

## Migration Notes

- Source `id` is bigint, target `id` is uuid — uses `migration.resolve_target_id()` with `p_target_id = NULL` (no UUID column in SAC)
- `vessel_id` mapped from SAC `vessel_id` via `vessels_id_mapping`; `vessel_revision_id` set to empty GUID
- `manual_upload_enabled` derived from JSONB `contract_manual_upload->>'enable' = 'true'`
- `rules` transforms `country_codes` array: legacy `position` bigint[] → SMAC `positions` UUID[] via `positions_id_mapping`; unmapped positions excluded
- `status` hardcoded Active (0); SAC has no `deleted_at` — target `deleted_at` and `archived_at` set to NULL
- `audit_info` uses `SYSTEM_USER_ID` from `constants.sql`; `legacy_id` added via `jsonb_set`
- Requires `vessels` and `positions` migrated first

## Special Considerations

- SAC has no UUID/identifier column — UUID duplicate check skipped
- Script performs `TRUNCATE TABLE crewing.contract_manual_upload_settings` before insert (full table reload)
- Orchestration dependencies: `vessels`, `positions`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessels_id_mapping` | Check for duplicate UUIDs in source table | `legacy_id`, `new_vessel_id` | `migration.table_mappings` (see SQL) | - |
| `positions_id_mapping` | Clear existing data fr | `legacy_position_id`, `new_position_id` | `migration.table_mappings` (see SQL) | - |

### `vessels_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: legacy_id, new_vessel_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::text AS legacy_id,
    target_id AS new_vessel_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### `positions_id_mapping`

- **Purpose**: Clear existing data fr
- **Output columns**: legacy_position_id, new_position_id
- **migration.table_mappings**: target_table=positions

```sql
CREATE TEMP TABLE positions_id_mapping AS
SELECT
    source_id::text AS legacy_position_id,
    target_id AS new_position_id
FROM migration.table_mappings
WHERE target_table = 'positions'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation; SAC has bigint `id` only |
| 2 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessels_id_mapping` on `vessel_id::text` | Lookup: `migration.table_mappings` where `target_table = 'vessels'` |
| 3 | — | — | `vessel_revision_id` | uuid | Empty GUID `00000000-0000-0000-0000-000000000000` | Not needed; hardcoded placeholder |
| 4 | `contract_manual_upload` | jsonb | `manual_upload_enabled` | boolean | JSON `enable = 'true'` → `true`; else `false` | Extracted from JSONB `contract_manual_upload` field |
| 5 | `contract_manual_upload` | jsonb | `rules` | jsonb | Transform `country_codes`: map `position` bigint[] → `positions` UUID[] via `positions_id_mapping`; keep `nationality` | Complex JSONB restructuring; unmapped positions excluded |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 7 | — | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 8 | — | — | `level` | numeric | Hardcoded `0` | Not in SAC source |
| 9 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 10 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 11 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 12 | — | — | `status` | integer | Hardcoded `0` (Active) | SAC has no status/deleted_at columns |
| 13 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 14 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 15 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 16 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 17 | `id` | bigint | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID`; `legacy_id` added via `jsonb_set` | Standardized SMAC audit structure with `legacy_id` |
| 18 | — | — | `tags` | text[] | `NULL` | Not populated; not in SAC source |

**SMAC columns not migrated:** None — all target columns populated.

**SAC columns not migrated:** None — all SAC columns used in transformation.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `vessels`
- `positions`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessels ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `legacy_id, new_vessel_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::text AS legacy_id,
    target_id AS new_vessel_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 2. Positions ID Mapping
**Purpose**: Clear existing data fr
**Output columns**: `legacy_position_id, new_position_id`
**migration.table_mappings**: `target_table='positions'`

```sql
CREATE TEMP TABLE positions_id_mapping AS
SELECT
    source_id::text AS legacy_position_id,
    target_id AS new_position_id
FROM migration.table_mappings
WHERE target_table = 'positions'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/contract_manual_upload_settings_migration.sql`

## Validation

- Run `05-validation/master/contract_manual_upload_settings_validation.sql` if available
- Run `06-rollback/master/contract_manual_upload_settings_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
