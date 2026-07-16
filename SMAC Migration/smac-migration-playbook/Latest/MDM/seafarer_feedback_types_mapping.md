# Table Mapping: feedback_reasons → seafarer_feedback_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: feedback_reasons
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: seafarer_feedback_types
- **Source Script**: `04-migration-scripts/master/seafarer_feedback_types_migration.sql`

- **Legacy Path**: `synergy_master.public.feedback_reasons`
- **New Path**: `smac_master_migration.crewing.seafarer_feedback_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Seafarer Feedback Types (`feedback_reasons` → `seafarer_feedback_types`)

## Migration Notes

- Source: `synergy_master.public.feedback_reasons` → `crewing.seafarer_feedback_types`
- `resolve_target_id()` with source_id = bigint `id`; `p_target_id = NULL`
- `feedback_category_id_mapping`: maps `feedback_type_identifier` → `enum.feedbackreasontype.identifier` (UUID validated)
- TRUNCATE target
- Filter: non-empty `name`
- `status` Case 3 from `deleted_at` + `is_active`
- `level` = sequential ROW_NUMBER alphabetically by name
- `audit_info` uses SAC `created_by_id`/`updated_by_id`

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.seafarer_feedback_types` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `feedback_category_id_mapping` | Check for duplicate UUIDs in source table | `legacy_enum_id`, `category_uuid` | - | `synergy_master` |

### `feedback_category_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: legacy_enum_id, category_uuid
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE feedback_category_id_mapping AS
SELECT
    e.id::bigint AS legacy_enum_id,
    CASE
        WHEN e.identifier_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN e.identifier_text::uuid
        ELSE NULL
    END AS category_uuid
FROM dblink('synergy_master',
    'SELECT id, identifier::text FROM enum.feedbackreasontype WHERE identifier IS NOT NULL'
) AS e(id bigint, identifier_text text)
WHERE e.identifier_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = NULL` |  |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(name), NULL)` |  |
| 3 | `name` | text | `name` | text | `TRIM(name)` |  |
| 4 | `description` | text | `description` | text | `TRIM(description)` |  |
| 5 | `name` | text | `level` | numeric(10,1) | `ROW_NUMBER() OVER (ORDER BY TRIM(name))` as sequential decimal | Alphabetical order |
| 6 | `feedback_type_identifier` | integer | `feedback_category_id` | uuid | Map via `feedback_category_id_mapping` to enum identifier UUID | FK lookup |
| 7 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` |  |
| 8 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 9 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 10 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` |  |
| 11 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` |  |
| 12 | `deleted_at, is_active` | timestamp, boolean | `status` | integer | Rule 2.2.1 Case 1: `deleted_at IS NOT NULL` → 3 (Deleted); else 0 (Active) |  |
| 13 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` |  |
| 14 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` |  |
| 15 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy |  |
| 16 | `—` | — | `archived_at` | timestamp | `NULL` |  |
| 17 | `name` | text | `tags` | text[] | Array from code tag + lowercase normalized name slug |  |
| 18 | `created_by_id, updated_by_id` | uuid | `audit_info` | jsonb | `migration.build_audit_info(created_by_id, NULL, updated_by_id, ...)` |  |

**SAC columns not migrated:** None from dblink SELECT.

**SMAC columns not migrated:** None beyond defaults.
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Feedback Category ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `legacy_enum_id, category_uuid`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE feedback_category_id_mapping AS
SELECT
    e.id::bigint AS legacy_enum_id,
    CASE
        WHEN e.identifier_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN e.identifier_text::uuid
        ELSE NULL
    END AS category_uuid
FROM dblink('synergy_master',
    'SELECT id, identifier::text FROM enum.feedbackreasontype WHERE identifier IS NOT NULL'
) AS e(id bigint, identifier_text text)
WHERE e.identifier_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

Full migration context: `04-migration-scripts/master/seafarer_feedback_types_migration.sql`

## Validation

- Run `05-validation/master/seafarer_feedback_types_validation.sql` if available
- Run `06-rollback/master/seafarer_feedback_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
