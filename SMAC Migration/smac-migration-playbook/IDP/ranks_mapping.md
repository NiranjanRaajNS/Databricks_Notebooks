# Table Mapping: ranks → ranks

## Overview
- **Legacy Database**: smac_master_migration
- **Legacy Schema**: public
- **Legacy Table**: ranks
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: ranks
- **Source Script**: `04-migration-scripts/idp/ranks_migration.sql`

- **Legacy Path**: `smac_master_migration.public.ranks`
- **New Path**: `smac_idp_dev.public.ranks`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Ranks (`ranks` → `ranks`)

## Migration Notes

- Reading from already-migrated master database (smac_master_migration.public.ranks)

## Special Considerations

- Mappings are stored in and read from smac_master_migration.migration.table_mappings

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | - | gen_random_uuid() | gen_random_uuid() |
| 2 | derived | - | rank_id | - | r.id AS rank_id | r.id |
| 3 | derived | - | role_id | - | ro.id AS role_id | ro.id |
| 4 | derived | - | rank_code | - | r.code AS rank_code | r.code |
| 5 | derived | - | status | - | 0 AS status | 0 |
| 6 | - | - | archived_at | - | NULL | NULL::timestamp |
| 7 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 8 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 9 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 10 | - | - | audit_info | - | NULL | NULL::jsonb |
| 11 | derived | - | tenant_id | - | COALESCE(r.tenant_id, current_setting('migration.default_tenant_id')::uuid) AS tenant_id | COALESCE(r.tenant_id, current_setting('migration.default_tenant_id')::uuid) |
| 12 | - | - | parent_id | - | NULL | NULL::uuid |
| 13 | - | - | tags | - | NULL | NULL::text[] |
| 14 | derived | - | workflow_status | - | 0 AS workflow_status | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/ranks_migration.sql`

## Validation

- Run `05-validation/idp/ranks_validation.sql` if available
- Run `06-rollback/idp/ranks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
