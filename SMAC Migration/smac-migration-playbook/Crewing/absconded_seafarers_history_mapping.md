# Table Mapping: absconded_seafarers_history → absconded_seafarers_history

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: absconded_seafarers_history
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: absconded_seafarers_history
- **Source Script**: `04-migration-scripts/crewing/absconded_seafarers_history_migration.sql`

- **Legacy Path**: `synergy_manning.public.absconded_seafarers_history`
- **New Path**: `smac_crewing_migration.public.absconded_seafarers_history`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Absconded Seafarers History (`absconded_seafarers_history` → `absconded_seafarers_history`)

## Migration Notes

- Migrates absconded_seafarers_history preserving UUID id. Maps relief_id to assignment_id via seafarer_vessel_assignments mapping. Maps signoff_reason_id via signoff_reasons master table.

## Special Considerations

- Script performs `TRUNCATE TABLE public.absconded_seafarers_history` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `seafarer_vessel_assignments`, `signoff_reasons`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `assignment_id_mapping` | FK lookup | `legacy_relief_id`, `assignment_id` | `migration.table_mappings` (see SQL) | - |
| `signoff_reason_id_mapping` | FK lookup | `legacy_reason_id`, `sign_off_reason_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

### `assignment_id_mapping`

- **Output columns**: legacy_relief_id, assignment_id
- **migration.table_mappings**: target_table=seafarer_vessel_assignments

```sql
CREATE TEMP TABLE assignment_id_mapping AS
SELECT
    source_id::bigint AS legacy_relief_id,
    target_id AS assignment_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_vessel_assignments'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `signoff_reason_id_mapping`

- **Output columns**: legacy_reason_id, sign_off_reason_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE signoff_reason_id_mapping AS
SELECT
    source_id::bigint AS legacy_reason_id,
    target_id AS sign_off_reason_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''sign_off_reasons'' AND target_db = current_database() AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'absconded_seafarers_history'::VARCHAR(100), legacy_data.id::text, current_database()::text... |
| 2 | seafarer_uuid | - | seafarer_id | - | legacy_data.seafarer_uuid AS seafarer_id | legacy_data.seafarer_uuid |
| 3 | derived | - | assignment_id | - | COALESCE( assignment_map.assignment_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS assignment_id | COALESCE( assignment_map.assignment_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 4 | derived | - | sign_off_reason_id | - | COALESCE( signoff_reason_map.sign_off_reason_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS sign_off_reason_id | COALESCE( signoff_reason_map.sign_off_reason_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 5 | investigation_remarks | - | investigation_remarks | - | TRIM(legacy_data.investigation_remarks) AS investigation_remarks | TRIM(legacy_data.investigation_remarks) |
| 6 | closure_date | - | closure_date | - | legacy_data.closure_date AS closure_date | legacy_data.closure_date |
| 7 | is_seafarer_deactivation_required | - | is_seafarer_deactivation_required | - | legacy_data.is_seafarer_deactivation_required AS is_seafarer_deactivation_required | legacy_data.is_seafarer_deactivation_required |
| 8 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'Deleted'::text WHEN legacy_data.status IS NULL THEN 'Active'::text WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(leg... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 'Deleted'::text WHEN legacy_data.status IS NULL THEN 'Active'::text WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(leg... |
| 9 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 10 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 11 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 12 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 13 | created_by_id, deleted_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, legacy_data.deleted_by_id::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::times... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Assignment ID Mapping
**Output columns**: `legacy_relief_id, assignment_id`
**migration.table_mappings**: `target_table='seafarer_vessel_assignments'`

```sql
CREATE TEMP TABLE assignment_id_mapping AS
SELECT
    source_id::bigint AS legacy_relief_id,
    target_id AS assignment_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_vessel_assignments'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Signoff Reason ID Mapping
**Output columns**: `legacy_reason_id, sign_off_reason_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE signoff_reason_id_mapping AS
SELECT
    source_id::bigint AS legacy_reason_id,
    target_id AS sign_off_reason_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''sign_off_reasons'' AND target_db = current_database() AND source_id ~ ''^[0-9]+$'''
) AS t(source_id text, target_id uuid)
WHERE source_id IS NOT NULL AND target_id IS NOT NULL;
```

Full migration context: `04-migration-scripts/crewing/absconded_seafarers_history_migration.sql`

## Validation

- Run `05-validation/crewing/absconded_seafarers_history_validation.sql` if available
- Run `06-rollback/crewing/absconded_seafarers_history_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
