# Table Mapping: seafarer_availability_log → seafarer_availability_logs

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_availability_log
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_availability_logs
- **Source Script**: `04-migration-scripts/crewing/seafarer_availability_logs_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_availability_log`
- **New Path**: `smac_crewing_migration.shore.seafarer_availability_logs`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Availability Logs (`seafarer_availability_log` → `seafarer_availability_logs`)

## Migration Notes

- SAC `seafarer_availability_log` → SMAC `shore.seafarer_availability_logs` (table name pluralized)
- SAC `id` (uuid) preserved via `migration.resolve_target_id()` with `p_target_id = id`
- `seafarer_id` mapped via `seafarers_id_mapping` (`target_table = 'seafarers'`)
- `remarks_id` (bigint) mapped via `availability_remarks_id_mapping` from `smac_master_migration`
- `availability_status` hardcoded `'available'`; `status` hardcoded `'active'` (SAC has neither column)
- SAC has no `created_at` — both `created_at` and `updated_at` use SAC `updated_at`
- `source` truncated to 50 characters; `edit_reason`, `related_entity`, `vessel_revision_id` not in SAC — `NULL`
- `audit_info` via `migration.build_audit_info()` — `created_by` = `SYSTEM_USER_ID`; `updated_by` from SAC `audit_info.UpdatedBy`
- Requires `seafarers` and master `availability_remarks` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_availability_logs` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | Prese | `seafarer_uuid`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `availability_remarks_id_mapping` | C | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

### `seafarers_id_mapping`

- **Purpose**: Prese
- **Output columns**: seafarer_uuid, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    target_id as seafarer_uuid,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `availability_remarks_id_mapping`

- **Purpose**: C
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE availability_remarks_id_mapping AS
SELECT
    t.source_id::bigint as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''availability_remarks'' AND target_db = current_database()'
) AS t(source_id text, target_id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID; idempotent |
| 2 | `seafarer_id` | uuid | `seafarer_id` | uuid | Map via `seafarers_id_mapping` (`target_table = 'seafarers'`) | LEFT JOIN — nullable if unmapped |
| 3 | `availability_date` | timestamp | `availability_date` | timestamp without time zone | Direct copy | |
| 4 | — | — | `availability_status` | character varying(50) | Hardcoded `'available'` | SAC has no status column; NOT NULL in SMAC |
| 5 | `remarks_id` | bigint | `remarks_id` | uuid | Map via `availability_remarks_id_mapping` from `smac_master_migration` | LEFT JOIN — nullable |
| 6 | `other_remarks` | text | `other_remarks` | text | `TRIM(other_remarks)` | |
| 7 | `source` | text | `source` | character varying(50) | `LEFT(TRIM(source), 50)` | Truncated to 50 chars |
| 8 | `is_latest` | boolean | `is_latest` | boolean | `COALESCE(is_latest, true)` | Defaults to true |
| 9 | `is_edited` | boolean | `is_edited` | boolean | `COALESCE(is_edited, false)` | Defaults to false |
| 10 | — | — | `edit_reason` | text | `NULL` | No equivalent in SAC |
| 11 | — | — | `related_entity` | text | `NULL` | No equivalent in SAC |
| 12 | — | — | `related_entity_id` | uuid | `NULL` | No equivalent in SAC |
| 13 | — | — | `status` | text | Hardcoded `'active'` | SAC has no status column |
| 14 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 15 | `updated_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | SAC has no `created_at` |
| 16 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 17 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 18 | — | — | `deleted_at` | timestamp without time zone | `NULL` | SAC has no soft-delete column |
| 19 | `audit_info` | jsonb | `audit_info` | jsonb | `migration.build_audit_info()` — `created_by` = `SYSTEM_USER_ID`; `updated_by` from `UpdatedBy` | SAC lacks `CreatedBy` |
| 20 | — | — | `vessel_revision_id` | uuid | `NULL` | No equivalent in SAC |

**SMAC columns not migrated:** None beyond unpopulated nullable fields.

**SAC columns not migrated:** None — all SAC columns in migration SELECT are mapped or absorbed into `audit_info`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Purpose**: Prese
**Output columns**: `seafarer_uuid, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    target_id as seafarer_uuid,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Availability Remarks ID Mapping
**Purpose**: C
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE availability_remarks_id_mapping AS
SELECT
    t.source_id::bigint as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''availability_remarks'' AND target_db = current_database()'
) AS t(source_id text, target_id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_availability_logs_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_availability_logs_validation.sql` if available
- Run `06-rollback/crewing/seafarer_availability_logs_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
