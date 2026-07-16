# Table Mapping: vessel_onboarding_statuses → contract_manual_upload_settings

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: vessel_onboarding_statuses
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: contract_manual_upload_settings
- **Source Script**: `04-migration-scripts/master/contract_manual_upload_settings_migration.sql`

- **Legacy Path**: `synergy_master.public.vessel_onboarding_statuses`
- **New Path**: `smac_master_migration.crewing.contract_manual_upload_settings`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Contract Manual Upload Settings (`vessel_onboarding_statuses` → `contract_manual_upload_settings`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates vessel_onboarding_statuses to contract_manual_upload_settings. Uses idempotent UUID resolution via migration.resolve_target_id() since source table has no UUID column.

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.contract_manual_upload_settings` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessels_id_mapping` | Check for duplicate UUIDs in source table | `legacy_id`, `new_vessel_id` | `migration.table_mappings` (see SQL) | - |
| `positions_id_mapping` | Clear existing data fr | `legacy_position_id`, `new_position_id` | `migration.table_mappings` (see SQL) | - |

### `vessels_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: legacy_id, new_vessel_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::text AS legacy_id,
    target_id AS new_vessel_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### `positions_id_mapping`

- **Purpose**: Clear existing data fr
- **Output columns**: legacy_position_id, new_position_id
- **migration.table_mappings**: target_table=positions

```sql
CREATE TEMP TABLE positions_id_mapping AS
SELECT
    source_id::text AS legacy_position_id,
    target_id AS new_position_id
FROM migration.table_mappings
WHERE target_table = 'positions'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_onboarding_statuses'::VARCHAR(100), legacy_data.id::text, current_database()::text::... |
| 2 | derived | - | vessel_id | - | vm.new_vessel_id as vessel_id | vm.new_vessel_id |
| 3 | derived | - | vessel_revision_id | - | '00000000-0000-0000-0000-000000000000'::uuid as vessel_revision_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 4 | contract_manual_upload | - | manual_upload_enabled | - | CASE WHEN legacy_data.contract_manual_upload IS NOT NULL AND legacy_data.contract_manual_upload->>'enable' = 'true' THEN true ELSE false END as manual_upload_enabled | CASE WHEN legacy_data.contract_manual_upload IS NOT NULL AND legacy_data.contract_manual_upload->>'enable' = 'true' THEN true ELSE false END |
| 5 | contract_manual_upload | - | rules | - | COALESCE( ( SELECT jsonb_agg( jsonb_build_object( 'positions', COALESCE( ( SELECT jsonb_agg(pm.new_position_id::text ORDER BY pm.new_position_id) FROM jsonb_array_elements( CASE... | COALESCE( ( SELECT jsonb_agg( jsonb_build_object( 'positions', COALESCE( ( SELECT jsonb_agg(pm.new_position_id::text ORDER BY pm.new_position_id) FROM jsonb_array_elements( CASE... |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | - | - | parent_id | - | NULL | NULL::uuid |
| 8 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 9 | derived | - | version | - | 1 as version | 1 |
| 10 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 11 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 12 | derived | - | status | - | 0 as status | 0 |
| 13 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 14 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 15 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 16 | - | - | archived_at | - | NULL | NULL::timestamp |
| 17 | id | - | audit_info | - | migration.build_audit_info() | jsonb_set( migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL:... |
| 18 | - | - | tags | - | NULL | NULL::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessels ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `legacy_id, new_vessel_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::text AS legacy_id,
    target_id AS new_vessel_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 2. Positions ID Mapping
**Purpose**: Clear existing data fr
**Output columns**: `legacy_position_id, new_position_id`
**migration.table_mappings**: `target_table='positions'`

```sql
CREATE TEMP TABLE positions_id_mapping AS
SELECT
    source_id::text AS legacy_position_id,
    target_id AS new_position_id
FROM migration.table_mappings
WHERE target_table = 'positions'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/contract_manual_upload_settings_migration.sql`

## Validation

- Run `05-validation/master/contract_manual_upload_settings_validation.sql` if available
- Run `06-rollback/master/contract_manual_upload_settings_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
