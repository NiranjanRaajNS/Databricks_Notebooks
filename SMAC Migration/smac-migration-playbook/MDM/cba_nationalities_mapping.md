# Table Mapping: cba_nationalities → cba_nationalities

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: cba_nationalities
- **Source Script**: `04-migration-scripts/master/cba_nationalities_migration.sql`

- **Legacy Path**: `synergy_master.public.cbas.nationality (JSONB)`
- **New Path**: `smac_master_migration.crewing.cba_nationalities`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Nationalities (`nationalities` → `nationalities`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)

## Special Considerations

- Source table does not have identifier/uuid columns - generate new UUID for all records
- Script performs `TRUNCATE TABLE crewing.cba_nationalities` before insert (full table reload).
- Orchestration dependencies: `countries`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `cbas_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `nationalities_id_mapping` | Check if any mappings already | `normalized_code`, `nationality_id` | - | - |

### `cbas_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_schema=crewing, target_table=cbas

```sql
CREATE TEMP TABLE cbas_id_mapping AS
SELECT
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cbas'
  AND target_schema = 'crewing'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `nationalities_id_mapping`

- **Purpose**: Check if any mappings already
- **Output columns**: normalized_code, nationality_id

```sql
CREATE TEMP TABLE nationalities_id_mapping AS
SELECT
    UPPER(TRIM(COALESCE(n.code, ''))) as normalized_code,
    n.id as nationality_id
FROM public.nationalities n
WHERE TRIM(COALESCE(n.code, '')) <> '';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | DISTINCT ON (dc.cba_id_uuid, dc.nationality_uuid) migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'cbas'::VARCHAR(100), dc.cba_id::text || '... |
| 2 | derived | - | cba_id | - | dc.cba_id_uuid as cba_id | dc.cba_id_uuid |
| 3 | derived | - | nationality | - | dc.nationality_uuid as nationality | dc.nationality_uuid |
| 4 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 5 | derived | - | version | - | 1 as version | 1 |
| 6 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 7 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 8 | derived | - | status | - | CASE WHEN dc.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN dc.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 9 | derived | - | level | - | 0 as level | 0 |
| 10 | derived | - | created_at | - | COALESCE(dc.created_at, NOW()) as created_at | COALESCE(dc.created_at, NOW()) |
| 11 | derived | - | updated_at | - | COALESCE(dc.updated_at, NOW()) as updated_at | COALESCE(dc.updated_at, NOW()) |
| 12 | derived | - | deleted_at | - | dc.deleted_at as deleted_at | dc.deleted_at |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.cbas`
- `public.nationalities`

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
  AND target_schema = 'crewing'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Nationalities ID Mapping
**Purpose**: Check if any mappings already
**Output columns**: `normalized_code, nationality_id`

```sql
CREATE TEMP TABLE nationalities_id_mapping AS
SELECT
    UPPER(TRIM(COALESCE(n.code, ''))) as normalized_code,
    n.id as nationality_id
FROM public.nationalities n
WHERE TRIM(COALESCE(n.code, '')) <> '';
```

Full migration context: `04-migration-scripts/master/cba_nationalities_migration.sql`

## Validation

- Run `05-validation/master/cba_nationalities_validation.sql` if available
- Run `06-rollback/master/cba_nationalities_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
