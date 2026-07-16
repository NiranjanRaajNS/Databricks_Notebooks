# Table Mapping: appraisal_templates + debrief_templates → form_definitions

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: appraisal_templates + debrief_templates
- **New Database**: smac_master_migration
- **New Schema**: template
- **New Table**: form_definitions
- **Source Script**: `04-migration-scripts/master/form_definitions_migration.sql`

- **Legacy Path**: `synergy_master.public.appraisal_templates + debrief_templates`
- **New Path**: `smac_master_migration.template.form_definitions`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Appraisal Templates (`appraisal_templates` → `form_definitions`)

## Migration Notes

- Sources: `synergy_master.public.appraisal_templates` UNION ALL `debrief_templates` → `template.form_definitions`
- `COALESCE(id, gen_random_uuid())` preserves legacy UUID when present (no `resolve_target_id`)
- TRUNCATE `template.form_definitions`; clears all `form_definitions` mappings
- `form_type_id_mapping` temp table: joins `template_type` name → `template.form_types.id`
- Filter: `template_name IS NOT NULL AND TRIM(template_name) <> ''`
- `status` Case 2; `workflow_status`/`defined_by` hardcoded `0` (not constants.sql vars in INSERT)
- `tenant_id` hardcoded UUID (not `DEFAULT_TENANT_ID` psql var)
- Post-migration: SurveyJS → Form.io conversion via `migration.convert_surveyjs_to_formio()` UPDATE on all rows
- Mapping storage joins `audit_info->>'legacy_id'` (note: INSERT audit_info has no legacy_id)

## Special Considerations

- Maps template (jsonb) to form_template (jsonb, NOT NULL)
- Use DISTINCT ON (source_id) to prevent duplicate mappings
- Script performs `TRUNCATE TABLE template.form_definitions` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `form_type_id_mapping` | FK lookup | `name`, `form_type_id` | - | - |

### `form_type_id_mapping`

- **Output columns**: name, form_type_id

```sql
CREATE TEMP TABLE form_type_id_mapping AS
SELECT
    name,
    id AS form_type_id
FROM template.form_types;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `COALESCE(id, gen_random_uuid())` | Preserves legacy UUID |
| 2 | `template_name` | text | `code` | text | `UPPER(REGEXP_REPLACE(TRIM(template_name), '[^A-Za-z0-9]', '_', 'g'))` | NOT NULL |
| 3 | `template_name` | text | `name` | text | `TRIM(template_name)` | NOT NULL |
| 4 | `template_name` | text | `description` | text | `NULLIF(TRIM(template_name), '')` |  |
| 5 | `template_type` | text | `form_type_id` | uuid | Lookup via `form_type_id_mapping` on `TRIM(template_type)`; fallback zero-UUID | NOT NULL |
| 6 | `template` | jsonb | `form_template` | jsonb | `COALESCE(template, '{}'::jsonb)`; post-migration converted to Form.io | NOT NULL |
| 7 | `—` | — | `collaboration_level` | integer | Hardcoded `0` |  |
| 8 | `—` | — | `tenant_id` | uuid | Hardcoded tenant UUID in script | Not using psql var |
| 9 | `—` | — | `parent_id` | uuid | `NULL` |  |
| 10 | `version` | integer | `version` | integer | `COALESCE(version, 1)` |  |
| 11 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` |  |
| 12 | `updated_at, created_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, created_at, NOW())` |  |
| 13 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy |  |
| 14 | `—` | — | `archived_at` | timestamp | `NULL` |  |
| 15 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` |  |
| 16 | `—` | — | `request_data_json` | jsonb | `NULL` |  |
| 17 | `—` | — | `module_id` | uuid | `NULL` |  |
| 18 | `—` | — | `level` | numeric | `NULL` |  |
| 19 | `—` | — | `tags` | text[] | `NULL` |  |
| 20 | `deleted_at, status` | timestamp, text | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 |  |
| 21 | `—` | — | `workflow_status` | integer | Hardcoded `0` (Draft) |  |
| 22 | `—` | — | `defined_by` | integer | Hardcoded `0` (Global) |  |
| 23 | `—` | — | `report_template` | text | `NULL` |  |

**SAC columns not migrated:** `applicable_role_ids`, `applicable_rank_ids`, `seafarer_rank_id`, `source_table` (internal UNION label).

**Post-migration update:** `form_template` converted from SurveyJS to Form.io format.
## Foreign Key Dependencies

### Prerequisites (from source script)

- `form_types`
- `template.form_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Form Type ID Mapping
**Output columns**: `name, form_type_id`

```sql
CREATE TEMP TABLE form_type_id_mapping AS
SELECT
    name,
    id AS form_type_id
FROM template.form_types;
```

Full migration context: `04-migration-scripts/master/form_definitions_migration.sql`

## Validation

- Run `05-validation/master/form_definitions_validation.sql` if available
- Run `06-rollback/master/form_definitions_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
