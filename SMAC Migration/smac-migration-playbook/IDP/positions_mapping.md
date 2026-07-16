# Table Mapping: positions → positions

## Overview
- **Legacy Database**: smac_master_migration
- **Legacy Schema**: public
- **Legacy Table**: positions
- **New Database**: smac_master_migration
- **New Schema**: current DB public
- **New Table**: positions
- **Source Script**: `04-migration-scripts/idp/positions_migration.sql`

- **Legacy Path**: `smac_master_migration.public.positions`
- **New Path**: `current DB public.positions`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Positions (`positions` → `positions`)

## Migration Notes

- IDP schema includes user_type_id (NOT NULL); rank_id is UUID (already resolved in master)

## Special Considerations

- Script performs `TRUNCATE TABLE public.positions` before insert (full table reload).
- Orchestration dependencies: `ranks`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | src.id | src.id |
| 2 | name | - | name | - | TRIM(src.name) AS name | TRIM(src.name) |
| 3 | code, name | - | code | - | COALESCE( NULLIF(TRIM(src.code), ''), UPPER(REGEXP_REPLACE(TRIM(src.name), '[^A-Za-z0-9]', '_', 'g')) ) AS code | COALESCE( NULLIF(TRIM(src.code), ''), UPPER(REGEXP_REPLACE(TRIM(src.name), '[^A-Za-z0-9]', '_', 'g')) ) |
| 4 | derived | - | user_type_id | - | '00000000-0000-0000-0000-000000000000'::uuid AS user_type_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 5 | level | - | level | - | COALESCE(src.level, 0) AS level | COALESCE(src.level, 0) |
| 6 | rank_id | - | rank_id | - | COALESCE(src.rank_id, '00000000-0000-0000-0000-000000000000'::uuid) AS rank_id | COALESCE(src.rank_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 7 | - | - | archived_at | - | NULL | NULL::timestamptz |
| 8 | created_at | - | created_at | - | COALESCE(src.created_at AT TIME ZONE 'UTC', NOW()) AS created_at | COALESCE(src.created_at AT TIME ZONE 'UTC', NOW()) |
| 9 | updated_at, created_at | - | updated_at | - | COALESCE(src.updated_at AT TIME ZONE 'UTC', src.created_at AT TIME ZONE 'UTC', NOW()) AS updated_at | COALESCE(src.updated_at AT TIME ZONE 'UTC', src.created_at AT TIME ZONE 'UTC', NOW()) |
| 10 | deleted_at | - | deleted_at | - | src.deleted_at AT TIME ZONE 'UTC' AS deleted_at | src.deleted_at AT TIME ZONE 'UTC' |
| 11 | audit_info | - | audit_info | - | COALESCE(src.audit_info, '{}'::jsonb) || jsonb_build_object( 'migrated_at', NOW(), 'migration_source', 'smac_master_migration.public.positions' ) AS audit_info | COALESCE(src.audit_info, '{}'::jsonb) || jsonb_build_object( 'migrated_at', NOW(), 'migration_source', 'smac_master_migration.public.positions' ) |
| 12 | tenant_id | - | tenant_id | - | COALESCE(src.tenant_id, '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid) AS tenant_id | COALESCE(src.tenant_id, '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid) |
| 13 | status | - | status | - | COALESCE(src.status, 0) AS status | COALESCE(src.status, 0) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/idp/positions_migration.sql`

## Validation

- Run `05-validation/idp/positions_validation.sql` if available
- Run `06-rollback/idp/positions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
