# Table Mapping: rank_combinations → rank_combinations

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: rank_combinations
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: rank_combinations
- **Source Script**: `04-migration-scripts/master/rank_combinations_migration.sql`

- **Legacy Path**: `synergy_master.public.rank_combinations`
- **New Path**: `smac_master_migration.crewing.rank_combinations`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Rank Combinations (`rank_combinations` → `rank_combinations`)

## Migration Notes

- Source: `synergy_master.public.rank_combinations` → `crewing.rank_combinations`
- SAC `id` (uuid) preserved via `resolve_target_id()` with `p_target_id = id`
- `ranks_id_mapping` FK lookup for primary/secondary rank integer IDs
- TRUNCATE target; migrates all rows even if FK mapping missing
- `status` Case 3 from `deleted_at` + `is_active` boolean
- `audit_info` uses SAC `created_by`/`updated_by`/`deleted_by` text fields

## Special Considerations

- Source table id column is UUID - preserve UUID as target id (Pattern 4)
- Script performs `TRUNCATE TABLE crewing.rank_combinations` before insert (full table reload).
- Orchestration dependencies: `combination_matrix_groups`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `ranks_id_mapping` | Check if any mappings already exist for the given source and targe | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `ranks_id_mapping`

- **Purpose**: Check if any mappings already exist for the given source and targe
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=ranks

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Pattern 4 |
| 2 | `primary_rank_id` | integer | `primary_rank_id` | uuid | Map via `ranks_id_mapping` | FK lookup |
| 3 | `secondary_rank_id` | integer | `secondary_rank_id` | uuid | Map via `ranks_id_mapping` | FK lookup; nullable |
| 4 | `—` | — | `level` | integer | Hardcoded `0` |  |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 6 | `deleted_at, is_active` | timestamp, boolean | `status` | integer | Rule 2.2.1 Case 1: `deleted_at IS NOT NULL` → 3 (Deleted); else 0 (Active) |  |
| 7 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` |  |
| 8 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` |  |
| 9 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy |  |
| 10 | `—` | — | `archived_at` | timestamp | `NULL` |  |
| 11 | `created_by, updated_by, deleted_by` | text | `audit_info` | jsonb | `migration.build_audit_info(created_by, deleted_by, updated_by, ...)` | Pattern 4; no legacy_id |

**SAC columns not migrated:** None from dblink SELECT.

**SMAC columns not migrated:** `code`, `name`, `version`, `defined_by`, `workflow_status`.
## Foreign Key Dependencies

### Prerequisites (from source script)

- `combination_matrix_groups`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Ranks ID Mapping
**Purpose**: Check if any mappings already exist for the given source and targe
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='ranks'`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/rank_combinations_migration.sql`

## Validation

- Run `05-validation/master/rank_combinations_validation.sql` if available
- Run `06-rollback/master/rank_combinations_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
