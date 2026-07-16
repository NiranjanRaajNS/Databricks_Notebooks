# Table Mapping: vessel_sub_categories → sub_categories

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_sub_categories
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: sub_categories
- **Source Script**: `04-migration-scripts/master/sub_categories_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_sub_categories`
- **New Path**: `smac_master_migration.vessel.sub_categories`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Sub Categories (`vessel_sub_categories` → `sub_categories`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- `category_id` resolved by joining `vessel_category_id` → `vessel_categories.identifier` (UUID equals SMAC `categories.id`)
- `code` generated from `name` + `identifier` via `generate_meaningful_code()`
- `status` derived from `deleted_at` + `status` text (Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0)
- Filter: `identifier IS NOT NULL`, `name IS NOT NULL`, `TRIM(name) <> ''`
- Pre-migration duplicate UUID check on SAC `identifier` column

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.sub_categories` before insert (full table reload)
- Requires `categories` migrated first (`vessel_categories.identifier` used as `category_id`)

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `vessel_category_id` | bigint | `category_id` | uuid | Join `vessel_categories` on `vessel_category_id = vessel_categories.id`; use `identifier` | Direct use of `vessel_categories.identifier` UUID as SMAC `category_id` |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy; NOT NULL in SMAC |
| 4 | `name`, `identifier` | text, uuid | `code` | text | `generate_meaningful_code(TRIM(name), identifier::text)` | Generated business code; NOT NULL in SMAC |
| 5 | `description` | text | `description` | text | `TRIM(description)` | Direct copy with whitespace trimmed |
| 6 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 7 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 8 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 9 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 10 | `deleted_at`, `status` | timestamp without time zone, text | `status` | integer | Rule 2.2.1 Case 1: `deleted_at IS NOT NULL` → 3 (Deleted); else 0 (Active) | Per project rule Case 2 — deleted_at takes precedence|
| 11 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 12 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at)` | Falls back to `created_at` when `updated_at` is NULL |
| 13 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated |
| 14 | — | — | `level` | numeric | Hardcoded `0` | Hierarchy level; not in SAC source |
| 15 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated by IDs; names combined into `notes` | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- `categories` (via `vessel_categories.identifier`)

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/sub_categories_migration.sql`

## Validation

- Run `05-validation/master/sub_categories_validation.sql` if available
- Run `06-rollback/master/sub_categories_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
