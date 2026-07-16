# Table Mapping: seafarer_profile_remarks → seafarer_profile_section_statuses

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_profile_remarks
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_profile_section_statuses
- **Source Script**: `04-migration-scripts/crewing/seafarer_profile_section_statuses_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_profile_remarks`
- **New Path**: `smac_crewing_migration.public.seafarer_profile_section_statuses`

## Business Key

- **Business Key**: `section_code`
- **Source (orchestration)**: Seafarer Profile Remarks (`seafarer_profile_remarks` → `seafarer_profile_section_statuses`)

## Migration Notes

- Generates new UUIDs for id (no identifier/uuid in source)
- Migrates seafarer_profile_remarks to seafarer_profile_section_statuses table. Generates new UUIDs for id column (no identifier/uuid in source). Maps name to section_code, type to status. Source table does not have seafarer_id, so it will be set to NULL (may need manual update). Sets defaults for new fields: completed_fields (0), total_fields (0), completion_pct (0.0). Stores description in audit_info for reference.

## Special Considerations

- Source table does not have seafarer_id, so it will be set to NULL
- Script performs `TRUNCATE TABLE public.seafarer_profile_section_statuses` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarers_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | gen_random_uuid() as id | gen_random_uuid() |
| 2 | derived | - | seafarer_id | - | '00000000-0000-0000-0000-000000000000'::uuid as seafarer_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 3 | name | - | section_code | - | CASE WHEN legacy_data.name IS NOT NULL AND TRIM(legacy_data.name) != '' THEN TRIM(legacy_data.name) ELSE NULL END as section_code | CASE WHEN legacy_data.name IS NOT NULL AND TRIM(legacy_data.name) != '' THEN TRIM(legacy_data.name) ELSE NULL END |
| 4 | type | - | status | - | CASE WHEN legacy_data.type IS NOT NULL AND TRIM(legacy_data.type) != '' THEN TRIM(legacy_data.type) ELSE NULL END as status | CASE WHEN legacy_data.type IS NOT NULL AND TRIM(legacy_data.type) != '' THEN TRIM(legacy_data.type) ELSE NULL END |
| 5 | derived | - | completed_fields | - | 0 as completed_fields | 0 |
| 6 | derived | - | total_fields | - | 0 as total_fields | 0 |
| 7 | derived | - | completion_pct | - | 0.0::numeric as completion_pct | 0.0::numeric |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 10 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 11 | - | - | archived_at | - | NULL | NULL::timestamp |
| 12 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 13 | created_by_id, updated_by_id, id | - | audit_info | - | jsonb_build_object( 'created_by', CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END, '... | jsonb_build_object( 'created_by', CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END, '... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_profile_section_statuses_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_profile_section_statuses_validation.sql` if available
- Run `06-rollback/crewing/seafarer_profile_section_statuses_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
