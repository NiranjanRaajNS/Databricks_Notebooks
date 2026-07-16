# Table Mapping: (seed data) → profile_remark_types

## Overview
- **Legacy Database**: N/A (seed)
- **Legacy Schema**: -
- **Legacy Table**: (seed data)
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: profile_remark_types
- **Source Script**: `08-seed-data/crewing/profile_remark_types_seed_data.sql`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Seafarer Profile Remarks (`seafarer_profile_remarks` → `profile_remark_types`)

## Migration Notes

- Migrates distinct values from seafarer_profile_remarks.type column
- No legacy migration script; populated via seed data SQL.

## Special Considerations

- Seed script: fixed rows inserted via VALUES (no legacy source table).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | gen_random_uuid() as id | gen_random_uuid() |
| 2 | name_lower | - | code | - | UPPER(seed_data.name_lower) as code | UPPER(seed_data.name_lower) |
| 3 | name_lower | - | name | - | INITCAP(seed_data.name_lower) as name | INITCAP(seed_data.name_lower) |
| 4 | name_lower | - | description | - | LOWER(seed_data.name_lower) as description | LOWER(seed_data.name_lower) |
| 5 | name_lower | - | level | - | ROW_NUMBER() OVER (ORDER BY seed_data.name_lower ASC) - 1 as level | ROW_NUMBER() OVER (ORDER BY seed_data.name_lower ASC) - 1 |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | - | - | parent_id | - | NULL | NULL::uuid |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 10 | - | - | updated_at | - | NULL | NULL::timestamp |
| 11 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 12 | - | - | archived_at | - | NULL | NULL::timestamp |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 14 | name_lower | - | tags | - | ( SELECT ARRAY_AGG(DISTINCT tag ORDER BY tag) FROM ( SELECT UPPER(seed_data.name_lower) AS tag UNION ALL SELECT LOWER(seed_data.name_lower) AS tag ) AS tag_sources WHERE tag IS ... | ( SELECT ARRAY_AGG(DISTINCT tag ORDER BY tag) FROM ( SELECT UPPER(seed_data.name_lower) AS tag UNION ALL SELECT LOWER(seed_data.name_lower) AS tag ) AS tag_sources WHERE tag IS ... |
| 15 | derived | - | status | - | 0 as status | 0 |
| 16 | derived | - | workflow_status | - | 0 as workflow_status | 0 |
| 17 | derived | - | defined_by | - | 0 as defined_by | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `08-seed-data/crewing/profile_remark_types_seed_data.sql`

## Validation

- Run `05-validation/crewing/profile_remark_types_validation.sql` if available
- Run `06-rollback/crewing/profile_remark_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
