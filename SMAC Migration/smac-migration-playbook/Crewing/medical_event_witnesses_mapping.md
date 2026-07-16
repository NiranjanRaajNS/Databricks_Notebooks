# Table Mapping: medical_events → medical_event_witnesses

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: medical_events
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: medical_event_witnesses
- **Source Script**: `04-migration-scripts/crewing/medical_event_witnesses_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.medical_events`
- **New Path**: `smac_crewing_migration.public.medical_event_witnesses`

## Business Key

- **Composite Key**: (`medical_event_id`, `name`)
- **Source (orchestration)**: Medical Events (`medical_events` → `medical_event_witnesses`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Extracts witness details from witness_details JSONB array field. Creates one record per witness object in the array. Uses WITH ORDINALITY to ensure uniqueness. Maps medical_event_id via migration.table_mappings. Extracts name, role, contact, statement from JSONB. Uses standardized SMAC audit_info structure.

## Special Considerations

- Script performs `TRUNCATE TABLE public.medical_event_witnesses` before insert (full table reload).
- Orchestration dependencies: `medical_events`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `medical_event_id_mapping` | FK lookup | `legacy_id`, `new_id` | - | - |

### `medical_event_id_mapping`

- **Output columns**: legacy_id, new_id

```sql
CREATE TEMP TABLE medical_event_id_mapping AS
SELECT
    id as legacy_id,
    id as new_id
FROM public.medical_events;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'medical_events'::VARCHAR(100), LEFT(legacy_data.id::text || '|' || witness_obj.ordinality... |
| 2 | derived | - | medical_event_id | - | event_map.new_id AS medical_event_id | event_map.new_id |
| 3 | derived | - | name | - | COALESCE( witness_obj.witness_json->>'name', witness_obj.witness_json->>'Name', witness_obj.witness_json->>'witness_name', '' ) AS name | COALESCE( witness_obj.witness_json->>'name', witness_obj.witness_json->>'Name', witness_obj.witness_json->>'witness_name', '' ) |
| 4 | derived | - | role | - | COALESCE( witness_obj.witness_json->>'role', witness_obj.witness_json->>'Role', witness_obj.witness_json->>'witness_role', NULL ) AS role | COALESCE( witness_obj.witness_json->>'role', witness_obj.witness_json->>'Role', witness_obj.witness_json->>'witness_role', NULL ) |
| 5 | derived | - | contact | - | COALESCE( witness_obj.witness_json->>'contact', witness_obj.witness_json->>'Contact', witness_obj.witness_json->>'witness_contact', witness_obj.witness_json->>'phone', witness_o... | COALESCE( witness_obj.witness_json->>'contact', witness_obj.witness_json->>'Contact', witness_obj.witness_json->>'witness_contact', witness_obj.witness_json->>'phone', witness_o... |
| 6 | derived | - | statement | - | COALESCE( witness_obj.witness_json->>'statement', witness_obj.witness_json->>'Statement', witness_obj.witness_json->>'witness_statement', witness_obj.witness_json->>'remarks', N... | COALESCE( witness_obj.witness_json->>'statement', witness_obj.witness_json->>'Statement', witness_obj.witness_json->>'witness_statement', witness_obj.witness_json->>'remarks', N... |
| 7 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'Deleted'::varchar(50) ELSE 'Active'::varchar(50) END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'Deleted'::varchar(50) ELSE 'Active'::varchar(50) END |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 10 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 11 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 12 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 13 | audit_info | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info->>'created_by' IS NOT NULL AND legacy_data.audit_info->>'created_by' <> '' TH... |

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

Full migration context: `04-migration-scripts/crewing/medical_event_witnesses_migration.sql`

## Validation

- Run `05-validation/crewing/medical_event_witnesses_validation.sql` if available
- Run `06-rollback/crewing/medical_event_witnesses_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
