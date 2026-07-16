# Table Mapping: training → training_master

## Overview
- **Legacy Database**: synergy_training
- **Legacy Schema**: public
- **Legacy Table**: training
- **New Database**: smac_crewing_migration
- **New Schema**: crewing
- **New Table**: training_master
- **Source Script**: `04-migration-scripts/master/training_master_migration.sql`

- **Legacy Path**: `synergy_training.public.training`
- **New Path**: `smac_crewing_migration.crewing.training_master`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Training Master (`training` → `training_master`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id` column
- `training_type_id` mapped from SAC `type` via `training_type_id_mapping` (`crewing.training_type` seed data)
- `training_category_id` matched from SAC `course_type` → `crewing.training_category.code`; fallback `'TRAINING'` code
- `document_id` mapped from SAC `document_identifier` → `document.documents.identifier`
- `status` derived from `deleted_at` only (Case 1)
- `code` generated from `name` via `generate_meaningful_code()`
- Post-migration UPDATE: `document_id` fallback for `name = 'Other'` from documents named like `%other documents%`
- Requires `training_types` / `training_type` seed and `training_category` seed loaded first

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.training_master` before insert (full table reload).
- Orchestration dependencies: `training_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `training_type_id_mapping` | FK lookup | `legacy_id`, `new_id` | - | - |
| `document_id_mapping` | Get count of traini | `document_identifier`, `document_id` | - | - |

### `training_type_id_mapping`

- **Output columns**: legacy_id, new_id

```sql
CREATE TEMP TABLE training_type_id_mapping AS
SELECT id AS legacy_id, id AS new_id
FROM crewing.training_type;
```

### `document_id_mapping`

- **Purpose**: Get count of traini
- **Output columns**: document_identifier, document_id

```sql
CREATE TEMP TABLE document_id_mapping AS
SELECT DISTINCT
    TRIM(d.identifier) AS document_identifier,
    d.id AS document_id
FROM document.documents d
WHERE d.identifier IS NOT NULL
  AND TRIM(d.identifier) <> '';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid as SMAC id |
| 2 | `name`, `id` | text, uuid | `code` | text | `generate_meaningful_code(TRIM(COALESCE(name, 'UNKNOWN')), id::text)` | Generated from name; NOT NULL in SMAC |
| 3 | `name` | text | `name` | text | `TRIM(COALESCE(name, 'UNKNOWN'))` | NOT NULL in SMAC |
| 4 | `description` | text | `description` | text | `TRIM(description)` | Direct copy; nullable |
| 5 | `type` | uuid | `training_type_id` | uuid | Map via `training_type_id_mapping` on `crewing.training_type.id` | NULL when type not in seed data |
| 6 | `course_type` | text | `training_category_id` | uuid | Join `crewing.training_category` on `UPPER(TRIM(code))`; fallback `code = 'TRAINING'` or first category | FK lookup |
| 7 | `include_In_appraisal` | boolean | `eligable_for_appraisal` | boolean | `COALESCE(include_In_appraisal, false)` | Direct boolean mapping |
| 8 | `document_identifier` | text | `document_id` | uuid | Map via `document_id_mapping` on `document.documents.identifier` | Post-migration fallback for `'Other'` |
| 9 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 10 | — | — | `parent_id` | uuid | `NULL` | No parent in SAC |
| 11 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 12 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 13 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 14 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 15 | `deleted_at` | timestamp with time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Case 1 — `deleted_at` only |
| 16 | `created_at` | timestamp with time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 17 | `updated_at` | timestamp with time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 18 | `deleted_at` | timestamp with time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 19 | — | — | `archived_at` | timestamp without time zone | `NULL` | No source equivalent |
| 20 | `created_by_id`, `updated_by_id`, `deleted_by_id`, `created_by_name`, `updated_by_name`, `deleted_by_name` | text | `audit_info` | jsonb | `migration.build_audit_info()` — user IDs + combined name notes | No `legacy_id` (uuid preserved as `id`) |
| 21 | `course_type` | text | `tags` | text[] | `ARRAY[TRIM(course_type)]` when non-empty; else `NULL` | Derived from course_type |

**SAC columns not migrated:** `reference_id`, `reference_uuid` — not referenced in migration script.

**Post-migration changes (not from SAC column mapping):** UPDATE `document_id` for `name = 'Other'` from `document.documents` where name LIKE `%other documents%`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `training_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Training Type ID Mapping
**Output columns**: `legacy_id, new_id`

```sql
CREATE TEMP TABLE training_type_id_mapping AS
SELECT id AS legacy_id, id AS new_id
FROM crewing.training_type;
```

### 2. Document ID Mapping
**Purpose**: Get count of traini
**Output columns**: `document_identifier, document_id`

```sql
CREATE TEMP TABLE document_id_mapping AS
SELECT DISTINCT
    TRIM(d.identifier) AS document_identifier,
    d.id AS document_id
FROM document.documents d
WHERE d.identifier IS NOT NULL
  AND TRIM(d.identifier) <> '';
```

Full migration context: `04-migration-scripts/master/training_master_migration.sql`

## Validation

- Run `05-validation/master/training_master_validation.sql` if available
- Run `06-rollback/master/training_master_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
