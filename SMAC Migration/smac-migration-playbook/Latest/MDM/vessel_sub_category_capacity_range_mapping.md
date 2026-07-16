# Table Mapping: vessel_sub_categories → vessel_sub_category_capacity_range

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_sub_categories
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_sub_category_capacity_range
- **Source Script**: `04-migration-scripts/master/vessel_sub_category_capacity_range_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_sub_categories`
- **New Path**: `smac_master_migration.vessel.vessel_sub_category_capacity_range`

## Business Key

- **Composite Key**: (`vessel_sub_category_id`, `capacity_id`)
- **Source (orchestration)**: Vessel Sub Category Capacity Range (`vessel_sub_categories` → `vessel_sub_category_capacity_range`)

## Migration Notes

- Source: `synergy_vessel.public.vessel_sub_categories` × capacity types
- SAC `id` + `capacity_id` → composite `source_id` for `migration.resolve_target_id()`
- Join `vessel_categories` on `vessel_category_id`; match `vessel_category_capacity_mapping`
- `vessel_sub_category_id` = SAC `identifier` (direct UUID)
- `upper_limit`/`lower_limit` from `teu_to`/`dwt_to`/`cbm_to` and `*_from` by capacity tag
- Filter: `identifier IS NOT NULL`; `ON CONFLICT (id) DO NOTHING`
- `NOT EXISTS` duplicate check on target before insert
## Special Considerations

- Uses migration.resolve_target_id() with composite source IDs for unpivot scenario
- Script performs `TRUNCATE TABLE vessel.vessel_sub_category_capacity_range` before insert (full table reload).
- Orchestration dependencies: `vessel_sub_categories`, `vessel_category_capacity_mapping`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id, capacity_id` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — composite source_id | One row per sub_category × capacity |
| 2 | `—` | — | `capacity_id` | uuid | From `vessel_category_capacity_mapping` by category identifier | FK lookup |
| 3 | `identifier` | uuid | `vessel_sub_category_id` | uuid | Direct copy of `identifier` | FK to sub_categories |
| 4 | `teu_to, dwt_to, cbm_to` | numeric | `upper_limit` | numeric | Selected by capacity tag (TEU/DWT/CBM) | Per capacity type |
| 5 | `teu_from, dwt_from, cbm_from` | numeric | `lower_limit` | numeric | Selected by capacity tag (TEU/DWT/CBM) | Per capacity type |
| 6 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | `—` | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 8 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 10 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 11 | `—` | — | `deleted_at` | timestamp without time zone | Hardcoded NULL | Not populated from SAC |
| 12 | `—` | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 13 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info(SYSTEM_USER_ID)` | Standardized SMAC structure |
| 14 | `—` | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 15 | `—` | — | `tags` | text[] | Hardcoded NULL | Not in SAC source |
| 16 | `status` | text | `status` | integer | ACTIVE→0, INACTIVE→2, DRAFT→1, DELETED→3 | String status mapping |
| 17 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Not sourced from SAC |
| 18 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Not sourced from SAC |

**SAC columns not migrated:** Source `audit_info` JSONB — replaced with standardized SMAC audit via `SYSTEM_USER_ID`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `vessel.sub_categories`
- `vessel.vessel_category_capacity_mapping`
- `vessel_category_capacity_mapping`
- `vessel_sub_categories`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/vessel_sub_category_capacity_range_migration.sql`

## Validation

- Run `05-validation/master/vessel_sub_category_capacity_range_validation.sql` if available
- Run `06-rollback/master/vessel_sub_category_capacity_range_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
