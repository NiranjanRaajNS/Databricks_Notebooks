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

- Creates capacity range records for each vessel sub category
- Maps capacity_id from vessel_category_capacity_mapping based on sub category's category
- Maps vessel_sub_category_id from vessel_sub_categories.identifier
- Maps capacity ranges based on capacity type: teu_from→lower_limit, teu_to→upper_limit (and similar for dwt, cbm)
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Requires vessel.sub_categories, vessel.categories, vessel.capacity, and vessel.vessel_category_capacity_mapping to be migrated first
- Creates capacity range records for each vessel sub category. For each sub category, creates one record per capacity associated with its category (from vessel_category_capacity_mapping). Maps vessel_sub_category_id from vessel_sub_categories.identifier, capacity_id from vessel_category_capacity_mapping, and maps dwt_from to upper_limit and dwt_to to lower_limit. Requires vessel_sub_categories and vessel_category_capacity_mapping tables to be migrated first.

## Special Considerations

- Uses migration.resolve_target_id() with composite source IDs for unpivot scenario
- Script performs `TRUNCATE TABLE vessel.vessel_sub_category_capacity_range` before insert (full table reload).
- Orchestration dependencies: `vessel_sub_categories`, `vessel_category_capacity_mapping`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | ri.resolved_id AS id | ri.resolved_id |
| 2 | derived | - | capacity_id | - | ri.capacity_id | ri.capacity_id |
| 3 | derived | - | vessel_sub_category_id | - | ri.sub_category_identifier AS vessel_sub_category_id | ri.sub_category_identifier |
| 4 | derived | - | upper_limit | - | CASE WHEN 'teu_capacity' = ANY(ri.capacity_tags) THEN ri.teu_to::numeric(18,2) WHEN 'grain_capacity' = ANY(ri.capacity_tags) OR 'bale_capacity' = ANY(ri.capacity_tags) THEN ri.d... | CASE WHEN 'teu_capacity' = ANY(ri.capacity_tags) THEN ri.teu_to::numeric(18,2) WHEN 'grain_capacity' = ANY(ri.capacity_tags) OR 'bale_capacity' = ANY(ri.capacity_tags) THEN ri.d... |
| 5 | derived | - | lower_limit | - | CASE WHEN 'teu_capacity' = ANY(ri.capacity_tags) THEN ri.teu_ | CASE WHEN 'teu_capacity' = ANY(ri.capacity_tags) THEN ri.teu_ |
| 6 | - | - | tenant_id | - | See source script | See source script |
| 7 | - | - | parent_id | - | See source script | See source script |
| 8 | - | - | version | - | See source script | See source script |
| 9 | - | - | created_at | - | See source script | See source script |
| 10 | - | - | updated_at | - | See source script | See source script |
| 11 | - | - | deleted_at | - | See source script | See source script |
| 12 | - | - | archived_at | - | See source script | See source script |
| 13 | - | - | audit_info | - | See source script | See source script |
| 14 | - | - | level | - | See source script | See source script |
| 15 | - | - | tags | - | See source script | See source script |
| 16 | - | - | status | - | See source script | See source script |
| 17 | - | - | workflow_status | - | See source script | See source script |
| 18 | - | - | defined_by | - | See source script | See source script |

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
