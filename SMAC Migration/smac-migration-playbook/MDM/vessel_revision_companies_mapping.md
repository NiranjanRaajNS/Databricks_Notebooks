# Table Mapping: vessel_details → vessel_revision_companies

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_details
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_revision_companies
- **Source Script**: `04-migration-scripts/master/vessel_revision_companies_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_details`
- **New Path**: `smac_master_migration.vessel.vessel_revision_companies`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ship Management Companies (`ship_management_companies` → `companies`)

## Migration Notes

- Maps vessel_revision_id from vessel_details.identifier (UUID) directly
- Maps company_id from company column values (bigint) to ship_management_companies.identifier (UUID)
- Maps service_type_id based on source column name
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessel.vessel_revisions and public.companies to be migrated first
- Main company information from ship_management_companies. Uses ship_management_companies_migration.sql script.

## Special Considerations

- Uses migration.resolve_target_id() for idempotent UUID generation (unpivot operation - uses composite source_id)
- Unpivots company columns from vessel_details into individual vessel_revision_companies records
- Script performs `TRUNCATE TABLE vessel.vessel_revision_companies` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `company_id_mapping` | FK lookup | `legacy_company_id`, `company_id` | - | `synergy_master` |
| `mlc_company_id_mapping` | FK lookup | `legacy_mlc_company_id`, `company_id` | `synergy_vessel.public.mlc_master` → `?.?.companies` | `synergy_vessel` |

### `company_id_mapping`

- **Output columns**: legacy_company_id, company_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT
    smc.id::bigint AS legacy_company_id,
    smc.identifier::uuid AS company_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ship_management_companies WHERE identifier IS NOT NULL'
) AS smc(id bigint, identifier uuid);
```

### `mlc_company_id_mapping`

- **Output columns**: legacy_mlc_company_id, company_id
- **migration.table_mappings**: source_db=synergy_vessel, source_schema=public, source_table=mlc_master, target_table=companies
- **dblink connection**: `synergy_vessel`

```sql
CREATE TEMP TABLE mlc_company_id_mapping AS
SELECT
    mm.id::bigint AS legacy_mlc_company_id,
    tm.target_id AS company_id
FROM dblink('synergy_vessel',
    'SELECT id FROM public.mlc_master WHERE id IS NOT NULL'
) AS mm(id bigint)
INNER JOIN migration.table_mappings tm
    ON tm.source_db = 'synergy_vessel'
    AND tm.source_schema = 'public'
    AND tm.source_table = 'mlc_master'
    AND tm.source_id = mm.id::text
    AND tm.target_table = 'companies'
    AND tm.target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_vessel'::VARCHAR(100), 'public'::VARCHAR(100), 'vessel_details'::VARCHAR(100), vd.id::text || '|ship_management_company_id', current_databa... |
| 2 | identifier | - | vessel_revision_id | - | vd.identifier AS vessel_revision_id | vd.identifier |
| 3 | derived | - | company_id | - | cm.company_id | cm.company_id |
| 4 | derived | - | service_type_id | - | COALESCE( (SELECT service_type_id FROM service_type_mapping WHERE LOWER(name) = 'technical'), '00000000-0000-0000-0000-000000000000'::uuid ) AS service_type_id | COALESCE( (SELECT service_type_id FROM service_type_mapping WHERE LOWER(name) = 'technical'), '00000000-0000-0000-0000-000000000000'::uuid ) |
| 5 | - | - | start_date | - | NULL | NULL::date |
| 6 | - | - | end_date | - | NULL | NULL::date |
| 7 | derived | - | is_inhouse_service | - | false AS is_inhouse_service | false |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | - | - | parent_id | - | NULL | NULL::uuid |
| 10 | derived | - | version | - | 1 AS version | 1 |
| 11 | created_at | - | created_at | - | COALESCE(vd.created_at, NOW()) AS created_at | COALESCE(vd.created_at, NOW()) |
| 12 | updated_at | - | updated_at | - | COALESCE(vd.updated_at, NOW()) AS updated_at | COALESCE(vd.updated_at, NOW()) |
| 13 | deleted_at | - | deleted_at | - | vd.deleted_at AS deleted_at | vd.deleted_at |
| 14 | - | - | archived_at | - | NULL | NULL::timestamp |
| 15 | audit_info, id, identifier, ship_management_company_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, CASE WHEN vd.audit_info IS NOT NULL AND vd.audit... |
| 16 | - | - | level | - | NULL | NULL::numeric |
| 17 | derived | - | tags | - | ARRAY['ship_management_company_id']::text[] AS tags | ARRAY['ship_management_company_id']::text[] |
| 18 | deleted_at, status | - | status | - | CASE WHEN vd.deleted_at IS NOT NULL THEN 3 WHEN vd.status IS NULL OR TRIM(vd.status) = '' THEN 0 WHEN UPPER(TRIM(vd.status)) = 'ACTIVE' OR TRIM(vd.status) = '0' THEN 0 WHEN UPPE... | CASE WHEN vd.deleted_at IS NOT NULL THEN 3 WHEN vd.status IS NULL OR TRIM(vd.status) = '' THEN 0 WHEN UPPER(TRIM(vd.status)) = 'ACTIVE' OR TRIM(vd.status) = '0' THEN 0 WHEN UPPE... |
| 19 | derived | - | workflow_status | - | 0 AS workflow_status | 0 |
| 20 | derived | - | defined_by | - | 0 AS defined_by | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `companies`
- `public.companies`
- `vessel.vessel_revisions`
- `vessel_revisions`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Company ID Mapping
**Output columns**: `legacy_company_id, company_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE company_id_mapping AS
SELECT
    smc.id::bigint AS legacy_company_id,
    smc.identifier::uuid AS company_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ship_management_companies WHERE identifier IS NOT NULL'
) AS smc(id bigint, identifier uuid);
```

### 2. Mlc Company ID Mapping
**Output columns**: `legacy_mlc_company_id, company_id`
**migration.table_mappings**: `mlc_master` → `companies` (source_db=`synergy_vessel`)
**dblink**: `synergy_vessel`

```sql
CREATE TEMP TABLE mlc_company_id_mapping AS
SELECT
    mm.id::bigint AS legacy_mlc_company_id,
    tm.target_id AS company_id
FROM dblink('synergy_vessel',
    'SELECT id FROM public.mlc_master WHERE id IS NOT NULL'
) AS mm(id bigint)
INNER JOIN migration.table_mappings tm
    ON tm.source_db = 'synergy_vessel'
    AND tm.source_schema = 'public'
    AND tm.source_table = 'mlc_master'
    AND tm.source_id = mm.id::text
    AND tm.target_table = 'companies'
    AND tm.target_db = current_database();
```

Full migration context: `04-migration-scripts/master/vessel_revision_companies_migration.sql`

## Validation

- Run `05-validation/master/vessel_revision_companies_validation.sql` if available
- Run `06-rollback/master/vessel_revision_companies_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
