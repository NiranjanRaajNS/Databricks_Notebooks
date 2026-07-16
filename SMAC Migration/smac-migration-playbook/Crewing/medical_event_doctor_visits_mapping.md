# Table Mapping: medical_events → medical_event_doctor_visits

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: medical_events
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: medical_event_doctor_visits
- **Source Script**: `04-migration-scripts/crewing/medical_event_doctor_visits_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.medical_events`
- **New Path**: `smac_crewing_migration.public.medical_event_doctor_visits`

## Business Key

- **Business Key**: `medical_event_id`
- **Source (orchestration)**: Medical Events (`medical_events` → `medical_event_doctor_visits`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Creates one record per medical_event. Maps medical_event_id and seafarer_id via migration.table_mappings. Uses medical_event_date as consultation_date and description as doctor_remarks. Uses standardized SMAC audit_info structure.

## Special Considerations

- Script performs `TRUNCATE TABLE public.medical_event_doctor_visits` before insert (full table reload).
- Orchestration dependencies: `medical_events`, `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `medical_event_id_mapping` | FK lookup | `legacy_id`, `new_id` | - | - |
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `medical_event_id_mapping`

- **Output columns**: legacy_id, new_id

```sql
CREATE TEMP TABLE medical_event_id_mapping AS
SELECT
    id as legacy_id,
    id as new_id
FROM public.medical_events;
```

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::uuid AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'medical_events'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(10... |
| 2 | derived | - | medical_event_id | - | event_map.new_id AS medical_event_id | event_map.new_id |
| 3 | derived | - | consultation_place_id | - | NULL AS consultation_place_id | NULL |
| 4 | derived | - | consultation_place_name | - | NULL AS consultation_place_name | NULL |
| 5 | medical_event_date | - | consultation_date | - | legacy_data.medical_event_date::date AS consultation_date | legacy_data.medical_event_date::date |
| 6 | derived | - | hospital_remarks | - | NULL AS hospital_remarks | NULL |
| 7 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'Deleted'::varchar(50) ELSE 'Active'::varchar(50) END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'Deleted'::varchar(50) ELSE 'Active'::varchar(50) END |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 10 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 11 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 12 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 13 | audit_info | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info->>'created_by' IS NOT NULL AND legacy_data.audit_info->>'created_by' <> '' TH... |
| 14 | derived | - | seafarer_id | - | seafarer_map.new_id AS seafarer_id | seafarer_map.new_id |
| 15 | derived | - | alternate_consultation_place | - | NULL AS alternate_consultation_place | NULL |
| 16 | derived | - | doctor_name | - | NULL AS doctor_name | NULL |
| 17 | description | - | doctor_remarks | - | legacy_data.description AS doctor_remarks | legacy_data.description |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Medical Event ID Mapping
**Output columns**: `legacy_id, new_id`

```sql
CREATE TEMP TABLE medical_event_id_mapping AS
SELECT
    id as legacy_id,
    id as new_id
FROM public.medical_events;
```

### 2. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::uuid AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

Full migration context: `04-migration-scripts/crewing/medical_event_doctor_visits_migration.sql`

## Validation

- Run `05-validation/crewing/medical_event_doctor_visits_validation.sql` if available
- Run `06-rollback/crewing/medical_event_doctor_visits_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
