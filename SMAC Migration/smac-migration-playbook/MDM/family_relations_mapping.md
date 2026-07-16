# Table Mapping: family_relations → family_relations

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: family_relations
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: family_relations
- **Source Script**: `04-migration-scripts/master/family_relations_migration.sql`

- **Legacy Path**: `synergy_master.public.family_relations`
- **New Path**: `smac_master_migration.public.family_relations`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Family Relations (`family_relations` → `family_relations`)

## Migration Notes

- Preserve legacy uuid (UUID) as id if available, otherwise generate new UUID
- Uses migration.resolve_target_id() for idempotent UUID generation
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates family_relations preserving identifier UUID as id if available, otherwise generates new UUIDs

## Special Considerations

- Script performs `TRUNCATE TABLE public.family_relations` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `gender_id_mapping` | FK lookup | `new_gender_id`, `gender_name` | - | `synergy_master` |

### `gender_id_mapping`

- **Output columns**: new_gender_id, gender_name
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE gender_id_mapping AS
SELECT DISTINCT
    d.identifier::uuid as new_gender_id,
    UPPER(TRIM(d.name)) as gender_name
FROM dblink('synergy_master',
    'SELECT identifier, name FROM enum.gender WHERE identifier IS NOT NULL AND TRIM(COALESCE(name, '''')) <> '''''
) AS d(identifier uuid, name text)
WHERE d.identifier IS NOT NULL
  AND TRIM(COALESCE(d.name, '')) <> '';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'family_relations'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(10... |
| 2 | relation, uuid | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.relation), legacy_data.uuid::text) |
| 3 | relation | - | name | - | LEFT(INITCAP(TRIM(COALESCE(legacy_data.relation, 'UNKNOWN'))), 255) AS name | LEFT(INITCAP(TRIM(COALESCE(legacy_data.relation, 'UNKNOWN'))), 255) |
| 4 | derived | - | gender_id | - | gender_map.new_gender_id AS gender_id | gender_map.new_gender_id |
| 5 | derived | - | category | - | 0 AS category | 0 |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 AS version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 11 | derived | - | level | - | 0 as level | 0 |
| 12 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 13 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 14 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 15 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Gender ID Mapping
**Output columns**: `new_gender_id, gender_name`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE gender_id_mapping AS
SELECT DISTINCT
    d.identifier::uuid as new_gender_id,
    UPPER(TRIM(d.name)) as gender_name
FROM dblink('synergy_master',
    'SELECT identifier, name FROM enum.gender WHERE identifier IS NOT NULL AND TRIM(COALESCE(name, '''')) <> '''''
) AS d(identifier uuid, name text)
WHERE d.identifier IS NOT NULL
  AND TRIM(COALESCE(d.name, '')) <> '';
```

Full migration context: `04-migration-scripts/master/family_relations_migration.sql`

## Validation

- Run `05-validation/master/family_relations_validation.sql` if available
- Run `06-rollback/master/family_relations_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
