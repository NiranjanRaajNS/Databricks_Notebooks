# Table Mapping: reimbursement_sub_categories → reimbursement_sub_categories

## Overview
- **Legacy Database**: synergy_crewwage
- **Legacy Schema**: public
- **Legacy Table**: reimbursement_sub_categories
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: reimbursement_sub_categories
- **Source Script**: `04-migration-scripts/master/reimbursement_sub_categories_migration.sql`

- **Legacy Path**: `synergy_crewwage.public.reimbursement_sub_categories`
- **New Path**: `smac_master_migration.crewing.reimbursement_sub_categories`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Sub Categories (`vessel_sub_categories` → `sub_categories`)

## Migration Notes

- Source: `synergy_crewwage.public.reimbursement_sub_categories` CROSS JOIN reimbursement types (`On Boarding`, `Pre Joining`)
- `resolve_target_id()` with composite source_id = `id || '_' || reimbursement_type`
- Joins legacy category name → `crewing.reimbursement_categories` by name + type
- `category_id_mapping` temp table for FK resolution
- TRUNCATE target; DISTINCT ON legacy id in subquery
- `status` Case 1 from `deleted_at`
- `audit_info` merged with `legacy_id` and `migration_source` keys
## Special Considerations

- Requires reimbursement_categories to be migrated first
- Script performs `TRUNCATE TABLE crewing.reimbursement_sub_categories` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `category_id_mapping` | Check for duplicate UUIDs in source table | `category_id`, `category_name_lower`, `reimbursement_type_name` | - | - |

### `category_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: category_id, category_name_lower, reimbursement_type_name

```sql
CREATE TEMP TABLE category_id_mapping AS
SELECT DISTINCT ON (category_name_lower)
    id AS category_id,
    category_name_lower,
    reimbursement_type_name
FROM (
    SELECT
        A.id,
        TRIM(LOWER(A.name)) AS category_name_lower,
        1 AS priority,
        B.name AS reimbursement_type_name
    FROM crewing.reimbursement_categories A
    JOIN crewing.reimbursement_types B ON B.id = A.reimbursement_type_id
    WHERE A.name IS NOT NULL AND TRIM(A.name) != ''
) sub
ORDER BY category_name_lower, priority, id;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id, reimbursement_type` | bigint, text | `id` | uuid | `COALESCE(resolve_target_id(..., id || '_' || type, p_target_id=NULL), gen_random_uuid())` | Composite source_id |
| 2 | `category_name, reimbursement_type` | text, text | `reimbursement_category_id` | uuid | Join `crewing.reimbursement_categories` on name + type; fallback zero-UUID | FK lookup |
| 3 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` |  |
| 4 | `name` | text | `name` | text | `TRIM(name)` |  |
| 5 | `name` | text | `description` | text | `TRIM(name)` | Same as name |
| 6 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 7 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 8 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 9 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 10 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 11 | `deleted_at` | timestamp | `status` | integer | Case 1 — `deleted_at IS NOT NULL` → Deleted (3); else Active (0) |  |
| 12 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` |  |
| 13 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` |  |
| 14 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy |  |
| 15 | `id` | bigint | `audit_info` | jsonb | `migration.build_audit_info()` merged with `legacy_id` and `migration_source` |  |

**SAC columns not migrated:** `reimbursement_category_id` (bigint FK resolved via category name join).

**Note:** Each legacy subcategory expanded to 2 rows (On Boarding + Pre Joining).",
)

# --- relations ---
set_update(
    "relations",
    [
        "- Source: `synergy_master.public.family_relations` → `public.relations`",
        "- SAC `uuid` preserved via `resolve_target_id()` with `p_target_id = uuid`",
        "- Pre-migration duplicate UUID check on `uuid` column",
        "- TRUNCATE target",
        "- Filter: non-empty `relation`",
        "- `status` Case 1 from `deleted_at`",
        "- `code` from `generate_meaningful_code(TRIM(relation))`",
    ],
    [
        row(1, "id, uuid", "bigint, uuid", "id", "uuid", "`migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid`", "
## Foreign Key Dependencies

### Prerequisites (from source script)

- `reimbursement_categories`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Category ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `category_id, category_name_lower, reimbursement_type_name`

```sql
CREATE TEMP TABLE category_id_mapping AS
SELECT DISTINCT ON (category_name_lower)
    id AS category_id,
    category_name_lower,
    reimbursement_type_name
FROM (
    SELECT
        A.id,
        TRIM(LOWER(A.name)) AS category_name_lower,
        1 AS priority,
        B.name AS reimbursement_type_name
    FROM crewing.reimbursement_categories A
    JOIN crewing.reimbursement_types B ON B.id = A.reimbursement_type_id
    WHERE A.name IS NOT NULL AND TRIM(A.name) != ''
) sub
ORDER BY category_name_lower, priority, id;
```

Full migration context: `04-migration-scripts/master/reimbursement_sub_categories_migration.sql`

## Validation

- Run `05-validation/master/reimbursement_sub_categories_validation.sql` if available
- Run `06-rollback/master/reimbursement_sub_categories_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
