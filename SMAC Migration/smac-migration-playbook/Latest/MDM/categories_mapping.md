# Table Mapping: vessel_categories → categories

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_categories
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: categories
- **Source Script**: `04-migration-scripts/master/categories_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_categories`
- **New Path**: `smac_master_migration.vessel.categories`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Categories (`vessel_categories` → `categories`)

## Migration Notes

- SAC `identifier` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = identifier`
- `code` generated from `name` + `identifier` via `generate_meaningful_code()`
- `status` derived from `deleted_at` + `status` text (Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0)
- `level` assigned via `ROW_NUMBER()` sorted alphabetically by name
- `tags` array includes generated code, normalized name slug, and `gas_tanker` for LPG carrier types
- Filter: `name IS NOT NULL` and `TRIM(name) <> ''`
- Pre-migration duplicate UUID check on SAC `identifier` column

## Special Considerations

- Script performs `TRUNCATE TABLE vessel.categories` before insert (full table reload)
- Prerequisite for `sub_categories` and other vessel FK migrations

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `identifier`, `id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = identifier` | Preserves SAC `identifier` as SMAC `id`; idempotent via `id_mappings` |
| 2 | `name`, `identifier` | text, uuid | `code` | text | `generate_meaningful_code(TRIM(name), identifier::text)` | Generated business code; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(name)` | Direct copy; NOT NULL in SMAC |
| 4 | `description` | text | `description` | text | `TRIM(description)` | Direct copy with whitespace trimmed |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 6 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 7 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |
| 8 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 9 | `deleted_at`, `status` | timestamp without time zone, text | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Per project rule Case 2 — deleted_at takes precedence|
| 10 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 11 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at)` | Falls back to `created_at` when `updated_at` is NULL |
| 12 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved; all records migrated |
| 13 | `name` | text | `level` | numeric | `ROW_NUMBER() OVER (ORDER BY TRIM(name))` | Sequential hierarchy index sorted alphabetically by name |
| 14 | `name`, `identifier` | text, uuid | `tags` | text[] | Array: generated code + lowercase normalized name slug; append `gas_tanker` for LPG CARRIER (REFRI/PRESS) | Derived search tags; not in SAC source |
| 15 | `created_by_id`, `updated_by_id` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated by IDs from SAC | Standardized SMAC audit structure; no `legacy_id` (identifier preserved as `id`) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/categories_migration.sql`

## Validation

- Run `05-validation/master/categories_validation.sql` if available
- Run `06-rollback/master/categories_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
