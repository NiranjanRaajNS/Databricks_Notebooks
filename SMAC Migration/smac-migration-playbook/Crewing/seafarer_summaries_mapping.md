# Table Mapping: seafarer_summaries → seafarer_summaries

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_summaries
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_summaries
- **Source Script**: `04-migration-scripts/crewing/seafarer_summaries_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_summaries`
- **New Path**: `smac_crewing_migration.shore.seafarer_summaries`

## Business Key

- **Business Key**: `seafarer_id`
- **Source (orchestration)**: Seafarer Summaries (`seafarer_summaries` → `seafarer_summaries`)

## Migration Notes

- Target uses uuid for id column (new UUIDs generated, legacy id stored in audit_info)
- Migrates seafarer_summaries table. Maps seafarer_id (bigint) to seafarer_id (uuid) via migration.table_mappings from current database (smac_crewing_migration). Ensures JSONB fields (section_summary, internal_document_summary) are not NULL with default '{}'. Adds new required fields: overall_completeness_percentage (default 0.0), status (default 'Active'), tenant_id. Target uses IDENTITY for id generation (new IDs generated, legacy id stored in audit_info). Only migrates records where seafarer_id can be mapped.

## Special Considerations

- Maps seafarer_id via migration.table_mappings from current database (smac_crewing_migration)
- Script performs `TRUNCATE TABLE shore.seafarer_summaries` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | Check if | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarers_id_mapping`

- **Purpose**: Check if
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
| 2 | derived | - | seafarer_id | - | COALESCE(seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as seafarer_id | COALESCE(seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | section_summary | - | section_summary | - | pg_temp.transform_json_array_to_object(legacy_data.section_summary, '{}'::jsonb) as section_summary | pg_temp.transform_json_array_to_object(legacy_data.section_summary, '{}'::jsonb) |
| 4 | derived | - | overall_completeness_percentage | - | 0.0::numeric(5,2) as overall_completeness_percentage | 0.0::numeric(5,2) |
| 5 | is_complete | - | is_complete | - | COALESCE(legacy_data.is_complete, false) as is_complete | COALESCE(legacy_data.is_complete, false) |
| 6 | authentication_summary | - | authentication_summary | - | pg_temp.transform_json_array_to_object(legacy_data.authentication_summary, NULL::jsonb) as authentication_summary | pg_temp.transform_json_array_to_object(legacy_data.authentication_summary, NULL::jsonb) |
| 7 | internal_document_summary | - | internal_document_summary | - | pg_temp.transform_json_array_to_object(legacy_data.internal_document_summary, '{}'::jsonb) as internal_document_summary | pg_temp.transform_json_array_to_object(legacy_data.internal_document_summary, '{}'::jsonb) |
| 8 | expiring_document_summary | - | expiring_document_summary | - | pg_temp.transform_json_array_to_object(legacy_data.expiring_document_summary, NULL::jsonb) as expiring_document_summary | pg_temp.transform_json_array_to_object(legacy_data.expiring_document_summary, NULL::jsonb) |
| 9 | derived | - | status | - | 'Active' as status | 'Active' |
| 10 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 13 | - | - | archived_at | - | NULL | NULL::timestamp |
| 14 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 15 | created_by_id, updated_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Purpose**: Check if
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

Full migration context: `04-migration-scripts/crewing/seafarer_summaries_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_summaries_validation.sql` if available
- Run `06-rollback/crewing/seafarer_summaries_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
