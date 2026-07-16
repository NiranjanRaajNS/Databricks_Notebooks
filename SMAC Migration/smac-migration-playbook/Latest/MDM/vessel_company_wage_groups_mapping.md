# Table Mapping: vessel_company_wage_groups → vessel_company_wage_groups

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_company_wage_groups
- **Source Script**: `04-migration-scripts/master/vessel_company_wage_groups_migration.sql`

- **New Path**: `smac_master_migration.vessel.vessel_company_wage_groups`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Company Wage Groups (`vessel_groups` → `company_wage_groups`)

## Migration Notes

- SAC `id` (bigint) → SMAC `id` via `migration.resolve_target_id()` with `p_target_id = NULL`
- `vessel_id` via `vessels_id_mapping`; `company_wage_group_id` via `group_id` mapping
- `vessel_revision_id` from active revision lookup
- `status` Case 2: `deleted_at` takes precedence over `status` string
- INNER JOIN on all FK maps — skips unmapped rows
- Migrate ALL records including deleted
## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE vessel.vessel_company_wage_groups` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessels_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `company_wage_groups_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `vessel_revision_id_mapping` | FK lookup | `new_vessel_id`, `active_revision_id` | - | - |

### `vessels_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### `company_wage_groups_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=company_wage_groups

```sql
CREATE TEMP TABLE company_wage_groups_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_groups'
  AND target_db = current_database();
```

### `vessel_revision_id_mapping`

- **Output columns**: new_vessel_id, active_revision_id

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM vessel.vessel_revisions vr
ORDER BY vr.vessel_id, vr.created_at DESC;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation |
| 2 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessels_id_mapping` | FK lookup |
| 3 | `—` | — | `vessel_revision_id` | uuid | Active revision from `vessel_revision_id_mapping` | FK lookup |
| 4 | `group_id` | bigint | `company_wage_group_id` | uuid | Map via `company_wage_groups_id_mapping` | FK lookup |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 6 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 7 | `—` | — | `level` | integer | Hardcoded `0` | Default hierarchy level |
| 8 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 9 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 10 | `status, deleted_at` | text, timestamp without time zone | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Case 2 |
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 12 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Direct copy with fallback |
| 13 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 14 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID)` | No audit columns in SAC |

**SAC columns not migrated:** `deleted_by`, `created_by_id`, `updated_by_id`, `isdeleted` — not referenced in INSERT.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.company_wage_groups`
- `vessel.vessel_revisions`
- `vessel.vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessels ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 2. Company Wage Groups ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='company_wage_groups'`

```sql
CREATE TEMP TABLE company_wage_groups_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'company_wage_groups'
  AND target_db = current_database();
```

### 3. Vessel Revision ID Mapping
**Output columns**: `new_vessel_id, active_revision_id`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (vr.vessel_id)
    vr.vessel_id AS new_vessel_id,
    vr.id AS active_revision_id
FROM vessel.vessel_revisions vr
ORDER BY vr.vessel_id, vr.created_at DESC;
```

Full migration context: `04-migration-scripts/master/vessel_company_wage_groups_migration.sql`

## Validation

- Run `05-validation/master/vessel_company_wage_groups_validation.sql` if available
- Run `06-rollback/master/vessel_company_wage_groups_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
