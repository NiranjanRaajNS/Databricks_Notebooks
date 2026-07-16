# Table Mapping: seafarer_restrictions → seafarer_restrictions

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_restrictions
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_restrictions
- **Source Script**: `04-migration-scripts/crewing/seafarer_restrictions_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_restrictions`
- **New Path**: `smac_crewing_migration.public.seafarer_restrictions`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Restrictions (`seafarer_restrictions` → `seafarer_restrictions`)

## Migration Notes

- Source has vessel_id as bigint[] (array), target has VesselId as single uuid
- Creates one row per vessel in the array (expands array into multiple rows)
- Maps seafarer_uuid (uuid) → SeafarerId (uuid) directly from seafarers table
- Maps vessel_id (bigint[]) → VesselId (uuid) via migration.table_mappings
- Uses deterministic UUID generation from source id + vessel_id combination
- Uses standardized SMAC audit_info structure
- Migrates seafarer_restrictions table. Source has vessel_id as bigint[] (array), target has VesselId as single uuid - creates one row per vessel in the array (expands array into multiple rows). Maps seafarer_uuid (uuid) to SeafarerId (uuid) directly from seafarers table. Maps vessel_id (bigint[]) to VesselId (uuid) via migration.table_mappings from smac_master_migration. Converts restricted_flags (jsonb) to RestrictedFlags (text). Uses source id UUID directly as target id. Requires seafarers and vessels tables to be migrated first.

## Special Considerations

- Converts restricted_flags (jsonb) → RestrictedFlags (text)
- Script performs `TRUNCATE TABLE public.seafarer_restrictions` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `vessels`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_uuid_mapping` | FK lookup | `source_id`, `target_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `seafarer_uuid_mapping` | FK lookup | `legacy_uuid`, `target_id` | - | - |

### `vessel_uuid_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_uuid_mapping AS
SELECT source_id::bigint as source_id, target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''vessels'' AND source_id ~ ''^-?[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### `seafarer_uuid_mapping`

- **Output columns**: legacy_uuid, target_id

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT id AS legacy_uuid, id AS target_id
FROM public.seafarers;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | "Id" | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_restrictions'::VARCHAR(100), sr.id::text, current_database()::text::VARCHAR(100)... |
| 2 | derived | - | "SeafarerId" | - | COALESCE( seafarer_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid ) as "SeafarerId" | COALESCE( seafarer_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid ) as "SeafarerId" |
| 3 | derived | - | "VesselId" | - | COALESCE( vessel_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid ) as "VesselId" | COALESCE( vessel_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid ) as "VesselId" |
| 4 | derived | - | "Reason" | - | TRIM(sr.reason) as "Reason" | TRIM(sr.reason) as "Reason" |
| 5 | derived | - | "RestrictedFlags" | - | CASE WHEN sr.restricted_flags IS NOT NULL THEN sr.restricted_flags::text ELSE NULL END as "RestrictedFlags" | CASE WHEN sr.restricted_flags IS NOT NULL THEN sr.restricted_flags::text ELSE NULL END as "RestrictedFlags" |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | created_at | - | COALESCE(sr.created_at, NOW()) as created_at | COALESCE(sr.created_at, NOW()) |
| 8 | derived | - | updated_at | - | COALESCE(sr.updated_at, NOW()) as updated_at | COALESCE(sr.updated_at, NOW()) |
| 9 | - | - | archived_at | - | NULL | NULL::timestamp |
| 10 | derived | - | deleted_at | - | sr.deleted_at | sr.deleted_at |
| 11 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( sr.created_by_id::varchar, sr.deleted_by_id::varchar, sr.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel Uuid ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_uuid_mapping AS
SELECT source_id::bigint as source_id, target_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''vessels'' AND source_id ~ ''^-?[0-9]+$'''
) AS t(source_id text, target_id uuid);
```

### 2. Seafarer Uuid ID Mapping
**Output columns**: `legacy_uuid, target_id`

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT id AS legacy_uuid, id AS target_id
FROM public.seafarers;
```

Full migration context: `04-migration-scripts/crewing/seafarer_restrictions_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_restrictions_validation.sql` if available
- Run `06-rollback/crewing/seafarer_restrictions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
