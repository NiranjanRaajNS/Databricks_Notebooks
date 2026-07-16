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

- This migration creates:
- Migrates debrief_stage_forms from synergy_master.public.debrief_stage_forms to smac_master_migration.crewing.debriefing_stage_forms. Junction table linking debriefing stage applicability records to form definitions. Maps debriefing_stage_applicability_id (uuid) via migration.table_mappings (debriefing_stage_applicability). Maps form_definition_id (uuid) via migration.table_mappings (form_definitions). Maps assigned_to_user_type based on stage_type from debriefing_stages (Reviewer=0, Appraisee=1, Manager=2). Maps form_mode from stage_mode in debriefing_stage_applicability. Maps status based on deleted_at (NULL=0 Active, NOT NULL=3 Deleted). Uses standardized SMAC audit_info structure. Requires debriefing_stage_applicability and form_definitions tables to be migrated first.

## Special Considerations

- Script truncates target table(s) before insert (full reload): `crewing.debriefing_stage_applicability`, `crewing.debriefing_stage_forms`.
- Orchestration dependencies: `debriefing_stage_applicability`, `form_definitions`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 7

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `form_type_id_mapping` | FK lookup | `form_type_id` | - | - |
| `rank_identifier_mapping` | FK lookup | `legacy_seafarer_rank_id`, `new_rank_id` | - | - |
| `template_to_stage_mapping` | FK lookup | `DISTINCT ON (dtr.seafarer_rank_id, dtr.template_name) dtr.se`, `dtr.template_name`, `ads.stage_id`, `ads.stage_name`, `ads.stage_level`, `ads.is_mandatory`, `ads.stage_mode_integer` | - | - |
| `fdl_roles_lookup` | FK lookup | `role_uuid`, `role_name`, `role_name_upper`, `role_name_lower`, `role_name_normalized_upper`, `role_name_normalized_lower`, `fr.fdl_department_id` | - | - |
| `qhse_manager_to_group_head_mapping` | Create lookup table for form_definitio | `group_head_role_uuid`, `group_head_role_name` | - | - |
| `rank_identifier_mapping_for_roles` | FK lookup | `legacy_seafarer_rank_id`, `new_rank_id` | - | - |
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

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | template_name, id | - | id | - | DISTINCT ON (TRIM(legacy_data.template_name)) COALESCE(legacy_data.id, gen_random_uuid()) as id | DISTINCT ON (TRIM(legacy_data.template_name)) COALESCE(legacy_data.id, gen_random_uuid()) |
| 2 | template_name | - | code | - | UPPER(REGEXP_REPLACE(TRIM(legacy_data.template_name), '[^A-Za-z0-9]', '_', 'g')) as code | UPPER(REGEXP_REPLACE(TRIM(legacy_data.template_name), '[^A-Za-z0-9]', '_', 'g')) |
| 3 | template_name | - | name | - | TRIM(legacy_data.template_name) as name | TRIM(legacy_data.template_name) |
| 4 | template_name | - | description | - | NULLIF(TRIM(legacy_data.template_name), '') as description | NULLIF(TRIM(legacy_data.template_name), '') |
| 5 | derived | - | form_type_id | - | ft_mapping.form_type_id as form_type_id | ft_mapping.form_type_id |
| 6 | template | - | form_template | - | COALESCE(legacy_data.template, '{}'::jsonb) as form_template | COALESCE(legacy_data.template, '{}'::jsonb) |
| 7 | derived | - | collaboration_level | - | 0 as collaboration_level | 0 |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | - | - | parent_id | - | NULL | NULL::uuid |
| 10 | version | - | version | - | COALESCE(legacy_data.version, 1) as version | COALESCE(legacy_data.version, 1) |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 13 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 14 | - | - | archived_at | - | NULL | NULL::timestamp |
| 15 | derived | - | audit_info | - | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... | jsonb_build_object( 'created_by', NULL, 'deleted_by', NULL, 'updated_by', NULL, 'archived_by', NULL, 'submitted_by', NULL, 'approved_at', NULL, 'approved_by', NULL, 'approval_no... |
| 16 | - | - | request_data_json | - | NULL | NULL::jsonb |
| 17 | - | - | module_id | - | NULL | NULL::uuid |
| 18 | - | - | level | - | NULL | NULL::numeric |
| 19 | - | - | tags | - | NULL | NULL::text[] |
| 20 | deleted_at, status | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.status IS NULL THEN 0 WHEN UPPER(TRIM(legacy_data.status)) = 'ACTIVE' OR TRIM(legacy_data.status) = '0' THEN... |
| 21 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 22 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 23 | - | - | report_template | - | NULL | NULL::text |

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
