# Table Mapping: non_synergy_group_companies → other_shipping_companies

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: non_synergy_group_companies
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: other_shipping_companies
- **Source Script**: `04-migration-scripts/master/other_shipping_companies_migration.sql`

- **Legacy Path**: `synergy_master.public.non_synergy_group_companies`
- **New Path**: `smac_master_migration.public.other_shipping_companies`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ship Management Companies (`ship_management_companies` → `companies`)

## Migration Notes

- Source: `synergy_master.public.non_synergy_group_companies` → `public.other_shipping_companies`
- `resolve_target_id()` with `p_target_id = NULL` (no identifier preserved)
- Same SAC table as `non_synergy_group_companies` but separate target/mappings
- TRUNCATE target
- Filter: non-empty `name`
- `status` Case 1 from `deleted_at` only
- Includes `deleted_at` column (unlike non_synergy_group_companies target)
## Special Considerations

- Script performs `TRUNCATE TABLE public.other_shipping_companies` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` | Idempotent via id_mappings |
| 2 | `name` | text | `name` | text | `TRIM(name)` |  |
| 3 | `name, code` | text, text | `code` | text | `COALESCE(NULLIF(TRIM(code), ''), generate_meaningful_code(TRIM(name), NULL))` |  |
| 4 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 5 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 6 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 7 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 8 | `deleted_at` | timestamp | `status` | integer | Case 1 — `deleted_at IS NOT NULL` → Deleted (3); else Active (0) |  |
| 9 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` |  |
| 10 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` |  |
| 11 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy |  |
| 12 | `created_by, updated_by` | varchar | `audit_info` | jsonb | `migration.build_audit_info(created_by, NULL, updated_by, ...)` |  |
| 13 | `—` | — | `level` | numeric | Hardcoded `0` |  |

**SAC columns not migrated:** `identifier` (not selected in dblink).

**SMAC columns not migrated:** None beyond defaults.",
)

# --- owner_relations ---
set_update(
    "owner_relations",
    [
        "- Source: `synergy_vessel.public.vessel_registered_owners` (where `vessel_owner_id` array not null) → `vessel.owner_relations`",
        "- Unnests `vessel_owner_id` bigint[] — one row per array element",
        "- Composite source_id: `id|owner_id|array_idx` via `resolve_target_id()`; `p_target_id = NULL`",
        "- `registered_owner_id_mapping` (source=vessel_registered_owners) + `group_owner_id_mapping` (source=vessel_owners)",
        "- Filter: both owner FK mappings must exist",
        "- `relation_type` hardcoded `0`",
        "- `status` hardcoded Active (0)",
    ],
    [
        row(1, "id, vessel_owner_id[], array_idx", "bigint, bigint[], integer", "id", "uuid", "`migration.resolve_target_id()` — composite source_id = `id|element|idx`; `p_target_id = NULL`", "
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/other_shipping_companies_migration.sql`

## Validation

- Run `05-validation/master/other_shipping_companies_validation.sql` if available
- Run `06-rollback/master/other_shipping_companies_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
