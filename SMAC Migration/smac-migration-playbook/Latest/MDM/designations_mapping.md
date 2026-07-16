# Table Mapping: "Designation" → designations

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: "Designation"
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: designations
- **Source Script**: `04-migration-scripts/master/designations_migration.sql`

- **Legacy Path**: `synergy_identity_shore_prod.public."Designation"`
- **New Path**: `smac_master_migration.public.designations`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Designation (`Designation` → `designations`)

## Migration Notes

- Source: `synergy_identity_shore_prod.public."Designation"` (case-sensitive)
- Source `Id` (integer) -> `migration.resolve_target_id()` with `p_target_id = NULL`
- `department_id` mapped from `DepartmentId` via `departments_id_mapping`
- `code` from `generate_meaningful_code(name)`
- No timestamps in SAC — `created_at`/`updated_at` set to NOW()
- Requires `departments` migrated first


## Special Considerations

- Script performs `TRUNCATE TABLE public.designations` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `departments_id_mapping` | Note: No duplicate UUID check needed as source table does not have identifier/uuid column | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `departments_id_mapping`

- **Purpose**: Note: No duplicate UUID check needed as source table does not have identifier/uuid column
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=departments

```sql
CREATE TEMP TABLE departments_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'departments'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `Id` | integer | `id` | uuid | `migration.resolve_target_id()` — source_id = `Id::text`; `p_target_id = NULL` | Idempotent UUID |
| 2 | `Name` | text | `name` | text | `TRIM(Name)` | NOT NULL in SMAC |
| 3 | `Name` | text | `code` | text | `generate_meaningful_code(TRIM(Name), NULL)` | Generated from name |
| 4 | `Description` | text | `description` | text | `NULLIF(TRIM(Description), '')` | Optional |
| 5 | `DepartmentId` | integer | `department_id` | uuid | Map via `departments_id_mapping`; fallback empty GUID | FK: `departments` |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 7 | — | — | `version` | integer | Hardcoded `1` | |
| 8 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 9 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 10 | — | — | `status` | integer | Hardcoded `0` (Active) | No `deleted_at` in SAC |
| 11 | — | — | `created_at` | timestamp without time zone | `NOW()` | Not in SAC |
| 12 | — | — | `updated_at` | timestamp without time zone | `NOW()` | Not in SAC |
| 13 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC |
| 14 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | |
| 15 | — | — | `level` | numeric | Hardcoded `0` | |


## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Departments ID Mapping
**Purpose**: Note: No duplicate UUID check needed as source table does not have identifier/uuid column
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='departments'`

```sql
CREATE TEMP TABLE departments_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'departments'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/designations_migration.sql`

## Validation

- Run `05-validation/master/designations_validation.sql` if available
- Run `06-rollback/master/designations_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
