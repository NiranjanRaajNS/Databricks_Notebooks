# Table Mapping: vessel_ecdis_info → vessel_ecdis_types

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_ecdis_info
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_ecdis_types
- **Source Script**: `04-migration-scripts/master/vessel_ecdis_types_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_ecdis_info`
- **New Path**: `smac_master_migration.vessel.vessel_ecdis_types`

## Business Key

- **Composite Key**: (`vessel_id`, `ecdis_type_id`)
- **Source (orchestration)**: Vessel Ecdis Info (`vessel_ecdis_info` → `vessel_ecdis_types`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates vessel_ecdis_info preserving identifier UUID as id if available. Maps vessel_id through vessel_details â†’ migration.table_mappings

## Special Considerations

- Map status: legacy vessel_ecdis_info has no status column; use deleted_at only (Rule 2.2.1: deleted_at takes precedence)
- Script performs `TRUNCATE TABLE vessel.vessel_ecdis_types` before insert (full table reload).
- Orchestration dependencies: `vessels`, `ecdis_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `vessel_details_id`, `vessel_legacy_id`, `vessel_details_identifier`, `new_vessel_id` | `migration.table_mappings` (see SQL) | `synergy_vessel` |
| `vessel_revision_id_mapping` | Drop t | `legacy_identifier_text`, `new_vessel_revision_id` | `migration.table_mappings` (see SQL) | - |
| `ecdis_type_id_mapping` | Create lookup | `legacy_ecdis_type_id`, `new_ecdis_type_id` | `migration.table_mappings` (see SQL) | - |

### `vessel_id_mapping`

- **Output columns**: vessel_details_id, vessel_legacy_id, vessel_details_identifier, new_vessel_id
- **migration.table_mappings**: target_table=vessels
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.id AS vessel_details_id,
    vd.vessel_id AS vessel_legacy_id,
    vd.identifier AS vessel_details_identifier,
    tm_vessel.target_id::uuid AS new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, vessel_id, identifier
     FROM public.vessel_details
     WHERE id IN (SELECT DISTINCT vessel_id FROM public.vessel_ecdis_info)'
) AS vd(id bigint, vessel_id bigint, identifier uuid)
LEFT JOIN migration.table_mappings tm_vessel
    ON tm_vessel.target_table = 'vessels'
   AND tm_vessel.target_db = current_database()
   AND tm_vessel.source_id = vd.vessel_id::text;
```

### `vessel_revision_id_mapping`

- **Purpose**: Drop t
- **Output columns**: legacy_identifier_text, new_vessel_revision_id
- **migration.table_mappings**: target_table=vessel_revisions

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (tm.source_id)
    tm.source_id AS legacy_identifier_text,
    tm.target_id::uuid AS new_vessel_revision_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'vessel_revisions'
  AND tm.target_db = current_database()
ORDER BY tm.source_id, tm.target_id;
```

### `ecdis_type_id_mapping`

- **Purpose**: Create lookup
- **Output columns**: legacy_ecdis_type_id, new_ecdis_type_id
- **migration.table_mappings**: target_table=ecdis_types

```sql
CREATE TEMP TABLE ecdis_type_id_mapping AS
SELECT
    source_id::bigint as legacy_ecdis_type_id,
    target_id::uuid as new_ecdis_type_id
FROM migration.table_mappings
WHERE target_table = 'ecdis_types'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.id) migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_ecdis_info'::VARCHAR(100), legacy_data.id::text, curren... |
| 2 | derived | - | vessel_id | - | COALESCE(vim.new_vessel_id, '00000000-0000-0000-0000-000000000000'::uuid) AS vessel_id | COALESCE(vim.new_vessel_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | vessel_revision_id | - | vrev.new_vessel_revision_id AS vessel_revision_id | vrev.new_vessel_revision_id |
| 4 | derived | - | ecdis_type_id | - | COALESCE(etim.new_ecdis_type_id, '00000000-0000-0000-0000-000000000000'::uuid) AS ecdis_type_id | COALESCE(etim.new_ecdis_type_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 as version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 10 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 11 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 12 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Output columns**: `vessel_details_id, vessel_legacy_id, vessel_details_identifier, new_vessel_id`
**migration.table_mappings**: `target_table='vessels'`
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT DISTINCT
    vd.id AS vessel_details_id,
    vd.vessel_id AS vessel_legacy_id,
    vd.identifier AS vessel_details_identifier,
    tm_vessel.target_id::uuid AS new_vessel_id
FROM dblink('synergy_vessel',
    'SELECT id, vessel_id, identifier
     FROM public.vessel_details
     WHERE id IN (SELECT DISTINCT vessel_id FROM public.vessel_ecdis_info)'
) AS vd(id bigint, vessel_id bigint, identifier uuid)
LEFT JOIN migration.table_mappings tm_vessel
    ON tm_vessel.target_table = 'vessels'
   AND tm_vessel.target_db = current_database()
   AND tm_vessel.source_id = vd.vessel_id::text;
```

### 2. Vessel Revision ID Mapping
**Purpose**: Drop t
**Output columns**: `legacy_identifier_text, new_vessel_revision_id`
**migration.table_mappings**: `target_table='vessel_revisions'`

```sql
CREATE TEMP TABLE vessel_revision_id_mapping AS
SELECT DISTINCT ON (tm.source_id)
    tm.source_id AS legacy_identifier_text,
    tm.target_id::uuid AS new_vessel_revision_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'vessel_revisions'
  AND tm.target_db = current_database()
ORDER BY tm.source_id, tm.target_id;
```

### 3. Ecdis Type ID Mapping
**Purpose**: Create lookup
**Output columns**: `legacy_ecdis_type_id, new_ecdis_type_id`
**migration.table_mappings**: `target_table='ecdis_types'`

```sql
CREATE TEMP TABLE ecdis_type_id_mapping AS
SELECT
    source_id::bigint as legacy_ecdis_type_id,
    target_id::uuid as new_ecdis_type_id
FROM migration.table_mappings
WHERE target_table = 'ecdis_types'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/master/vessel_ecdis_types_migration.sql`

## Validation

- Run `05-validation/master/vessel_ecdis_types_validation.sql` if available
- Run `06-rollback/master/vessel_ecdis_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
