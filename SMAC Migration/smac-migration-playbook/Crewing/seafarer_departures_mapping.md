# Table Mapping: seafarer_departures → seafarer_departures

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: seafarer_departures
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_departures
- **Source Script**: `04-migration-scripts/crewing/seafarer_departures_migration.sql`

- **Legacy Path**: `synergy_manning.public.seafarer_departures`
- **New Path**: `smac_crewing_migration.shore.seafarer_departures`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Departures (`seafarer_departures` → `seafarer_departures`)

## Migration Notes

- Migrates seafarer_departures. Uses migration.resolve_target_id() for idempotent UUID generation. Maps seafarer_id via seafarers mapping. Maps relief_id to assignment_id via seafarer_vessel_assignments. Casts seafarer_signed_at to actual_departure_date (date). Maps status (text) to progress_status. Sets status (integer) based on deleted_at (3=Deleted, 0=Active).

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_departures` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `seafarer_vessel_assignments`, `workflow_status`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `workflow_status_signed_mapping` | FK lookup | `workflow_status_id` | - | `smac_master_migration` |
| `workflow_status_inforce_mapping` | Query public.user_profiles from sma | `workflow_status_id` | - | `smac_master_migration` |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `workflow_status_signed_mapping`

- **Output columns**: workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_signed_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''SIGNED'' LIMIT 1'
) AS t(id uuid);
```

### `workflow_status_inforce_mapping`

- **Purpose**: Query public.user_profiles from sma
- **Output columns**: workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_inforce_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''INFORCE'' LIMIT 1'
) AS t(id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_departures'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHA... |
| 2 | derived | - | seafarer_id | - | seafarer_map.new_id AS seafarer_id | seafarer_map.new_id |
| 3 | derived | - | assignment_id | - | COALESCE(relief_summary.assignment_id, '00000000-0000-0000-0000-000000000000'::uuid) AS assignment_id | COALESCE(relief_summary.assignment_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 4 | - | - | planned_departure_date | - | NULL | NULL::date |
| 5 | shore_user_signed_at | - | actual_departure_date | - | CASE WHEN legacy_data.shore_user_signed_at IS NOT NULL THEN legacy_data.shore_user_signed_at::date ELSE NULL END AS actual_departure_date | CASE WHEN legacy_data.shore_user_signed_at IS NOT NULL THEN legacy_data.shore_user_signed_at::date ELSE NULL END |
| 6 | - | - | departure_report | - | NULL | NULL::uuid[] |
| 7 | status | - | progress_status | - | TRIM(legacy_data.status) AS progress_status | TRIM(legacy_data.status) |
| 8 | status | - | workflow_status_id | - | CASE WHEN LOWER(TRIM(legacy_data.status)) IN ('signed', 'checklist_verified') THEN COALESCE(workflow_status_signed_map.workflow_status_id, '00000000-0000-0000-0000-000000000000'... | CASE WHEN LOWER(TRIM(legacy_data.status)) IN ('signed', 'checklist_verified') THEN COALESCE(workflow_status_signed_map.workflow_status_id, '00000000-0000-0000-0000-000000000000'... |
| 9 | shore_user_signed_at, status | - | is_verified | - | CASE WHEN legacy_data.shore_user_signed_at IS NOT NULL AND UPPER(TRIM(legacy_data.status)) = 'SIGNED' THEN true ELSE false END AS is_verified | CASE WHEN legacy_data.shore_user_signed_at IS NOT NULL AND UPPER(TRIM(legacy_data.status)) = 'SIGNED' THEN true ELSE false END |
| 10 | shore_user_signed_at | - | verified_at | - | legacy_data.shore_user_signed_at AS verified_at | legacy_data.shore_user_signed_at |
| 11 | shore_user_id | - | verified_by_id | - | COALESCE( user_profile_map.user_id, CASE WHEN legacy_data.shore_user_id IS NOT NULL AND TRIM(legacy_data.shore_user_id) <> '' AND legacy_data.shore_user_id ~ '^[0-9a-f]{8}-[0-9a... | COALESCE( user_profile_map.user_id, CASE WHEN legacy_data.shore_user_id IS NOT NULL AND TRIM(legacy_data.shore_user_id) <> '' AND legacy_data.shore_user_id ~ '^[0-9a-f]{8}-[0-9a... |
| 12 | - | - | verification_notes | - | NULL | NULL::text |
| 13 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 14 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 15 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 16 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 17 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 18 | - | - | archived_at | - | NULL | NULL::timestamp |
| 19 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, ... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Workflow Status Signed ID Mapping
**Output columns**: `workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_signed_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''SIGNED'' LIMIT 1'
) AS t(id uuid);
```

### 3. Workflow Status Inforce ID Mapping
**Purpose**: Query public.user_profiles from sma
**Output columns**: `workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_inforce_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''INFORCE'' LIMIT 1'
) AS t(id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_departures_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_departures_validation.sql` if available
- Run `06-rollback/crewing/seafarer_departures_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
