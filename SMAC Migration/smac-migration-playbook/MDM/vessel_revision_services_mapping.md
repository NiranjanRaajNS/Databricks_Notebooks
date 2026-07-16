# Table Mapping: vessel_details → vessel_revision_services

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_details
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_revision_services
- **Source Script**: `04-migration-scripts/master/vessel_revision_services_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_details`
- **New Path**: `smac_master_migration.vessel.vessel_revision_services`

## Business Key

- **Composite Key**: (`vessel_revision_id`, `service_type_id`)
- **Source (orchestration)**: Vessel Revision Services (`vessel_details` → `vessel_revision_services`)

## Migration Notes

- Maps vessel_revision_id from vessel_details.identifier (UUID) directly
- Maps vessel_id from vessel_details.vessel_id (bigint) to vessel.vessels.id (uuid) via migration.table_mappings
- Maps service_type_id from vessel_details.service_type (varchar) to public.service_types.id (uuid) via migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessel.vessel_revisions, vessel.vessels, and public.service_types to be migrated first
- Maps vessel_details to vessel_revision_services. Maps vessel_revision_id from vessel_details.identifier (uuid) directly. Maps vessel_id from vessel_details.vessel_id (bigint) to vessel.vessels.id (uuid) via migration.table_mappings. Maps service_type_id from vessel_details.service_type (varchar) to public.service_types.id (uuid) via migration.table_mappings where target_table = 'service_types' and source_id = service_type. Requires vessel_revisions, vessels, and service_types tables to be migrated first.

## Special Considerations

- Uses migration.resolve_target_id() with composite source IDs for unpivot scenario
- Script performs `TRUNCATE TABLE vessel.vessel_revision_services` before insert (full table reload).
- Orchestration dependencies: `vessel_revisions`, `vessels`, `service_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `service_type_crewing_lookup` | FK lookup | `service_type_id` | - | - |
| `service_type_technical_lookup` | Check for duplicate UUIDs in source table | `service_type_id` | - | - |
| `service_type_procurement_lookup` | Check for duplicate UUIDs in source table | `service_type_id` | - | - |
| `service_type_accounting_lookup` | FK lookup | `service_type_id` | - | - |

### `vessel_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### `service_type_crewing_lookup`

- **Output columns**: service_type_id

```sql
CREATE TEMP TABLE service_type_crewing_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'crewing'
LIMIT 1;
```

### `service_type_technical_lookup`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: service_type_id

```sql
CREATE TEMP TABLE service_type_technical_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'technical'
LIMIT 1;
```

### `service_type_procurement_lookup`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: service_type_id

```sql
CREATE TEMP TABLE service_type_procurement_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'procurement'
LIMIT 1;
```

### `service_type_accounting_lookup`

- **Output columns**: service_type_id

```sql
CREATE TEMP TABLE service_type_accounting_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'accounting'
LIMIT 1;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_details'::VARCHAR(100), vd.id::text || '|Crewing', current_database()::text::VARCHAR... |
| 2 | derived | - | vessel_id | - | vim.new_id AS vessel_id | vim.new_id |
| 3 | identifier | - | vessel_revision_id | - | vd.identifier AS vessel_revision_id | vd.identifier |
| 4 | derived | - | service_type_id | - | COALESCE(st_crewing.service_type_id, '00000000-0000-0000-0000-000000000000'::uuid) AS service_type_id | COALESCE(st_crewing.service_type_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | - | - | parent_id | - | NULL | NULL::uuid |
| 7 | derived | - | version | - | 1 AS version | 1 |
| 8 | created_at | - | created_at | - | COALESCE(vd.created_at, NOW()) AS created_at | COALESCE(vd.created_at, NOW()) |
| 9 | updated_at | - | updated_at | - | COALESCE(vd.updated_at, NOW()) AS updated_at | COALESCE(vd.updated_at, NOW()) |
| 10 | deleted_at | - | deleted_at | - | vd.deleted_at AS deleted_at | vd.deleted_at |
| 11 | - | - | archived_at | - | NULL | NULL::timestamp |
| 12 | audit_info | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, CASE WHEN vd.audit_info IS NOT NULL AND vd.audit... |
| 13 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 14 | service_type | - | tags | - | ARRAY[COALESCE((SELECT name FROM public.service_types WHERE LOWER(TRIM(name)) = 'crewing' LIMIT 1), vd.service_type::text) | ARRAY[COALESCE((SELECT name FROM public.service_types WHERE LOWER(TRIM(name)) = 'crewing' LIMIT 1), vd.service_type::text) |
| 15 | derived | - | status | - | 'Crewing']::text[] AS tags | 'Crewing']::text[] AS tags |
| 16 | deleted_at, status | - | workflow_status | - | CASE WHEN vd.deleted_at IS NOT NULL THEN 3 WHEN vd.status IS NULL OR TRIM(vd.status) = '' THEN 0 WHEN UPPER(TRIM(vd.status)) = 'ACTIVE' OR TRIM(vd.status) = '1' THEN 0 WHEN UPPE... | CASE WHEN vd.deleted_at IS NOT NULL THEN 3 WHEN vd.status IS NULL OR TRIM(vd.status) = '' THEN 0 WHEN UPPER(TRIM(vd.status)) = 'ACTIVE' OR TRIM(vd.status) = '1' THEN 0 WHEN UPPE... |
| 17 | - | - | defined_by | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer AS workflow_status |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.service_types`
- `vessel.vessel_revisions`
- `vessel.vessels`
- `vessel_revisions`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 2. Service Type Crewing ID Mapping
**Output columns**: `service_type_id`

```sql
CREATE TEMP TABLE service_type_crewing_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'crewing'
LIMIT 1;
```

### 3. Service Type Technical ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `service_type_id`

```sql
CREATE TEMP TABLE service_type_technical_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'technical'
LIMIT 1;
```

### 4. Service Type Procurement ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `service_type_id`

```sql
CREATE TEMP TABLE service_type_procurement_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'procurement'
LIMIT 1;
```

### 5. Service Type Accounting ID Mapping
**Output columns**: `service_type_id`

```sql
CREATE TEMP TABLE service_type_accounting_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'accounting'
LIMIT 1;
```

Full migration context: `04-migration-scripts/master/vessel_revision_services_migration.sql`

## Validation

- Run `05-validation/master/vessel_revision_services_validation.sql` if available
- Run `06-rollback/master/vessel_revision_services_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
