# Table Mapping: additional_wages → company_wage_scale_allowances

## Overview
- **Legacy Database**: synergy_crewwage
- **Legacy Schema**: public
- **Legacy Table**: additional_wages
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: company_wage_scale_allowances
- **Source Script**: `04-migration-scripts/master/company_wage_scale_allowances_migration.sql`

- **Legacy Path**: `synergy_crewwage.public.additional_wages`
- **New Path**: `smac_master_migration.crewing.company_wage_scale_allowances`

## Business Key

- **Composite Key**: (`company_wage_scales_id`, `wage_component_id`)
- **Source (orchestration)**: Company Wage Scale Allowances (`additional_wages` → `company_wage_scale_allowances`)

## Migration Notes

- Source `id` is bigint, target `id` is uuid — uses `migration.resolve_target_id()` with `p_target_id = NULL` (no UUID column in SAC)
- `company_wage_scale_id` mapped from SAC `wage_scale_id` via `company_wage_scale_id_mapping`; `wage_component_id` from SAC `wage_component_uuid` via `wage_components_id_mapping`
- `payment_scope`: both `min_experience` and `max_experience` NULL → `'Fixed'`, else `'Regular'`
- `experience_type` hardcoded to `'InHouse'`; `workflow_status` from `constants.sql` (Approved = 2)
- `status` derived from SAC `isdeleted`: `true` → Deleted (3), else Active (0); SAC has no `deleted_at` — target `deleted_at` set to NULL
- `audit_info` uses `SYSTEM_USER_ID` from `constants.sql` (source `created_by_id`/`updated_by_id` not mapped)
- Requires `company_wage_scales` and `wage_components` migrated first

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Script performs `TRUNCATE TABLE crewing.company_wage_scale_allowances` before insert (full table reload).
- Orchestration dependencies: `company_wage_scales`, `wage_components`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_wage_scale_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `wage_components_id_mapping` | Check if target table has existi | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `company_wage_scale_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=company_wage_scales

```sql
CREATE TEMP TABLE company_wage_scale_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_scales'
  AND target_db = current_database();
```

### `wage_components_id_mapping`

- **Purpose**: Check if target table has existi
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=wage_components

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation; SAC has bigint `id` only |
| 2 | `wage_scale_id` | bigint | `company_wage_scale_id` | uuid | Map via `company_wage_scale_id_mapping`; fallback empty GUID | Lookup: `migration.table_mappings` where `target_table = 'company_wage_scales'` |
| 3 | `wage_component_uuid` | uuid | `wage_component_id` | uuid | Map via `wage_components_id_mapping`; fallback empty GUID | Lookup: `migration.table_mappings` where `target_table = 'wage_components'` |
| 4 | `min_experience`, `max_experience` | integer | `payment_scope` | text | Both NULL → `'Fixed'`; otherwise `'Regular'` | Derived from experience range columns |
| 5 | — | — | `experience_type` | text | Hardcoded `'InHouse'` | Constant; not in SAC source |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 7 | — | — | `parent_id` | uuid | `NULL` | No parent relationship in SAC |
| 8 | — | — | `level` | numeric | Hardcoded `0` | Hierarchy level; not in SAC source |
| 9 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 10 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 11 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 12 | `isdeleted` | boolean | `status` | integer | `isdeleted = true` → Deleted (3); else Active (0) | SAC uses `isdeleted` flag (no `deleted_at` column) |
| 13 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback; NOT NULL in SMAC |
| 14 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | Direct copy | May be NULL in source |
| 15 | — | — | `deleted_at` | timestamp without time zone | `NULL` | SAC has no `deleted_at`; soft-delete tracked via `isdeleted` only |
| 16 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` from `constants.sql` | Standardized SMAC audit structure; `legacy_id` handled by `id_mappings` |
| 17 | — | — | `tags` | text[] | `NULL` | Not populated; not in SAC source |

**SMAC columns not migrated:** `archived_at` — no source equivalent in SAC `additional_wages`.

**SAC columns not migrated:** `created_by_id`, `updated_by_id` — audit uses `SYSTEM_USER_ID` instead of source values.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `company_wage_scales`
- `wage_components`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company Wage Scale ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='company_wage_scales'`

```sql
CREATE TEMP TABLE company_wage_scale_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_scales'
  AND target_db = current_database();
```

### 2. Wage Components ID Mapping
**Purpose**: Check if target table has existi
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='wage_components'`

```sql
CREATE TEMP TABLE wage_components_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'wage_components'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/company_wage_scale_allowances_migration.sql`

## Validation

- Run `05-validation/master/company_wage_scale_allowances_validation.sql` if available
- Run `06-rollback/master/company_wage_scale_allowances_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
