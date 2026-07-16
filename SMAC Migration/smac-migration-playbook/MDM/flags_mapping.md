# Table Mapping: flags → flags

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: flags
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: flags
- **Source Script**: `04-migration-scripts/master/flags_migration.sql`

- **Legacy Path**: `synergy_vessel.public.flags`
- **New Path**: `smac_master_migration.public.flags`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Flags (`flags` → `flags`)

## Migration Notes

- Preserve legacy identifier (UUID) as id
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Script performs `TRUNCATE TABLE public.flags` before insert (full table reload).
- Orchestration dependencies: `countries`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `country_id_mapping` | FK lookup | `legacy_id`, `new_id`, `iso_code` | `migration.table_mappings` (see SQL) | - |

### `country_id_mapping`

- **Output columns**: legacy_id, new_id, iso_code
- **migration.table_mappings**: target_table=countries

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    tm.source_id::bigint AS legacy_id,
    tm.target_id AS new_id,
    c.iso_code AS iso_code
FROM migration.table_mappings tm
JOIN public.countries c ON c.id = tm.target_id
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | source_id, source_identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'flags'::VARCHAR(100), s.source_id::text, current_database()::text::VARCHAR(100), 'public'::... |
| 2 | flag_name, source_identifier | - | code | - | generate_meaningful_code() | COALESCE( NULLIF(TRIM(cm.iso_code), ''), generate_meaningful_code(TRIM(s.flag_name), s.source_identifier::text) ) |
| 3 | flag_name | - | name | - | COALESCE(s.flag_name, 'UNKNOWN') AS name | COALESCE(s.flag_name, 'UNKNOWN') |
| 4 | description | - | description | - | TRIM(s.description) AS description | TRIM(s.description) |
| 5 | derived | - | country_id | - | cm.new_id AS country_id | cm.new_id |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | parent_id | - | NULL AS parent_id | NULL |
| 8 | derived | - | version | - | 1 AS version | 1 |
| 9 | created_at | - | created_at | - | COALESCE(s.created_at, NOW()) AS created_at | COALESCE(s.created_at, NOW()) |
| 10 | updated_at | - | updated_at | - | COALESCE(s.updated_at, NOW()) AS updated_at | COALESCE(s.updated_at, NOW()) |
| 11 | deleted_at | - | deleted_at | - | s.deleted_at AS deleted_at | s.deleted_at |
| 12 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 13 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( s.created_by_id::varchar, NULL::varchar, s.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::va... |
| 14 | derived | - | level | - | 0 AS level | 0 |
| 15 | derived | - | tags | - | ARRAY[]::text[] AS tags | ARRAY[]::text[] |
| 16 | deleted_at | - | status | - | CASE WHEN s.deleted_at IS NOT NULL THEN 3 ELSE 0 END AS status | CASE WHEN s.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 17 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 18 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Country ID Mapping
**Output columns**: `legacy_id, new_id, iso_code`
**migration.table_mappings**: `target_table='countries'`

```sql
CREATE TEMP TABLE country_id_mapping AS
SELECT
    tm.source_id::bigint AS legacy_id,
    tm.target_id AS new_id,
    c.iso_code AS iso_code
FROM migration.table_mappings tm
JOIN public.countries c ON c.id = tm.target_id
WHERE tm.target_table = 'countries'
  AND tm.target_db = current_database();
```

Full migration context: `04-migration-scripts/master/flags_migration.sql`

## Validation

- Run `05-validation/master/flags_validation.sql` if available
- Run `06-rollback/master/flags_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
