# Table Mapping: medical_expense_records → medical_expense_records

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: medical_expense_records
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: medical_expense_records
- **Source Script**: `04-migration-scripts/crewing/medical_expense_records_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.medical_expense_records`
- **New Path**: `smac_crewing_migration.public.medical_expense_records`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Medical Expense Records (`medical_expense_records` → `medical_expense_records`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates medical_expense_records table. Preserves legacy UUID id directly. Maps seafarer_id and medical_event_id via migration.table_mappings. Uses standardized audit_info format. Requires seafarers and medical_events tables to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.medical_expense_records` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `medical_events`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | Check for duplicate UUIDs in source table | `seafarer_uuid`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `medical_events_id_mapping` | Clear existing dat | `medical_event_uuid`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarers_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
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

### `medical_events_id_mapping`

- **Purpose**: Clear existing dat
- **Output columns**: medical_event_uuid, new_id
- **migration.table_mappings**: target_table=medical_events

```sql
CREATE TEMP TABLE medical_events_id_mapping AS
SELECT
    target_id as medical_event_uuid,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'medical_events'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'medical_expense_records'::VARCHAR(100), legacy_data.id::text, current_database()::text::V... |
| 2 | derived | - | seafarer_id | - | seafarer_map.new_id AS seafarer_id | seafarer_map.new_id |
| 3 | derived | - | medical_event_id | - | event_map.new_id AS medical_event_id | event_map.new_id |
| 4 | claim_no | - | claim_no | - | legacy_data.claim_no AS claim_no | legacy_data.claim_no |
| 5 | voucher_no | - | voucher_no | - | legacy_data.voucher_no AS voucher_no | legacy_data.voucher_no |
| 6 | voucher_date | - | voucher_date | - | legacy_data.voucher_date AS voucher_date | legacy_data.voucher_date |
| 7 | incurred_at | - | incurred_at | - | legacy_data.incurred_at AS incurred_at | legacy_data.incurred_at |
| 8 | file_with_pi | - | file_with_pi | - | COALESCE(legacy_data.file_with_pi, false) AS file_with_pi | COALESCE(legacy_data.file_with_pi, false) |
| 9 | derived | - | amount | - | NULL AS amount | NULL |
| 10 | derived | - | currency_code | - | NULL AS currency_code | NULL |
| 11 | derived | - | status | - | 0 AS status | 0 |
| 12 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 13 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 14 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 15 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 16 | derived | - | deleted_at | - | NULL AS deleted_at | NULL |
| 17 | audit_info | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info->>'CreatedBy' IS NOT NULL AND legacy_data.audit_info->>'CreatedBy' <> '' THEN... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
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

### 2. Medical Events ID Mapping
**Purpose**: Clear existing dat
**Output columns**: `medical_event_uuid, new_id`
**migration.table_mappings**: `target_table='medical_events'`

```sql
CREATE TEMP TABLE medical_events_id_mapping AS
SELECT
    target_id as medical_event_uuid,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'medical_events'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/medical_expense_records_migration.sql`

## Validation

- Run `05-validation/crewing/medical_expense_records_validation.sql` if available
- Run `06-rollback/crewing/medical_expense_records_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
