# Table Mapping: sea_experience_summary → seafarer_operator_experience

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: sea_experience_summary
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_operator_experience
- **Source Script**: `04-migration-scripts/crewing/seafarer_operator_experience_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.sea_experience_summary`
- **New Path**: `smac_crewing_migration.public.seafarer_operator_experience`

## Business Key

- **Business Key**: `seafarer_id`
- **Source (orchestration)**: Sea Experience Summary (`sea_experience_summary` → `seafarer_operator_experience`)

## Migration Notes

- Migrates sea_experience_summary to seafarer_operator_experience. Preserves source UUID (id column) as target id using migration.resolve_target_id(). Column mappings: operator_experience (numeric) → operator_experience_in_days (integer), is_last_synergy_experience → is_last_experience_inhouse. Maps seafarer_id (bigint) to seafarer_id (uuid) via migration.table_mappings. Status defaults to 'Active' for all records. Uses migration.build_audit_info() for standardized audit_info structure.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_operator_experience` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | Delete mappings from migration.table_mappings | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_id_mapping`

- **Purpose**: Delete mappings from migration.table_mappings
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.id) migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'sea_experience_summary'::VARCHAR(100), legacy_data.id::text,... |
| 2 | derived | - | seafarer_id | - | COALESCE( seafarer_id_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS seafarer_id | COALESCE( seafarer_id_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 3 | operator_experience | - | operator_experience_in_days | - | COALESCE(legacy_data.operator_experience::integer, 0) as operator_experience_in_days | COALESCE(legacy_data.operator_experience::integer, 0) |
| 4 | is_last_synergy_experience | - | is_last_experience_inhouse | - | COALESCE(legacy_data.is_last_synergy_experience, false) as is_last_experience_inhouse | COALESCE(legacy_data.is_last_synergy_experience, false) |
| 5 | derived | - | status | - | 'Active'::text as status | 'Active'::text |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 8 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 9 | - | - | archived_at | - | NULL | NULL::timestamp |
| 10 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 11 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Purpose**: Delete mappings from migration.table_mappings
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_operator_experience_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_operator_experience_validation.sql` if available
- Run `06-rollback/crewing/seafarer_operator_experience_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
