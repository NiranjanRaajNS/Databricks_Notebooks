# Table Mapping: fdl_department → fdl_departments

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: fdl_department
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: fdl_departments
- **Source Script**: `04-migration-scripts/master/fdl_departments_migration.sql`

- **Legacy Path**: `synergy_vessel.public.fdl_department`
- **New Path**: `smac_master_migration.vessel.fdl_departments`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Departments (Master) (`departments` → `departments`)

## Migration Notes

- `id` uses `migration.resolve_target_id()` with `source_id = id::text` and `p_target_id = NULL` (SAC has integer `id` only)
- `code` generated via `generate_meaningful_code(TRIM(name), TRIM(name))`
- `service_type_id` mapped from SAC `service_type` enum: `technical` → `Technical`, `manning` → `Crewing`
- `is_multi_cluster` set to `true` when service type name is `Crewing`
- `level` mapped from SAC `display_order`
- `status` mapped from SAC `status` varchar (no `deleted_at` in source)
- `created_at`/`updated_at` set to `NOW()` — not present in SAC source
- Post-migration UPDATE: `code = 'VEI'` where `name = 'Vessel IT FDL'`; tags override for CMS department
- Filter: only rows where `id IS NOT NULL AND TRIM(COALESCE(name, '')) <> ''`
- Requires `public.service_types` migrated first
- Uses integer constants from `constants.sql` for `tenant_id`, `defined_by`, `workflow_status`

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.fdl_departments` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | integer | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID; SAC has integer `id` only |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(COALESCE(name, 'UNKNOWN')), TRIM(COALESCE(name, 'UNKNOWN')))` | Generated from name; post-migration UPDATE sets `'VEI'` for Vessel IT FDL |
| 3 | `display_name`, `name` | text | `name` | text | `LEFT(COALESCE(display_name, name), 255)` | Prefers `display_name`; NOT NULL in SMAC |
| 4 | `display_name` | text | `description` | text | `TRIM(display_name)` when non-empty; else `NULL` | Uses display_name as description |
| 5 | `service_type` | text | `service_type_id` | uuid | Join `public.service_types`: `technical`→`Technical`, `manning`→`Crewing` | FK lookup by mapped service type name |
| 6 | — | — | `scope` | integer | Hardcoded `0` | Not in SAC source |
| 7 | `service_type` (via join) | text | `is_multi_cluster` | boolean | `true` when `service_types.name = 'Crewing'`; else `false` | Derived from mapped service type |
| 8 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 9 | — | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 10 | `display_order` | integer | `level` | numeric | `COALESCE(display_order, 0)` | SAC hierarchy order maps to SMAC `level` |
| 11 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 12 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 13 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 14 | `status` | text | `status` | integer | Map `status` string: ACTIVE/`0`→0, INACTIVE/`2`→2; default Active (0) | SAC has no `deleted_at` column |
| 15 | — | — | `created_at` | timestamp without time zone | `NOW()` | SAC has no `created_at` column |
| 16 | — | — | `updated_at` | timestamp without time zone | `NOW()` | SAC has no `updated_at` column |
| 17 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 18 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 19 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — `SYSTEM_USER_ID` for created/updated by | Standardized SMAC audit structure; `legacy_id` handled by `id_mappings` |
| 20 | `name`, `display_name` | text | `tags` | text[] | Distinct array: lowercase code tag + normalized name slug(s); `/` preserved variant when applicable | Derived search tags; post-migration override for CMS department |

**SMAC columns not migrated:** None — all target columns populated from SAC or defaults.

**SAC columns not migrated:** None significant — all SAC columns used in mapping or defaults.

**Post-migration changes (not from SAC column mapping):**
- UPDATE `code = 'VEI'` where `name = 'Vessel IT FDL'`
- UPDATE `tags = '{cms,qhse_fdl,CMS,cms_fdl}'` where `UPPER(TRIM(code)) = 'CMS'`

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.service_types`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/fdl_departments_migration.sql`

## Validation

- Run `05-validation/master/fdl_departments_validation.sql` if available
- Run `06-rollback/master/fdl_departments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
