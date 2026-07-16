# Table Mapping: vessel_details (union_code text[]) → vessel_revision_unions

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_details (union_code text[])
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_revision_unions
- **Source Script**: `04-migration-scripts/master/vessel_revision_unions_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_details (union_code text[])`
- **New Path**: `smac_master_migration.vessel.vessel_revision_unions`

## Business Key

- **Composite Key**: (`vim.new_vessel_id`, `vd.identifier`, `mucl.maritime_union_id`)

## Migration Notes

- Maps vessel_revision_id from vessel_details.identifier (UUID) directly
- Maps maritime_union_id from union_code (text) to public.maritime_unions.code (case-insensitive)
- Maps vessel_id from vessel_details.vessel_id (bigint) to vessel.vessels.id (uuid) via migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessel.vessel_revisions, vessel.vessels, and public.maritime_unions to be migrated first

## Special Considerations

- Uses migration.resolve_target_id() for idempotent UUID generation (unpivot operation - uses composite source_id)
- Unpivots union_code array from vessel_details into individual vessel_revision_unions records
- Use DISTINCT ON (source_id) to prevent duplicate mappings
- Script performs `TRUNCATE TABLE vessel.vessel_revision_unions` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `legacy_vessel_id`, `new_vessel_id` | `migration.table_mappings` (see SQL) | - |
| `maritime_union_code_lookup` | FK lookup | `mu.code`, `maritime_union_id` | - | - |

### `vessel_id_mapping`

- **Output columns**: legacy_vessel_id, new_vessel_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_vessel_id,
    target_id AS new_vessel_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### `maritime_union_code_lookup`

- **Output columns**: mu.code, maritime_union_id

```sql
CREATE TEMP TABLE maritime_union_code_lookup AS
SELECT
    mu.code,
    mu.id AS maritime_union_id
FROM public.maritime_unions mu
WHERE mu.code IS NOT NULL
  AND TRIM(mu.code) <> ''
  AND mu.deleted_at IS NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_details'::VARCHAR(100), md.vessel_details_id::text || '|union_code|' || md.legacy_un... |
| 2 | derived | - | vessel_id | - | md.vessel_id | md.vessel_id |
| 3 | derived | - | vessel_revision_id | - | md.vessel_revision_id | md.vessel_revision_id |
| 4 | derived | - | maritime_union_id | - | md.maritime_union_id | md.maritime_union_id |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | - | - | parent_id | - | NULL | NULL::uuid |
| 7 | - | - | level | - | NULL | NULL::numeric |
| 8 | derived | - | version | - | 1 AS version | 1 |
| 9 | derived | - | defined_by | - | 0 AS defined_by | 0 |
| 10 | derived | - | workflow_status | - | 0 AS workflow_status | 0 |
| 11 | derived | - | status | - | CASE WHEN md.deleted_at IS NOT NULL THEN 3 ELSE 0 END AS status | CASE WHEN md.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 12 | derived | - | created_at | - | COALESCE(md.created_at, NOW()) AS created_at | COALESCE(md.created_at, NOW()) |
| 13 | derived | - | updated_at | - | COALESCE(md.updated_at, NOW()) AS updated_at | COALESCE(md.updated_at, NOW()) |
| 14 | derived | - | deleted_at | - | md.deleted_at AS deleted_at | md.deleted_at |
| 15 | - | - | archived_at | - | NULL | NULL::timestamp |
| 16 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 17 | derived | - | tags | - | ARRAY['union_code']::text[] AS tags | ARRAY['union_code']::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.maritime_unions`
- `vessel.vessel_revisions`
- `vessel_revisions`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Output columns**: `legacy_vessel_id, new_vessel_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_vessel_id,
    target_id AS new_vessel_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 2. Maritime Union Code ID Mapping
**Output columns**: `mu.code, maritime_union_id`

```sql
CREATE TEMP TABLE maritime_union_code_lookup AS
SELECT
    mu.code,
    mu.id AS maritime_union_id
FROM public.maritime_unions mu
WHERE mu.code IS NOT NULL
  AND TRIM(mu.code) <> ''
  AND mu.deleted_at IS NULL;
```

Full migration context: `04-migration-scripts/master/vessel_revision_unions_migration.sql`

## Validation

- Run `05-validation/master/vessel_revision_unions_validation.sql` if available
- Run `06-rollback/master/vessel_revision_unions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
