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

- Source: `synergy_vessel.public.vessel_details` unpivoted by company column
- SAC `id` + column name → composite `source_id` for `migration.resolve_target_id()`
- 6 UNION ALL branches: ship_management, recruitment (×4), manning, mlc company columns
- `vessel_revision_id` = SAC `identifier` (direct UUID)
- `company_id` via ship_management or mlc company mapping
- `service_type_id` derived per source column (technical, crewing, accounting, mlc)
- Filter: `identifier IS NOT NULL AND <company_col> IS NOT NULL`; INNER JOIN company mapping
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
| 1 | `id, company column` | bigint, bigint | `id` | uuid | `migration.resolve_target_id()` — composite source_id = `id|column_name` | One row per company column |
| 2 | `identifier` | uuid | `vessel_revision_id` | uuid | Direct copy of `identifier` | FK to vessel_revisions |
| 3 | `ship_management_company_id, recruitment_company, manning_management_company, mlc_company_id` | bigint | `company_id` | uuid | Map via `company_id_mapping` or `mlc_company_id_mapping` | FK lookup |
| 4 | `company column name` | — | `service_type_id` | uuid | Lookup `public.service_types` by column type (technical/crewing/accounting/mlc) | Derived per unpivot branch |
| 5 | `—` | — | `start_date` | timestamp without time zone | `NULL` | Not in SAC source |
| 6 | `—` | — | `end_date` | timestamp without time zone | `NULL` | Not in SAC source |
| 7 | `—` | — | `is_inhouse_service` | boolean | Hardcoded `false` | Not in SAC source |
| 8 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 9 | `—` | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 10 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 11 | `created_at` | timestamp | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 12 | `updated_at` | timestamp | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 13 | `deleted_at` | timestamp | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 14 | `—` | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 15 | `audit_info, column name` | jsonb, text | `audit_info` | jsonb | `migration.build_audit_info()` + legacy metadata keys | Includes unpivot column name |
| 16 | `—` | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 17 | `company column name` | — | `tags` | text[] | `ARRAY[column_name]` | Identifies source column |
| 18 | `status, deleted_at` | text, timestamp | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 |  |
| 19 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Not sourced from SAC |
| 20 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Not sourced from SAC |

**SAC columns not migrated:** Other `vessel_details` columns — handled in other vessel migrations.

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
