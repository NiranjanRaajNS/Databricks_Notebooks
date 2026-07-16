# Table Mapping: cba_audit_info → cba_audit_info

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cba_audit_info
- **Source Script**: `04-migration-scripts/master/cba_audit_info_migration.sql`

- **New Path**: `smac_master_migration.crewing.cba_audit_info`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Cba Audit Info (`cba_audit_info` → `cba_audit_info`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- `cba_id` mapped via `cbas_id_mapping`; fallback zero-UUID
- `changed_by` from `created_by_id`; `changed_on` from `created_at`
- `status`: `deleted_at IS NOT NULL` → Inactive (2); else Active (0)

## Special Considerations

- Source table has id column as UUID - preserve legacy UUID
- Script performs `TRUNCATE TABLE crewing.cba_audit_info` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cbas_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `cbas_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=cbas

```sql
CREATE TEMP TABLE cbas_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cbas'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — `p_target_id = id` | Preserves SAC uuid |
| 2 | `description` | text | `description` | text | `TRIM(description)` | Direct copy |
| 3 | `action` | text | `action` | text | Direct copy | Direct copy |
| 4 | `cba_id` | bigint | `cba_id` | uuid | Map via `cbas_id_mapping`; zero-UUID fallback | FK: `cbas` |
| 5 | `created_by_id` | text | `changed_by` | uuid | `created_by_id::uuid` or zero-UUID | Renamed column |
| 6 | `created_at` | timestamp without time zone | `changed_on` | timestamp without time zone | `COALESCE(created_at, NOW())` | Audit timestamp |
| 7 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` | From constants.sql |
| 8 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 9 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` | From constants.sql |
| 10 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` | From constants.sql |
| 11 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Inactive (2); else Active (0) | Note: uses 2 not 3 for deleted |
| 12 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 13 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` |  |
| 14 | `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Uses created_at for both |
| 15 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy |  |
| 16 | `created_by_id` | text | `audit_info` | jsonb | `migration.build_audit_info()` | Standard SMAC audit |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Cbas ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='cbas'`

```sql
CREATE TEMP TABLE cbas_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cbas'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/cba_audit_info_migration.sql`

## Validation

- Run `05-validation/master/cba_audit_info_validation.sql` if available
- Run `06-rollback/master/cba_audit_info_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
