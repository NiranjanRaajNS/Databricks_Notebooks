# Table Mapping: debrief_templates → debriefing_stage_forms

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: debrief_templates
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: debriefing_stage_forms
- **Source Script**: `04-migration-scripts/master/debriefing_stage_forms_migration.sql`

- **Legacy Path**: `synergy_master.public.debrief_templates`
- **New Path**: `smac_master_migration.crewing.debriefing_stage_forms`

## Business Key

- **Composite Key**: (`debriefing_stage_applicability_id`, `form_definition_id`)
- **Source (orchestration)**: Debriefing Stage Forms (`debrief_templates` → `debriefing_stage_forms`)

## Migration Notes

- Multi-part migration from `synergy_master.public.debrief_templates`
- Part 1: creates `template.form_definitions` for unique template names
- Part 2: creates `debriefing_stage_applicability` (rank Ã— vessel_type Ã— stage)
- Part 3: creates `debriefing_stage_forms` linking applicability to form definitions
- Part 4: UPDATE `assigned_to_position_id` from `applicable_role_ids` via FDL role matching
- Requires debriefing_stages, form_definitions, form_types, ranks, categories migrated first


## Special Considerations

- Script truncates target table(s) before insert (full reload): `crewing.debriefing_stage_applicability`, `crewing.debriefing_stage_forms`.
- Orchestration dependencies: `debriefing_stage_applicability`, `form_definitions`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 14

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `form_type_id_mapping` | FK lookup | `form_type_id` | - | - |
| `all_vessel_types` | Vessel category ID mappings | `legacy_vessel_type_id`, `new_vessel_type_id` | `migration.table_mappings` (target_table=categories) | - |
| `debrief_templates_with_ranks` | SAC debrief templates with rank | `seafarer_rank_id`, `template_name` | - | `synergy_master` |
| `rank_identifier_mapping` | FK lookup | `legacy_seafarer_rank_id`, `new_rank_id` | - | - |
| `all_debriefing_stages` | Active debriefing stage definitions | `stage_id`, `stage_name`, `stage_level`, `is_mandatory`, `stage_mode_integer` | - | - |
| `template_to_stage_mapping` | Template to stage join | `seafarer_rank_id`, `template_name`, `stage_id`, stage metadata | - | - |
| `debriefing_form_definitions` | Form definitions created in Part 1 | form definition fields | - | - |
| `fdl_roles_lookup` | FK lookup | `role_uuid`, `role_name`, normalized name variants, `fdl_department_id` | - | - |
| `cms_fdl_department` | CMS department for role matching | `department_id` | - | - |
| `qhse_manager_to_group_head_mapping` | Group Head role for form assignment | `group_head_role_uuid`, `group_head_role_name` | - | - |
| `debrief_templates_with_rank_roles` | Templates with resolved rank roles | template + rank role fields | - | - |
| `rank_identifier_mapping_for_roles` | FK lookup | `legacy_seafarer_rank_id`, `new_rank_id` | - | - |
| `rank_role_matches` | Rank to FDL role matches | rank and role match fields | - | - |
| `rank_role_mapping` | Map seafarer_rank_id to new rank_id (same as Part 2) | `rank_id`, `template_name`, `matched_role_uuids` | - | - |

### `form_type_id_mapping`

- **Output columns**: form_type_id

```sql
CREATE TEMP TABLE form_type_id_mapping AS
SELECT
    id AS form_type_id
FROM template.form_types
WHERE code = 'DEBRIEFING';
```

### `rank_identifier_mapping`

- **Output columns**: legacy_seafarer_rank_id, new_rank_id

```sql
CREATE TEMP TABLE rank_identifier_mapping AS
SELECT DISTINCT ON (r.id)
    r.id AS legacy_seafarer_rank_id,
    r.id AS new_rank_id
FROM public.ranks r;
```

### `template_to_stage_mapping`

- **Output columns**: DISTINCT ON (dtr.seafarer_rank_id, dtr.template_name) dtr.se, dtr.template_name, ads.stage_id, ads.stage_name, ads.stage_level, ads.is_mandatory, ads.stage_mode_integer

```sql
CREATE TEMP TABLE template_to_stage_mapping AS
SELECT DISTINCT ON (dtr.seafarer_rank_id, dtr.template_name)
    dtr.seafarer_rank_id,
    dtr.template_name,
    ads.stage_id,
    ads.stage_name,
    ads.stage_level,
    ads.is_mandatory,
    ads.stage_mode_integer
FROM debrief_templates_with_ranks dtr
JOIN all_debriefing_stages ads ON
    UPPER(TRIM(ads.stage_name)) = UPPER(TRIM(dtr.template_name))
ORDER BY dtr.seafarer_rank_id, dtr.template_name, ads.stage_level;
```

### `fdl_roles_lookup`

- **Output columns**: role_uuid, role_name, role_name_upper, role_name_lower, role_name_normalized_upper, role_name_normalized_lower, fr.fdl_department_id

```sql
CREATE TEMP TABLE fdl_roles_lookup AS
SELECT
    fr.id AS role_uuid,
    TRIM(fr.name) AS role_name,
    UPPER(TRIM(fr.name)) AS role_name_upper,
    LOWER(TRIM(fr.name)) AS role_name_lower,
    UPPER(REPLACE(TRIM(fr.name), '_', ' ')) AS role_name_normalized_upper,
    LOWER(REPLACE(TRIM(fr.name), '_', ' ')) AS role_name_normalized_lower,
    fr.fdl_department_id
FROM vessel.fdl_roles fr
WHERE fr.status = 0
  AND fr.name IS NOT NULL
  AND TRIM(fr.name) != '';
```

### `qhse_manager_to_group_head_mapping`

- **Purpose**: Create lookup table for form_definitio
- **Output columns**: group_head_role_uuid, group_head_role_name

```sql
CREATE TEMP TABLE qhse_manager_to_group_head_mapping AS
SELECT
    fr.role_uuid AS group_head_role_uuid,
    fr.role_name AS group_head_role_name
FROM fdl_roles_lookup fr
JOIN cms_fdl_department cfd ON cfd.department_id = fr.fdl_department_id
WHERE fr.role_name_upper = 'GROUP HEAD'
LIMIT 1;
```

### `rank_identifier_mapping_for_roles`

- **Output columns**: legacy_seafarer_rank_id, new_rank_id

```sql
CREATE TEMP TABLE IF NOT EXISTS rank_identifier_mapping_for_roles AS
SELECT DISTINCT ON (r.id)
    r.id AS legacy_seafarer_rank_id,
    r.id AS new_rank_id
FROM public.ranks r;
```

### `rank_role_mapping`

- **Purpose**: Map seafarer_rank_id to new rank_id (same as Part 2)
- **Output columns**: rank_id, template_name, matched_role_uuids

```sql
CREATE TEMP TABLE rank_role_mapping AS
SELECT
    rank_id,
    template_name,
    ARRAY_AGG(role_uuid ORDER BY source_role_order) AS matched_role_uuids
FROM rank_role_matches
WHERE role_uuid IS NOT NULL
GROUP BY rank_id, template_name;
```

## Column Mapping| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | — | — | `id` | uuid | `gen_random_uuid()` | No direct SAC row; synthetic per applicability+form combo |
| 2 | — | — | `debriefing_stage_applicability_id` | uuid | From Part 2 `debriefing_stage_applicability.id` | Derived from rank+vessel+stage |
| 3 | `template_name` | text | `form_definition_id` | uuid | Match stage name to `form_definitions.name` (DEBRIEFING type) | Via `debriefing_form_definitions` lookup |
| 4 | `template_name` | text | `form_name` | text | From matched `form_definitions.name` | |
| 5 | — | — | `assigned_to_user_type` | integer | Map `debriefing_stages.stage_type`: Reviewerâ†’0, Appraiseeâ†’1, Managerâ†’2 | From joined stage |
| 6 | `applicable_role_ids` | text[] | `assigned_to_position_id` | uuid[] | Part 4 UPDATE: match role names to `vessel.fdl_roles` UUIDs by rank+template | Initially NULL; updated post-insert |
| 7 | — | — | `is_required` | boolean | Hardcoded `true` | |
| 8 | — | — | `is_repeatable` | boolean | Hardcoded `false` | |
| 9 | — | — | `form_mode` | integer | Copy from `debriefing_stage_applicability.stage_mode` | |
| 10 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 11 | — | — | `parent_id` | uuid | `NULL` | |
| 12 | — | — | `level` | numeric | Hardcoded `0` | |
| 13 | — | — | `version` | integer | Hardcoded `1` | |
| 14 | — | — | `created_at` | timestamp without time zone | `NOW()` | |
| 15 | — | — | `updated_at` | timestamp without time zone | `NULL` initially; set on Part 4 UPDATE | |
| 16 | — | — | `deleted_at` | timestamp without time zone | `NULL` | |
| 17 | — | — | `archived_at` | timestamp without time zone | `NULL` | |
| 18 | — | — | `audit_info` | jsonb | Empty SMAC audit structure (all NULL) | |
| 19 | — | — | `tags` | text[] | Empty array `ARRAY[]::text[]` | |
| 20 | — | — | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | |
| 21 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 22 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 23 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |



**SAC columns used indirectly:** `template_name`, `seafarer_rank_id`, `applicable_role_ids` — drive Parts 1–4 but do not map 1:1 to `debriefing_stage_forms` rows.

**Related Part 1 mappings (form_definitions):** `id`, `template_name`, `template`, `status`, `deleted_at`, `version`, `created_at`, `updated_at` from `debrief_templates`.


## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.debriefing_stage_applicability`
- `crewing.debriefing_stages`
- `debriefing_stage_applicability`
- `debriefing_stages`
- `form_definitions`
- `form_types`
- `template.form_definitions`
- `template.form_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Form Type ID Mapping
**Output columns**: `form_type_id`

```sql
CREATE TEMP TABLE form_type_id_mapping AS
SELECT
    id AS form_type_id
FROM template.form_types
WHERE code = 'DEBRIEFING';
```

### 2. Rank Identifier ID Mapping
**Output columns**: `legacy_seafarer_rank_id, new_rank_id`

```sql
CREATE TEMP TABLE rank_identifier_mapping AS
SELECT DISTINCT ON (r.id)
    r.id AS legacy_seafarer_rank_id,
    r.id AS new_rank_id
FROM public.ranks r;
```

### 3. Template To Stage ID Mapping
**Output columns**: `DISTINCT ON (dtr.seafarer_rank_id, dtr.template_name) dtr.se, dtr.template_name, ads.stage_id, ads.stage_name, ads.stage_level, ads.is_mandatory, ads.stage_mode_integer`

```sql
CREATE TEMP TABLE template_to_stage_mapping AS
SELECT DISTINCT ON (dtr.seafarer_rank_id, dtr.template_name)
    dtr.seafarer_rank_id,
    dtr.template_name,
    ads.stage_id,
    ads.stage_name,
    ads.stage_level,
    ads.is_mandatory,
    ads.stage_mode_integer
FROM debrief_templates_with_ranks dtr
JOIN all_debriefing_stages ads ON
    UPPER(TRIM(ads.stage_name)) = UPPER(TRIM(dtr.template_name))
ORDER BY dtr.seafarer_rank_id, dtr.template_name, ads.stage_level;
```

### 4. Fdl Roles ID Mapping
**Output columns**: `role_uuid, role_name, role_name_upper, role_name_lower, role_name_normalized_upper, role_name_normalized_lower, fr.fdl_department_id`

```sql
CREATE TEMP TABLE fdl_roles_lookup AS
SELECT
    fr.id AS role_uuid,
    TRIM(fr.name) AS role_name,
    UPPER(TRIM(fr.name)) AS role_name_upper,
    LOWER(TRIM(fr.name)) AS role_name_lower,
    UPPER(REPLACE(TRIM(fr.name), '_', ' ')) AS role_name_normalized_upper,
    LOWER(REPLACE(TRIM(fr.name), '_', ' ')) AS role_name_normalized_lower,
    fr.fdl_department_id
FROM vessel.fdl_roles fr
WHERE fr.status = 0
  AND fr.name IS NOT NULL
  AND TRIM(fr.name) != '';
```

### 5. Qhse Manager To Group Head ID Mapping
**Purpose**: Create lookup table for form_definitio
**Output columns**: `group_head_role_uuid, group_head_role_name`

```sql
CREATE TEMP TABLE qhse_manager_to_group_head_mapping AS
SELECT
    fr.role_uuid AS group_head_role_uuid,
    fr.role_name AS group_head_role_name
FROM fdl_roles_lookup fr
JOIN cms_fdl_department cfd ON cfd.department_id = fr.fdl_department_id
WHERE fr.role_name_upper = 'GROUP HEAD'
LIMIT 1;
```

### 6. Rank Identifier Mapping For Roles
**Output columns**: `legacy_seafarer_rank_id, new_rank_id`

```sql
CREATE TEMP TABLE IF NOT EXISTS rank_identifier_mapping_for_roles AS
SELECT DISTINCT ON (r.id)
    r.id AS legacy_seafarer_rank_id,
    r.id AS new_rank_id
FROM public.ranks r;
```

### 7. Rank Role ID Mapping
**Purpose**: Map seafarer_rank_id to new rank_id (same as Part 2)
**Output columns**: `rank_id, template_name, matched_role_uuids`

```sql
CREATE TEMP TABLE rank_role_mapping AS
SELECT
    rank_id,
    template_name,
    ARRAY_AGG(role_uuid ORDER BY source_role_order) AS matched_role_uuids
FROM rank_role_matches
WHERE role_uuid IS NOT NULL
GROUP BY rank_id, template_name;
```

Full migration context: `04-migration-scripts/master/debriefing_stage_forms_migration.sql`

## Validation

- Run `05-validation/master/debriefing_stage_forms_validation.sql` if available
- Run `06-rollback/master/debriefing_stage_forms_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.