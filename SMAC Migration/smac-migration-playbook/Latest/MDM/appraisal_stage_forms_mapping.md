# Table Mapping: appraisal_stage_forms → appraisal_stage_forms

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: appraisal_stage_forms
- **Source Script**: `04-migration-scripts/master/appraisal_stage_forms_migration.sql`

- **New Path**: `smac_master_migration.crewing.appraisal_stage_forms`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Appraisal Templates (`appraisal_templates` → `appraisal_stage_forms`)

## Migration Notes

- Multi-part migration: also inserts `template.form_definitions` and `crewing.appraisal_stage_applicability`
- Column mapping documents primary `crewing.appraisal_stage_forms` INSERT (Part 3)
- Composite source_id: `template_id || '_' || stage_applicability_id` via `migration.resolve_target_id()`
- `form_definition_id` and `stage_applicability_id` from prior migration parts / temp tables
- `form_name` derived dynamically from template name + rank (except Master/Chief Engineer and Appraisee feedback)
- Filter: `asa.status = 0`; `DISTINCT ON (asa.id)` enforces one form per applicability
- Part 4 UPDATE sets `assigned_to_position_id` from rank

## Special Considerations

- Script truncates target table(s) before insert (full reload): `crewing.appraisal_stage_applicability`, `crewing.appraisal_stage_forms`.

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 36

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `unique_appraisal_combinations` | Distinct rank/appraisal/vessel combos from SAC | `rank_id`, `appraisal_type_id`, `vessel_category_id` | - | `synergy_seafarer` |
| `matching_templates` | All SAC appraisal_templates for form generation | template fields + `seafarer_rank_id` | - | `synergy_master` |
| `inserted_rank_ids` | Tracks rank IDs inserted in Part 1 | `target_rank_id` | - | - |
| `templates_for_insertion` | Templates queued for form_definitions INSERT | template metadata | - | - |
| `all_vessel_types` | Vessel category ID mappings | `legacy_vessel_type_id`, `new_vessel_type_id` | `migration.table_mappings` (target_table=categories) | - |
| `all_appraisal_types` | Appraisal type ID mappings | `legacy_appraisal_type_id`, `new_appraisal_type_id` | `migration.table_mappings` (target_table=appraisal_types) | - |
| `final_applicability_combinations` | Rank+stage+type+vessel applicability combos | composite applicability keys | - | - |
| `applicability_with_ids` | Applicability rows with resolved UUIDs | applicability fields with ids | - | - |
| `role_name_to_fdl_role` | Map role names to vessel.fdl_roles | `role_name`, `fdl_role_id` | - | - |
| `template_to_form_definition` | Template to form_definition id link | `template_name`, `form_definition_id` | - | - |
| `stage_to_form_definitions` | Stage to form_definition mapping for Part 3 | stage fields, `form_definition_id` | - | - |
| `child_parent_rank_with_uuids` | Child/parent ranks with SMAC UUIDs | `child_rank_id`, `parent_rank_id`, rank names | - | - |
| `all_target_ranks` | All migrated target rank ids | `target_rank_id`, `rank_name` | - | - |
| `parent_form_definitions` | Parent rank form definitions for child rank clone | `parent_form_definition_id`, parent form fields | - | - |
| `parent_applicability` | Parent rank applicability records | `parent_applicability_id`, applicability fields | - | - |
| `appraisal_templates_with_rank_roles` | Templates with resolved rank roles | template + role fields | - | - |
| `rank_role_matches` | Rank to FDL role matches | `rank_id`, `role_uuid`, role name fields | - | - |
| `stage_forms_with_template` | Stage forms joined to templates | form + template fields | - | - |
| `rank_assignment_resolved` | Resolved rank assignment appraiser names | `rank_name`, appraiser name fields | - | - |
| `rank_assignment_with_uuids` | Rank assignments with FDL role UUIDs | `rank_name`, appraiser UUID fields | - | - |
| `rank_identifier_to_target` | FK lookup | `rank_identifier_uuid`, `legacy_rank_id`, `target_rank_id`, `rank_name` | `migration.table_mappings` (see SQL) | `synergy_master` |
| `template_name_stage_mapping` | FK lookup | `template_name_upper`, `stage_id`, `stage_name`, `stage_sequence`, `stage_mode` | - | `synergy_master` |
| `rank_to_stages_mapping` | FK lookup | `target_rank_id`, `stage_id`, `stage_sequence`, `stage_mode`, `template_name_upper` | - | - |
| `fdl_roles_lookup` | FK lookup | `id`, `name`, `name_upper` | - | - |
| `child_parent_rank_mapping` | FK lookup | `child_rank_name`, `parent_rank_name` | - | - |
| `child_ranks_without_templates` | Child ranks needing parent template clone | child/parent rank ids and names | `migration.table_mappings` (see SQL) | `synergy_master` |
| `child_form_definitions_mapping` | Child to parent form definition mapping | child/parent form definition ids | - | - |
| `child_applicability_mapping` | Child applicability id mapping | child rank + applicability ids | - | - |
| `fdl_roles_lookup_for_update` | FDL roles for post-insert UPDATE | role uuid and normalized name variants | - | - |
| `rank_identifier_mapping_for_roles` | FK lookup | `legacy_seafarer_rank_id`, `new_rank_id` | `migration.table_mappings` (see SQL) | `synergy_master` |
| `template_rank_role_mapping` | Template rank to role mapping | `rank_id`, `template_name`, matched role fields | - | - |
| `master_rank_lookup` | FK lookup | `rank_id`, `rank_name` | - | - |
| `manning_manager_role_lookup` | FK lookup | `role_id`, `role_name` | - | - |
| `rank_assignment_mapping` | FK lookup | `rank_name`, `appraiser_1`, `appraiser_2`, `shore` | - | - |
| `all_ranks_lookup` | FK lookup | `rank_id`, `rank_name`, `rank_name_upper` | - | - |
| `rank_parent_mapping` | FK lookup | `child_rank_name`, `parent_rank_name` | - | - |

### `rank_identifier_to_target`

- **Output columns**: rank_identifier_uuid, legacy_rank_id, target_rank_id, rank_name
- **migration.table_mappings**: target_table=ranks
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE rank_identifier_to_target AS
SELECT DISTINCT
    r.identifier as rank_identifier_uuid,
    r.id as legacy_rank_id,
    tm.target_id as target_rank_id,
    target_rank.name as rank_name
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS r(id bigint, identifier uuid)
LEFT JOIN migration.table_mappings tm ON tm.source_id = r.id::text
LEFT JOIN public.ranks target_rank ON target_rank.id = tm.target_id
WHERE tm.target_table = 'ranks'
  AND tm.target_db = current_database()
  AND tm.target_id IS NOT NULL;
```

### `template_name_stage_mapping`

- **Output columns**: template_name_upper, stage_id, stage_name, stage_sequence, stage_mode
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE template_name_stage_mapping AS
SELECT DISTINCT
    UPPER(TRIM(at.template_name)) as template_name_upper,
    ast.id as stage_id,
    ast.name as stage_name,
    CASE
        WHEN UPPER(TRIM(at.template_name)) = 'APPRAISEE FEEDBACK' THEN 2
        WHEN UPPER(TRIM(at.template_name)) = 'GENERAL FEEDBACKS' THEN 1
        WHEN UPPER(TRIM(at.template_name)) = 'MARINE SUPERINTENDENT FEEDBACK' THEN 1
        WHEN UPPER(TRIM(at.template_name)) = 'CREWING SUPERINTENDENT FEEDBACK' THEN 1
        WHEN UPPER(TRIM(at.template_name)) = 'TECHNICAL SUPERINTENDENT FEEDBACK' THEN 1
        WHEN UPPER(TRIM(at.template_name)) = 'DEBRIEFING COMMITTEE REVIEW FEEDBACK' THEN 4
        WHEN UPPER(TRIM(at.template_name)) = 'MARINE MANAGER FEEDBACK' THEN 3
        WHEN UPPER(TRIM(at.template_name)) = 'TECHNICAL MANAGER FEEDBACK' THEN 3
        WHEN UPPER(TRIM(at.template_name)) = 'REVIEWER FEEDBACK' THEN 3
        ELSE NULL
    END as stage_sequence,
    CASE
        WHEN UPPER(TRIM(at.template_name)) = 'APPRAISEE FEEDBACK' THEN 'Sequential'
        WHEN UPPER(TRIM(at.template_name)) = 'GENERAL FEEDBACKS' THEN 'Sequential'
        WHEN UPPER(TRIM(at.template_name)) = 'MARINE SUPERINTENDEN...
```

### `rank_to_stages_mapping`

- **Output columns**: DISTINCT ON (rtt.target_rank_id, tnsm.stage_id) rtt.target_r, tnsm.stage_id, tnsm.stage_sequence, tnsm.stage_mode, tnsm.template_name_upper

```sql
CREATE TEMP TABLE rank_to_stages_mapping AS
SELECT DISTINCT ON (rtt.target_rank_id, tnsm.stage_id)
    rtt.target_rank_id,
    tnsm.stage_id,
    tnsm.stage_sequence,
    tnsm.stage_mode,
    tnsm.template_name_upper
FROM matching_templates mt
JOIN rank_identifier_to_target rtt ON rtt.rank_identifier_uuid = mt.seafarer_rank_id
JOIN template_name_stage_mapping tnsm ON UPPER(TRIM(mt.template_name)) = tnsm.template_name_upper
WHERE rtt.target_rank_id IS NOT NULL
  AND mt.template_name IS NOT NULL
  AND TRIM(mt.template_name) != ''
  AND tnsm.stage_id IS NOT NULL
  AND mt.deleted_at IS NULL
  AND UPPER(TRIM(mt.status)) = 'ACTIVE'
ORDER BY rtt.target_rank_id, tnsm.stage_id, tnsm.stage_sequence, tnsm.stage_mode;
```

### `fdl_roles_lookup`

- **Output columns**: id, name, name_upper

```sql
CREATE TEMP TABLE fdl_roles_lookup AS
SELECT
    id,
    name,
    UPPER(TRIM(name)) as name_upper
FROM vessel.fdl_roles
WHERE status = 0;
```

### `child_parent_rank_mapping`

- **Output columns**: child_rank_name, parent_rank_name

```sql
CREATE TEMP TABLE child_parent_rank_mapping AS
SELECT
    child_rank_name,
    parent_rank_name
FROM (VALUES
    ('Junior Third Officer', 'Third Officer'),
    ('Junior Fourth Engineer', 'Fourth Engineer'),
    ('Electrical Cadet', 'Trainee Electrical Officer'),
    ('Oiler', 'Motorman'),
    ('Trainee Fitter', 'Fitter'),
    ('Trainee Seaman', 'Ordinary Seaman'),
    ('Trainee Wiper', 'Wiper'),
    ('Trainee General Steward', 'General Steward')
) AS parent_mapping(child_rank_name, parent_rank_name);
```

### `child_ranks_without_templates`

- **Purpose**: Map role names to fdl_roles.id (for app
- **Output columns**: DISTINCT cprwu.child_rank_id, cprwu.child_rank_name, cprwu.parent_rank_id, cprwu.parent_rank_name
- **migration.table_mappings**: target_table=ranks
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE child_ranks_without_templates AS
SELECT DISTINCT
    cprwu.child_rank_id,
    cprwu.child_rank_name,
    cprwu.parent_rank_id,
    cprwu.parent_rank_name
FROM child_parent_rank_with_uuids cprwu
WHERE NOT EXISTS (

    SELECT 1
    FROM dblink('synergy_master',
        'SELECT DISTINCT seafarer_rank_id
         FROM public.appraisal_templates
         WHERE seafarer_rank_id IS NOT NULL'
    ) AS legacy_templates(seafarer_rank_id uuid)
    JOIN dblink('synergy_master',
        'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
    ) AS legacy_ranks(id bigint, identifier uuid) ON legacy_ranks.identifier = legacy_templates.seafarer_rank_id
    JOIN migration.table_mappings tm ON tm.source_id = legacy_ranks.id::text
    WHERE tm.target_table = 'ranks'
      AND tm.target_db = current_database()
      AND tm.target_id = cprwu.child_rank_id
);
```

### `child_form_definitions_mapping`

- **Output columns**: DISTINCT pa.child_rank_id, cprwu.child_rank_name, pa.parent_rank_id, cprwu.parent_rank_name, parent_form_definition_id, child_form_definition_id, parent_form_name, pa.parent_applicability_id, pa.stage_id, pa.vessel_type_id, pa.appraisal_type_id, template_name_upper

```sql
CREATE TEMP TABLE child_form_definitions_mapping AS
SELECT DISTINCT
    pa.child_rank_id,
    cprwu.child_rank_name,
    pa.parent_rank_id,
    cprwu.parent_rank_name,
    asf.form_definition_id as parent_form_definition_id,
    CASE
        WHEN UPPER(TRIM(fd.name)) = 'APPRAISEE FEEDBACK' THEN asf.form_definition_id
        ELSE migration.resolve_target_id(
            'synergy_master'::VARCHAR(100),
            'public'::VARCHAR(100),
            'appraisal_templates'::VARCHAR(100),
            ('CHILD_RANK_' || pa.child_rank_id::text || '_' || asf.form_definition_id::text)::text,
            current_database()::text::VARCHAR(100),
            'template'::VARCHAR(100),
            'form_definitions'::VARCHAR(100),
            NULL::uuid,
            current_setting('migration.is_repeated_migration_form_definitions')::boolean
        )
    END as child_form_definition_id,
    fd.name as parent_form_name,
    pa.parent_applicability_id,
    pa.stage_id,
    pa.vessel_type_id,
    pa.appraisal_type_id,
    COALESCE(tnsm.template_name_upper, 'UNKNOWN') as template_name_upper
FROM parent_applicability pa
JOIN child_ranks_without_templates cprwu ON
    cprwu.child_rank_id = pa.child...
```

### `child_applicability_mapping`

- **Output columns**: DISTINCT pa.child_rank_id, pa.vessel_type_id, pa.appraisal_type_id, pa.stage_id, child_applicability_id

```sql
CREATE TEMP TABLE child_applicability_mapping AS
SELECT DISTINCT
    pa.child_rank_id,
    pa.vessel_type_id,
    pa.appraisal_type_id,
    pa.stage_id,
    asa.id as child_applicability_id
FROM parent_applicability pa
JOIN crewing.appraisal_stage_applicability asa ON
    asa.rank_id = pa.child_rank_id
    AND asa.vessel_type_id = pa.vessel_type_id
    AND asa.appraisal_type_id = pa.appraisal_type_id
    AND asa.stage_id = pa.stage_id
WHERE asa.status = 0;
```

### `fdl_roles_lookup_for_update`

- **Output columns**: role_uuid, role_name, role_name_upper, role_name_lower, role_name_normalized_upper, role_name_normalized_lower

```sql
CREATE TEMP TABLE fdl_roles_lookup_for_update AS
SELECT
    id AS role_uuid,
    TRIM(name) AS role_name,
    UPPER(TRIM(name)) AS role_name_upper,
    LOWER(TRIM(name)) AS role_name_lower,
    UPPER(REPLACE(TRIM(name), '_', ' ')) AS role_name_normalized_upper,
    LOWER(REPLACE(TRIM(name), '_', ' ')) AS role_name_normalized_lower
FROM vessel.fdl_roles
WHERE status = 0
  AND name IS NOT NULL
  AND TRIM(name) != '';
```

### `rank_identifier_mapping_for_roles`

- **Output columns**: legacy_seafarer_rank_id, new_rank_id
- **migration.table_mappings**: target_table=ranks
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE rank_identifier_mapping_for_roles AS
SELECT DISTINCT
    r.identifier AS legacy_seafarer_rank_id,
    tm.target_id AS new_rank_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS r(id bigint, identifier uuid)
LEFT JOIN migration.table_mappings tm ON tm.source_id = r.id::text
LEFT JOIN public.ranks target_rank ON target_rank.id = tm.target_id
WHERE tm.target_table = 'ranks'
  AND tm.target_db = current_database()
  AND tm.target_id IS NOT NULL
  AND r.identifier IS NOT NULL;
```

### `template_rank_role_mapping`

- **Output columns**: DISTINCT ON (rank_id, template_name) rank_id, template_name, matched_role_uuid, source_role_name, matched_role_name

```sql
CREATE TEMP TABLE template_rank_role_mapping AS
SELECT DISTINCT ON (rank_id, template_name)
    rank_id,
    template_name,
    role_uuid AS matched_role_uuid,
    source_role_name,
    matched_role_name
FROM rank_role_matches
ORDER BY rank_id, template_name, match_priority, LENGTH(matched_role_name) DESC, role_uuid;
```

### `master_rank_lookup`

- **Output columns**: rank_id, rank_name

```sql
CREATE TEMP TABLE master_rank_lookup AS
SELECT
    id as rank_id,
    name as rank_name
FROM public.ranks
WHERE UPPER(TRIM(name)) = 'MASTER'
  AND status = 0
LIMIT 1;
```

### `manning_manager_role_lookup`

- **Output columns**: role_id, role_name

```sql
CREATE TEMP TABLE manning_manager_role_lookup AS
SELECT
    fr.id as role_id,
    fr.name as role_name
FROM vessel.fdl_roles fr
JOIN vessel.fdl_departments fd ON fd.id = fr.fdl_department_id
WHERE UPPER(TRIM(fd.name)) = 'MANNING FDL'
  AND UPPER(TRIM(fr.name)) = 'FLEET MANAGER'
  AND fr.status = 0
LIMIT 1;
```

### `rank_assignment_mapping`

- **Output columns**: rank_name, appraiser_1, appraiser_2, shore

```sql
CREATE TEMP TABLE rank_assignment_mapping AS
SELECT
    rank_name,
    appraiser_1,
    appraiser_2,
    shore
FROM (VALUES

    ('Master', NULL, NULL, NULL),
    ('Chief Officer', 'Master', NULL, 'Manning Manager'),
    ('Second Officer', 'Master', NULL, 'Manning Manager'),
    ('Third Officer', 'Master', NULL, 'Manning Manager'),
    ('Junior Third Officer', 'Master', NULL, 'Manning Manager'),
    ('Deck Cadet', 'Chief Officer', 'Master', 'Manning Manager'),
    ('Chief Engineer', NULL, NULL, NULL),
    ('Second Engineer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Third Engineer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Gas Engineer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Fourth Engineer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Junior Fourth Engineer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Electro Technical Officer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Electrical Officer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Engine Cadet', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Trainee Electrical Officer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Electrical C...
```

### `all_ranks_lookup`

- **Output columns**: rank_id, rank_name, rank_name_upper

```sql
CREATE TEMP TABLE all_ranks_lookup AS
SELECT
    id as rank_id,
    name as rank_name,
    UPPER(TRIM(name)) as rank_name_upper
FROM public.ranks
WHERE status = 0;
```

### `rank_parent_mapping`

- **Output columns**: child_rank_name, parent_rank_name

```sql
CREATE TEMP TABLE rank_parent_mapping AS
SELECT
    child_rank_name,
    parent_rank_name
FROM (VALUES
    ('Junior Third Officer', 'Third Officer'),
    ('Junior Fourth Engineer', 'Fourth Engineer'),
    ('Electrical Cadet', 'Trainee Electrical Officer'),
    ('Oiler', 'Motorman'),
    ('Trainee Fitter', 'Fitter'),
    ('Trainee Seaman', 'Ordinary Seaman'),
    ('Trainee Wiper', 'Wiper'),
    ('Trainee General Steward', 'General Steward')
) AS parent_mapping(child_rank_name, parent_rank_name);
```

## Column Mapping| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `appraisal_templates.id, appraisal_stage_applicability.id` | uuid, uuid | `id` | uuid | `migration.resolve_target_id()` — composite source_id = `template_id || '_' || asa.id`; `p_target_id = NULL` | Idempotent UUID from composite key |
| 2 | `—` | — | `stage_applicability_id` | uuid | From `crewing.appraisal_stage_applicability.id` (Part 2) | FK to applicability record |
| 3 | `—` | — | `form_definition_id` | uuid | From `stage_to_form_definitions` temp table (Part 1) | FK to `template.form_definitions` |
| 4 | `appraisal_templates.template_name, ranks.name` | text, text | `form_name` | text | Dynamic: append rank for non-Master/Chief Engineer; Appraisee feedback uses base name only | Derived from template + rank |
| 5 | `—` | — | `assigned_to_user_type` | text | `'Seafarer'` for Appraisee feedback; else `'Shore'` | From `stage_to_form_definitions` |
| 6 | `—` | — | `assigned_to_position_id` | uuid | `NULL` initially; Part 4 UPDATE from rank | Post-migration update |
| 7 | `—` | — | `is_required` | boolean | From `appraisal_stage_applicability.is_mandatory` | Direct mapping |
| 8 | `—` | — | `is_repeatable` | boolean | Hardcoded `true` | SMAC default |
| 9 | `—` | — | `form_mode` | text | From `appraisal_stage_applicability.stage_mode` | Direct mapping |
| 10 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 11 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 12 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 13 | `—` | — | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Filter: only active applicability rows |
| 14 | `—` | — | `created_at` | timestamp without time zone | `NOW()` | No created_at in source join |
| 15 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | No SAC audit columns |
| 16 | `—` | — | `tags` | text[] | Empty array `ARRAY[]::text[]` | Not populated from SAC |
| 17 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 18 | `—` | — | `level` | numeric | Hardcoded `0` | No level in SAC |



**SAC columns not migrated (direct):** `appraisal_templates.template` JSON, `applicable_role_ids`, raw `appraisals` rows — handled in Parts 1–2.

**SMAC tables also populated:** `template.form_definitions`, `crewing.appraisal_stage_applicability` (see migration script Parts 1–2).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing.appraisal_stages`
- `form_types`
- `template.form_types`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Rank Identifier ID Mapping
**Output columns**: `rank_identifier_uuid, legacy_rank_id, target_rank_id, rank_name`
**migration.table_mappings**: `target_table='ranks'`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE rank_identifier_to_target AS
SELECT DISTINCT
    r.identifier as rank_identifier_uuid,
    r.id as legacy_rank_id,
    tm.target_id as target_rank_id,
    target_rank.name as rank_name
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS r(id bigint, identifier uuid)
LEFT JOIN migration.table_mappings tm ON tm.source_id = r.id::text
LEFT JOIN public.ranks target_rank ON target_rank.id = tm.target_id
WHERE tm.target_table = 'ranks'
  AND tm.target_db = current_database()
  AND tm.target_id IS NOT NULL;
```

### 2. Template Name Stage ID Mapping
**Output columns**: `template_name_upper, stage_id, stage_name, stage_sequence, stage_mode`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE template_name_stage_mapping AS
SELECT DISTINCT
    UPPER(TRIM(at.template_name)) as template_name_upper,
    ast.id as stage_id,
    ast.name as stage_name,
    CASE
        WHEN UPPER(TRIM(at.template_name)) = 'APPRAISEE FEEDBACK' THEN 2
        WHEN UPPER(TRIM(at.template_name)) = 'GENERAL FEEDBACKS' THEN 1
        WHEN UPPER(TRIM(at.template_name)) = 'MARINE SUPERINTENDENT FEEDBACK' THEN 1
        WHEN UPPER(TRIM(at.template_name)) = 'CREWING SUPERINTENDENT FEEDBACK' THEN 1
        WHEN UPPER(TRIM(at.template_name)) = 'TECHNICAL SUPERINTENDENT FEEDBACK' THEN 1
        WHEN UPPER(TRIM(at.template_name)) = 'DEBRIEFING COMMITTEE REVIEW FEEDBACK' THEN 4
        WHEN UPPER(TRIM(at.template_name)) = 'MARINE MANAGER FEEDBACK' THEN 3
        WHEN UPPER(TRIM(at.template_name)) = 'TECHNICAL MANAGER FEEDBACK' THEN 3
        WHEN UPPER(TRIM(at.template_name)) = 'REVIEWER FEEDBACK' THEN 3
        ELSE NULL
    END as stage_sequence,
    CASE
        WHEN UPPER(TRIM(at.template_name)) = 'APPRAISEE FEEDBACK' THEN 'Sequential'
        WHEN UPPER(TRIM(at.template_name)) = 'GENERAL FEEDBACKS' THEN 'Sequential'
        WHEN UPPER(TRIM(at.template_name)) = 'MARINE SUPERINTENDENT FEEDBACK' THEN 'Parallel'
        WHEN UPPER(TRIM(at.template_name)) = 'CREWING SUPERINTENDENT FEEDBACK' THEN 'Parallel'
        WHEN UPPER(TRIM(at.template_name)) = 'TECHNICAL SUPERINTENDENT FEEDBACK' THEN 'Parallel'
        WHEN UPPER(TRIM(at.template_name)) = 'DEBRIEFING COMMITTEE REVIEW FEEDBACK' THEN 'Sequential'
        WHEN UPPER(TRIM(at.template_name)) = 'MARINE MANAGER FEEDBACK' THEN 'Sequential'
        WHEN UPPER(TRIM(at.template_name)) = 'TECHNICAL MANAGER FEEDBACK' THEN 'Sequential'
        WHEN UPPER(TRIM(at.template_name)) = 'REVIEWER FEEDBACK' THEN 'Sequential'
        ELSE NULL
    END as stage_mode
FROM dblink('synergy_master',
    'SELECT DISTINCT template_name FROM public.appraisal_templates WHERE template_name IS NOT NULL'
) AS at(template_name text)
JOIN crewing.appraisal_stages ast ON (

    (UPPER(TRIM(at.template_name)) = 'APPRAISEE FEEDBACK' AND UPPER(TRIM(ast.name)) = 'APPRAISEE ACKNOWLEDGEMENT')
    OR

    (UPPER(TRIM(at.template_name)) = 'GENERAL FEEDBACKS' AND UPPER(TRIM(ast.name)) = 'APPRAISER FEEDBACK')
    OR

    (UPPER(TRIM(at.template_name)) = 'DEBRIEFING COMMITTEE REVIEW FEEDBACK' AND UPPER(TRIM(ast.name)) = 'MANAGER FEEDBACK')
    OR

    (UPPER(TRIM(at.template_name)) != 'APPRAISEE FEEDBACK'
     AND UPPER(TRIM(at.template_name)) != 'GENERAL FEEDBACKS'
     AND UPPER(TRIM(at.template_name)) != 'DEBRIEFING COMMITTEE REVIEW FEEDBACK'
     AND UPPER(TRIM(ast.name)) = UPPER(TRIM(at.template_name)))
)
WHERE ast.status = 0
  AND at.template_name IS NOT NULL
  AND TRIM(at.template_name) != '';
```

### 3. Rank To Stages ID Mapping
**Output columns**: `DISTINCT ON (rtt.target_rank_id, tnsm.stage_id) rtt.target_r, tnsm.stage_id, tnsm.stage_sequence, tnsm.stage_mode, tnsm.template_name_upper`

```sql
CREATE TEMP TABLE rank_to_stages_mapping AS
SELECT DISTINCT ON (rtt.target_rank_id, tnsm.stage_id)
    rtt.target_rank_id,
    tnsm.stage_id,
    tnsm.stage_sequence,
    tnsm.stage_mode,
    tnsm.template_name_upper
FROM matching_templates mt
JOIN rank_identifier_to_target rtt ON rtt.rank_identifier_uuid = mt.seafarer_rank_id
JOIN template_name_stage_mapping tnsm ON UPPER(TRIM(mt.template_name)) = tnsm.template_name_upper
WHERE rtt.target_rank_id IS NOT NULL
  AND mt.template_name IS NOT NULL
  AND TRIM(mt.template_name) != ''
  AND tnsm.stage_id IS NOT NULL
  AND mt.deleted_at IS NULL
  AND UPPER(TRIM(mt.status)) = 'ACTIVE'
ORDER BY rtt.target_rank_id, tnsm.stage_id, tnsm.stage_sequence, tnsm.stage_mode;
```

### 4. Fdl Roles ID Mapping
**Output columns**: `id, name, name_upper`

```sql
CREATE TEMP TABLE fdl_roles_lookup AS
SELECT
    id,
    name,
    UPPER(TRIM(name)) as name_upper
FROM vessel.fdl_roles
WHERE status = 0;
```

### 5. Child Parent Rank ID Mapping
**Output columns**: `child_rank_name, parent_rank_name`

```sql
CREATE TEMP TABLE child_parent_rank_mapping AS
SELECT
    child_rank_name,
    parent_rank_name
FROM (VALUES
    ('Junior Third Officer', 'Third Officer'),
    ('Junior Fourth Engineer', 'Fourth Engineer'),
    ('Electrical Cadet', 'Trainee Electrical Officer'),
    ('Oiler', 'Motorman'),
    ('Trainee Fitter', 'Fitter'),
    ('Trainee Seaman', 'Ordinary Seaman'),
    ('Trainee Wiper', 'Wiper'),
    ('Trainee General Steward', 'General Steward')
) AS parent_mapping(child_rank_name, parent_rank_name);
```

### 6. Child Ranks Without Templates ID Mapping
**Purpose**: Map role names to fdl_roles.id (for app
**Output columns**: `DISTINCT cprwu.child_rank_id, cprwu.child_rank_name, cprwu.parent_rank_id, cprwu.parent_rank_name`
**migration.table_mappings**: `target_table='ranks'`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE child_ranks_without_templates AS
SELECT DISTINCT
    cprwu.child_rank_id,
    cprwu.child_rank_name,
    cprwu.parent_rank_id,
    cprwu.parent_rank_name
FROM child_parent_rank_with_uuids cprwu
WHERE NOT EXISTS (

    SELECT 1
    FROM dblink('synergy_master',
        'SELECT DISTINCT seafarer_rank_id
         FROM public.appraisal_templates
         WHERE seafarer_rank_id IS NOT NULL'
    ) AS legacy_templates(seafarer_rank_id uuid)
    JOIN dblink('synergy_master',
        'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
    ) AS legacy_ranks(id bigint, identifier uuid) ON legacy_ranks.identifier = legacy_templates.seafarer_rank_id
    JOIN migration.table_mappings tm ON tm.source_id = legacy_ranks.id::text
    WHERE tm.target_table = 'ranks'
      AND tm.target_db = current_database()
      AND tm.target_id = cprwu.child_rank_id
);
```

### 7. Child Form Definitions ID Mapping
**Output columns**: `DISTINCT pa.child_rank_id, cprwu.child_rank_name, pa.parent_rank_id, cprwu.parent_rank_name, parent_form_definition_id, child_form_definition_id, parent_form_name, pa.parent_applicability_id, pa.stage_id, pa.vessel_type_id, pa.appraisal_type_id, template_name_upper`

```sql
CREATE TEMP TABLE child_form_definitions_mapping AS
SELECT DISTINCT
    pa.child_rank_id,
    cprwu.child_rank_name,
    pa.parent_rank_id,
    cprwu.parent_rank_name,
    asf.form_definition_id as parent_form_definition_id,
    CASE
        WHEN UPPER(TRIM(fd.name)) = 'APPRAISEE FEEDBACK' THEN asf.form_definition_id
        ELSE migration.resolve_target_id(
            'synergy_master'::VARCHAR(100),
            'public'::VARCHAR(100),
            'appraisal_templates'::VARCHAR(100),
            ('CHILD_RANK_' || pa.child_rank_id::text || '_' || asf.form_definition_id::text)::text,
            current_database()::text::VARCHAR(100),
            'template'::VARCHAR(100),
            'form_definitions'::VARCHAR(100),
            NULL::uuid,
            current_setting('migration.is_repeated_migration_form_definitions')::boolean
        )
    END as child_form_definition_id,
    fd.name as parent_form_name,
    pa.parent_applicability_id,
    pa.stage_id,
    pa.vessel_type_id,
    pa.appraisal_type_id,
    COALESCE(tnsm.template_name_upper, 'UNKNOWN') as template_name_upper
FROM parent_applicability pa
JOIN child_ranks_without_templates cprwu ON
    cprwu.child_rank_id = pa.child_rank_id
    AND cprwu.parent_rank_id = pa.parent_rank_id

JOIN crewing.appraisal_stage_applicability parent_asa ON parent_asa.id = pa.parent_applicability_id
JOIN crewing.appraisal_stage_forms asf ON asf.stage_applicability_id = parent_asa.id
JOIN template.form_definitions fd ON fd.id = asf.form_definition_id
LEFT JOIN template_name_stage_mapping tnsm ON tnsm.stage_id = pa.stage_id
WHERE asf.status = 0
  AND fd.status = 0
  AND fd.form_type_id = current_setting('migration.appraisal_form_type_id')::uuid;
```

### 8. Child Applicability ID Mapping
**Output columns**: `DISTINCT pa.child_rank_id, pa.vessel_type_id, pa.appraisal_type_id, pa.stage_id, child_applicability_id`

```sql
CREATE TEMP TABLE child_applicability_mapping AS
SELECT DISTINCT
    pa.child_rank_id,
    pa.vessel_type_id,
    pa.appraisal_type_id,
    pa.stage_id,
    asa.id as child_applicability_id
FROM parent_applicability pa
JOIN crewing.appraisal_stage_applicability asa ON
    asa.rank_id = pa.child_rank_id
    AND asa.vessel_type_id = pa.vessel_type_id
    AND asa.appraisal_type_id = pa.appraisal_type_id
    AND asa.stage_id = pa.stage_id
WHERE asa.status = 0;
```

### 9. Fdl Roles Lookup For Update ID Mapping
**Output columns**: `role_uuid, role_name, role_name_upper, role_name_lower, role_name_normalized_upper, role_name_normalized_lower`

```sql
CREATE TEMP TABLE fdl_roles_lookup_for_update AS
SELECT
    id AS role_uuid,
    TRIM(name) AS role_name,
    UPPER(TRIM(name)) AS role_name_upper,
    LOWER(TRIM(name)) AS role_name_lower,
    UPPER(REPLACE(TRIM(name), '_', ' ')) AS role_name_normalized_upper,
    LOWER(REPLACE(TRIM(name), '_', ' ')) AS role_name_normalized_lower
FROM vessel.fdl_roles
WHERE status = 0
  AND name IS NOT NULL
  AND TRIM(name) != '';
```

### 10. Rank Identifier Mapping For Roles
**Output columns**: `legacy_seafarer_rank_id, new_rank_id`
**migration.table_mappings**: `target_table='ranks'`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE rank_identifier_mapping_for_roles AS
SELECT DISTINCT
    r.identifier AS legacy_seafarer_rank_id,
    tm.target_id AS new_rank_id
FROM dblink('synergy_master',
    'SELECT id, identifier FROM public.ranks WHERE identifier IS NOT NULL'
) AS r(id bigint, identifier uuid)
LEFT JOIN migration.table_mappings tm ON tm.source_id = r.id::text
LEFT JOIN public.ranks target_rank ON target_rank.id = tm.target_id
WHERE tm.target_table = 'ranks'
  AND tm.target_db = current_database()
  AND tm.target_id IS NOT NULL
  AND r.identifier IS NOT NULL;
```

### 11. Template Rank Role ID Mapping
**Output columns**: `DISTINCT ON (rank_id, template_name) rank_id, template_name, matched_role_uuid, source_role_name, matched_role_name`

```sql
CREATE TEMP TABLE template_rank_role_mapping AS
SELECT DISTINCT ON (rank_id, template_name)
    rank_id,
    template_name,
    role_uuid AS matched_role_uuid,
    source_role_name,
    matched_role_name
FROM rank_role_matches
ORDER BY rank_id, template_name, match_priority, LENGTH(matched_role_name) DESC, role_uuid;
```

### 12. Master Rank ID Mapping
**Output columns**: `rank_id, rank_name`

```sql
CREATE TEMP TABLE master_rank_lookup AS
SELECT
    id as rank_id,
    name as rank_name
FROM public.ranks
WHERE UPPER(TRIM(name)) = 'MASTER'
  AND status = 0
LIMIT 1;
```

### 13. Manning Manager Role ID Mapping
**Output columns**: `role_id, role_name`

```sql
CREATE TEMP TABLE manning_manager_role_lookup AS
SELECT
    fr.id as role_id,
    fr.name as role_name
FROM vessel.fdl_roles fr
JOIN vessel.fdl_departments fd ON fd.id = fr.fdl_department_id
WHERE UPPER(TRIM(fd.name)) = 'MANNING FDL'
  AND UPPER(TRIM(fr.name)) = 'FLEET MANAGER'
  AND fr.status = 0
LIMIT 1;
```

### 14. Rank Assignment ID Mapping
**Output columns**: `rank_name, appraiser_1, appraiser_2, shore`

```sql
CREATE TEMP TABLE rank_assignment_mapping AS
SELECT
    rank_name,
    appraiser_1,
    appraiser_2,
    shore
FROM (VALUES

    ('Master', NULL, NULL, NULL),
    ('Chief Officer', 'Master', NULL, 'Manning Manager'),
    ('Second Officer', 'Master', NULL, 'Manning Manager'),
    ('Third Officer', 'Master', NULL, 'Manning Manager'),
    ('Junior Third Officer', 'Master', NULL, 'Manning Manager'),
    ('Deck Cadet', 'Chief Officer', 'Master', 'Manning Manager'),
    ('Chief Engineer', NULL, NULL, NULL),
    ('Second Engineer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Third Engineer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Gas Engineer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Fourth Engineer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Junior Fourth Engineer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Electro Technical Officer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Electrical Officer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Engine Cadet', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Trainee Electrical Officer', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Electrical Cadet', 'Chief Engineer', 'Master', 'Manning Manager'),

    ('Chief Cook', 'Master', NULL, 'Manning Manager'),
    ('General Steward', 'Master', NULL, 'Manning Manager'),
    ('Bosun', 'Chief Officer', 'Master', 'Manning Manager'),
    ('Pumpman', 'Chief Officer', 'Master', 'Manning Manager'),
    ('Fitter', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Able Bodied Seaman', 'Chief Officer', 'Master', 'Manning Manager'),
    ('Ordinary Seaman', 'Chief Officer', 'Master', 'Manning Manager'),
    ('Oiler', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Wiper', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Trainee Fitter', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Trainee Seaman', 'Chief Officer', 'Master', 'Manning Manager'),
    ('Trainee Wiper', 'Chief Engineer', 'Master', 'Manning Manager'),
    ('Trainee General Steward', 'Master', NULL, 'Manning Manager')
) AS mapping(rank_name, appraiser_1, appraiser_2, shore);
```

### 15. All Ranks ID Mapping
**Output columns**: `rank_id, rank_name, rank_name_upper`

```sql
CREATE TEMP TABLE all_ranks_lookup AS
SELECT
    id as rank_id,
    name as rank_name,
    UPPER(TRIM(name)) as rank_name_upper
FROM public.ranks
WHERE status = 0;
```

### 16. Rank Parent ID Mapping
**Output columns**: `child_rank_name, parent_rank_name`

```sql
CREATE TEMP TABLE rank_parent_mapping AS
SELECT
    child_rank_name,
    parent_rank_name
FROM (VALUES
    ('Junior Third Officer', 'Third Officer'),
    ('Junior Fourth Engineer', 'Fourth Engineer'),
    ('Electrical Cadet', 'Trainee Electrical Officer'),
    ('Oiler', 'Motorman'),
    ('Trainee Fitter', 'Fitter'),
    ('Trainee Seaman', 'Ordinary Seaman'),
    ('Trainee Wiper', 'Wiper'),
    ('Trainee General Steward', 'General Steward')
) AS parent_mapping(child_rank_name, parent_rank_name);
```

Full migration context: `04-migration-scripts/master/appraisal_stage_forms_migration.sql`

## Validation

- Run `05-validation/master/appraisal_stage_forms_validation.sql` if available
- Run `06-rollback/master/appraisal_stage_forms_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.