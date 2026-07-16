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

- Migrates seafarer_availability_log to seafarer_availability_logs table. Preserves legacy UUID id. Maps seafarer_id (uuid) to uuid via migration.table_mappings. Maps remarks_id (bigint) to uuid via migration.table_mappings. Sets default values for availability_status ('Available') and status ('Active'). Requires seafarers table to be migrated first.

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
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_availability_log'::VARCHAR(100), legacy_data.id::text, current_database()::text:... |
| 2 | derived | - | seafarer_id | - | seafarer_map.new_id AS seafarer_id | seafarer_map.new_id |
| 3 | availability_date | - | availability_date | - | legacy_data.availability_date | legacy_data.availability_date |
| 4 | derived | - | availability_status | - | 'available'::varchar(50) as availability_status | 'available'::varchar(50) |
| 5 | derived | - | remarks_id | - | remarks_map.new_id AS remarks_id | remarks_map.new_id |
| 6 | other_remarks | - | other_remarks | - | TRIM(legacy_data.other_remarks) as other_remarks | TRIM(legacy_data.other_remarks) |
| 7 | source | - | source | - | LEFT(TRIM(legacy_data.source), 50)::varchar(50) as source | LEFT(TRIM(legacy_data.source), 50)::varchar(50) |
| 8 | is_latest | - | is_latest | - | COALESCE(legacy_data.is_latest, true) as is_latest | COALESCE(legacy_data.is_latest, true) |
| 9 | is_edited | - | is_edited | - | COALESCE(legacy_data.is_edited, false) as is_edited | COALESCE(legacy_data.is_edited, false) |
| 10 | derived | - | edit_reason | - | NULL as edit_reason | NULL |
| 11 | derived | - | related_entity | - | NULL as related_entity | NULL |
| 12 | derived | - | related_entity_id | - | NULL as related_entity_id | NULL |
| 13 | derived | - | status | - | 'active'::text as status | 'active'::text |
| 14 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 15 | updated_at | - | created_at | - | COALESCE(legacy_data.updated_at, NOW()) as created_at | COALESCE(legacy_data.updated_at, NOW()) |
| 16 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 17 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 18 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 19 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, au.audit_user_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL:... |
| 20 | derived | - | vessel_revision_id | - | NULL as vessel_revision_id | NULL |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
