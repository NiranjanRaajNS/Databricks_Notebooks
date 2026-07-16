# Table Mapping: consents → consents

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: consents
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: consents
- **Source Script**: `04-migration-scripts/idp/consents_migration.sql`

- **Legacy Path**: `synergy_identity_shore_prod.public.consents`
- **New Path**: `smac_idp_dev.public.consents`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Consents (`consents` → `consents`)

## Special Considerations

- Orchestration dependencies: `consent_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `consent_type_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `consent_type_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=consent_types

```sql
CREATE TEMP TABLE consent_type_id_mapping AS
SELECT
    tm.source_id::text AS legacy_id,
    tm.target_id::uuid AS new_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'consent_types'
  AND tm.target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | COALESCE(legacy_data.id, gen_random_uuid()) as id | COALESCE(legacy_data.id, gen_random_uuid()) |
| 2 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 3 | description | - | description | - | TRIM(legacy_data.description) as description | TRIM(legacy_data.description) |
| 4 | code | - | code | - | TRIM(legacy_data.code) as code | TRIM(legacy_data.code) |
| 5 | body | - | body | - | legacy_data.body as body | legacy_data.body |
| 6 | derived | - | consent_type_id | - | consent_type_map.new_id as consent_type_id | consent_type_map.new_id |
| 7 | status | - | status | - | CASE WHEN legacy_data.status::text = 'Active' THEN 0 WHEN legacy_data.status::text = 'Draft' THEN 1 WHEN legacy_data.status::text = 'Inactive' THEN 2 WHEN legacy_data.status::te... | CASE WHEN legacy_data.status::text = 'Active' THEN 0 WHEN legacy_data.status::text = 'Draft' THEN 1 WHEN legacy_data.status::text = 'Inactive' THEN 2 WHEN legacy_data.status::te... |
| 8 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 9 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 10 | id | - | audit_info | - | jsonb_build_object( 'legacy_id', legacy_data.id::text, 'migrated_at', NOW(), 'migration_source', 'synergy_identity_shore_prod' ) as audit_info | jsonb_build_object( 'legacy_id', legacy_data.id::text, 'migrated_at', NOW(), 'migration_source', 'synergy_identity_shore_prod' ) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Consent Type ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='consent_types'`

```sql
CREATE TEMP TABLE consent_type_id_mapping AS
SELECT
    tm.source_id::text AS legacy_id,
    tm.target_id::uuid AS new_id
FROM migration.table_mappings tm
WHERE tm.target_table = 'consent_types'
  AND tm.target_db = current_database();
```

Full migration context: `04-migration-scripts/idp/consents_migration.sql`

## Validation

- Run `05-validation/idp/consents_validation.sql` if available
- Run `06-rollback/idp/consents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
