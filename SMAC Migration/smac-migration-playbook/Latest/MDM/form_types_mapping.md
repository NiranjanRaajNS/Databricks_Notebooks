# Table Mapping: form_types → form_types

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: template
- **New Table**: form_types
- **Source Script**: `04-migration-scripts/master/form_types_migration.sql`

- **Legacy Path**: `synergy_master.public.appraisal_templates.template_type + debrief_templates.template_type`
- **New Path**: `smac_master_migration.template.form_types`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Form Types (from debrief_templates) (`debrief_templates` → `form_types`)

## Migration Notes

- Sources: distinct `template_type` from `appraisal_templates` + `debrief_templates` → `template.form_types`
- `gen_random_uuid()` for each distinct template_type (no legacy UUID preserved)
- TRUNCATE `template.form_types`; clears mappings
- `default_module` temp table: first module with code TEMPLATE or name ILIKE template; fallback zero-UUID
- Aggregates MIN(created_at), MAX(updated_at), MAX(deleted_at) per template_type
- Filter: `template_type IS NOT NULL AND TRIM(template_type) <> ''`
- `status` Case 1 from `deleted_at`; `workflow_status`/`defined_by` hardcoded `0`
- Mapping: source_id = `TRIM(UPPER(template_type))` joined on `ft.name`
## Special Considerations

- Use DISTINCT ON (source_id) to prevent duplicate mappings
- Script performs `TRUNCATE TABLE template.form_types` before insert (full table reload).
- Orchestration dependencies: `modules`

## ID Mappings

Intermediate lookup tables from the migration script.

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `default_module` | Resolve module_id for form_types | `id` | - | - |

### `default_module`

- **Purpose**: First module with code TEMPLATE or name ILIKE template; used for `module_id` FK
- **Output columns**: id

```sql
CREATE TEMP TABLE default_module AS
SELECT v_default_module_id as id;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `template_type` | varchar | `id` | uuid | `gen_random_uuid()` per distinct value | New UUID; not preserved |
| 2 | `template_type` | varchar | `code` | text | `UPPER(REGEXP_REPLACE(TRIM(template_type), '[^A-Za-z0-9]', '_', 'g'))` | NOT NULL |
| 3 | `template_type` | varchar | `name` | text | `TRIM(template_type)` | NOT NULL |
| 4 | `template_type` | varchar | `description` | text | `TRIM(template_type)` | Same as name |
| 5 | `—` | — | `module_id` | uuid | From `default_module` temp lookup; fallback zero-UUID | NOT NULL |
| 6 | `—` | — | `tenant_id` | uuid | Hardcoded tenant UUID in script |  |
| 7 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 8 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 9 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(MIN(created_at), NOW())` per type |  |
| 10 | `updated_at, created_at` | timestamp | `updated_at` | timestamp | `COALESCE(MAX(updated_at), created_at, NOW())` |  |
| 11 | `deleted_at` | timestamp | `deleted_at` | timestamp | `MAX(deleted_at)` per type |  |
| 12 | `—` | — | `archived_at` | timestamp | `NULL` |  |
| 13 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |
| 14 | `—` | — | `level` | numeric | `NULL` |  |
| 15 | `—` | — | `tags` | text[] | `NULL` |  |
| 16 | `deleted_at` | timestamp | `status` | integer | Case 1 — `deleted_at IS NOT NULL` → Deleted (3); else Active (0) |  |
| 17 | `—` | — | `workflow_status` | integer | Hardcoded `0` (Draft) |  |
| 18 | `—` | — | `defined_by` | integer | Hardcoded `0` (Global) |  |

**SAC columns not migrated:** All other appraisal_templates/debrief_templates columns beyond template_type and timestamps.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `modules`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/form_types_migration.sql`

## Validation

- Run `05-validation/master/form_types_validation.sql` if available
- Run `06-rollback/master/form_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
