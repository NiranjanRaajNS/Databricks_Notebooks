# Table Mapping: managementservicetypelist → management_services

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: enum
- **Legacy Table**: managementservicetypelist
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: management_services
- **Source Script**: `04-migration-scripts/master/management_services_migration.sql`

- **Legacy Path**: `synergy_master.enum.managementservicetypelist`
- **New Path**: `smac_master_migration.vessel.management_services`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Managementservicetypelist (`managementservicetypelist` → `management_services`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates enum.managementservicetypelist preserving identifier UUID as id. Master table with no dependencies.

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.management_services` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `service_type_id_mapping` | Clear existing data from target tab | `legacy_service_type_identifier`, `new_id` | - | `synergy_master` |

### `service_type_id_mapping`

- **Purpose**: Clear existing data from target tab
- **Output columns**: legacy_service_type_identifier, new_id
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE service_type_id_mapping AS
SELECT DISTINCT
    legacy_st.identifier AS legacy_service_type_identifier,
    COALESCE(
        CASE
            WHEN LOWER(TRIM(legacy_st.name)) = 'manning' THEN smac_st_crewing.id
            ELSE smac_st_match.id
        END,
        smac_st_technical.id
    ) AS new_id
FROM dblink('synergy_master',
    'SELECT identifier, name FROM enum.fdlservicetype WHERE identifier IS NOT NULL'
) AS legacy_st(identifier uuid, name text)
LEFT JOIN public.service_types smac_st_crewing ON LOWER(TRIM(smac_st_crewing.name)) = 'crewing'
LEFT JOIN public.service_types smac_st_match ON LOWER(TRIM(smac_st_match.name)) = LOWER(TRIM(legacy_st.name))
LEFT JOIN public.service_types smac_st_technical ON LOWER(TRIM(smac_st_technical.name)) = 'technical'
WHERE legacy_st.identifier IS NOT NULL;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id, identifier | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'enum'::VARCHAR(100), 'managementservicetypelist'::VARCHAR(100), legacy_data.id::text, current_database()::text::VAR... |
| 2 | name, identifier | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), legacy_data.identifier::text) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | derived | - | service_type_id | - | COALESCE(stm.new_id, '00000000-0000-0000-0000-000000000000'::uuid) AS service_type_id | COALESCE(stm.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | derived | - | version | - | 1 AS version | 1 |
| 7 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 8 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 9 | derived | - | status | - | 0 AS status | 0 |
| 10 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 11 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 12 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.service_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Service Type ID Mapping
**Purpose**: Clear existing data from target tab
**Output columns**: `legacy_service_type_identifier, new_id`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE service_type_id_mapping AS
SELECT DISTINCT
    legacy_st.identifier AS legacy_service_type_identifier,
    COALESCE(
        CASE
            WHEN LOWER(TRIM(legacy_st.name)) = 'manning' THEN smac_st_crewing.id
            ELSE smac_st_match.id
        END,
        smac_st_technical.id
    ) AS new_id
FROM dblink('synergy_master',
    'SELECT identifier, name FROM enum.fdlservicetype WHERE identifier IS NOT NULL'
) AS legacy_st(identifier uuid, name text)
LEFT JOIN public.service_types smac_st_crewing ON LOWER(TRIM(smac_st_crewing.name)) = 'crewing'
LEFT JOIN public.service_types smac_st_match ON LOWER(TRIM(smac_st_match.name)) = LOWER(TRIM(legacy_st.name))
LEFT JOIN public.service_types smac_st_technical ON LOWER(TRIM(smac_st_technical.name)) = 'technical'
WHERE legacy_st.identifier IS NOT NULL;
```

Full migration context: `04-migration-scripts/master/management_services_migration.sql`

## Validation

- Run `05-validation/master/management_services_validation.sql` if available
- Run `06-rollback/master/management_services_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
