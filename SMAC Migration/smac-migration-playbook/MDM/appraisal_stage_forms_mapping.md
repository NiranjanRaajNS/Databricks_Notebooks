# Table Mapping: appraisal_stage_forms → appraisal_stage_forms

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: appraisal_stage_forms
- **Source Script**: `04-migration-scripts/master/appraisal_stage_forms_migration.sql`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Appraisal Templates (`appraisal_templates` → `appraisal_stage_forms`)

## Migration Notes

- Part 1: Creates form_definitions records based on appraisal_templates
- Migrates appraisal_stage_forms from appraisal_templates table

## Special Considerations

- Script truncates target table(s) before insert (full reload): `crewing.appraisal_stage_applicability`, `crewing.appraisal_stage_forms`.

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 16

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `rank_identifier_to_target` | FK lookup | `rank_identifier_uuid`, `legacy_rank_id`, `target_rank_id`, `rank_name` | `migration.table_mappings` (see SQL) | `synergy_master` |
| `template_name_stage_mapping` | FK lookup | `template_name_upper`, `stage_id`, `stage_name`, `stage_sequence`, `stage_mode` | - | `synergy_master` |
| `rank_to_stages_mapping` | FK lookup | `DISTINCT ON (rtt.target_rank_id, tnsm.stage_id) rtt.target_r`, `tnsm.stage_id`, `tnsm.stage_sequence`, `tnsm.stage_mode`, `tnsm.template_name_upper` | - | - |
| `fdl_roles_lookup` | FK lookup | `id`, `name`, `name_upper` | - | - |
| `child_parent_rank_mapping` | FK lookup | `child_rank_name`, `parent_rank_name` | - | - |
| `child_ranks_without_templates` | Map role names to fdl_roles.id (for app | `DISTINCT cprwu.child_rank_id`, `cprwu.child_rank_name`, `cprwu.parent_rank_id`, `cprwu.parent_rank_name` | `migration.table_mappings` (see SQL) | `synergy_master` |
| `child_form_definitions_mapping` | FK lookup | `DISTINCT pa.child_rank_id`, `cprwu.child_rank_name`, `pa.parent_rank_id`, `cprwu.parent_rank_name`, `parent_form_definition_id`, `child_form_definition_id`, `parent_form_name`, `pa.parent_applicability_id`, `pa.stage_id`, `pa.vessel_type_id`, `pa.appraisal_type_id`, `template_name_upper` | - | - |
| `child_applicability_mapping` | FK lookup | `DISTINCT pa.child_rank_id`, `pa.vessel_type_id`, `pa.appraisal_type_id`, `pa.stage_id`, `child_applicability_id` | - | - |
| `fdl_roles_lookup_for_update` | FK lookup | `role_uuid`, `role_name`, `role_name_upper`, `role_name_lower`, `role_name_normalized_upper`, `role_name_normalized_lower` | - | - |
| `rank_identifier_mapping_for_roles` | FK lookup | `legacy_seafarer_rank_id`, `new_rank_id` | `migration.table_mappings` (see SQL) | `synergy_master` |
| `template_rank_role_mapping` | FK lookup | `DISTINCT ON (rank_id, template_name) rank_id`, `template_name`, `matched_role_uuid`, `source_role_name`, `matched_role_name` | - | - |
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

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id / identifier / uuid | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'appraisal_templates'::VARCHAR(100), CASE WHEN UPPER(TRIM(mt.template_name)) = 'APPRAISEE FE... |
| 2 | derived | - | code | - | UPPER(REGEXP_REPLACE(TRIM( CASE WHEN UPPER(TRIM(mt.template_name)) = 'APPRAISEE FEEDBACK' THEN 'Appraisee feedback' WHEN mt.rank_name IS NOT NULL AND TRIM(mt.rank_name) != '' TH... | UPPER(REGEXP_REPLACE(TRIM( CASE WHEN UPPER(TRIM(mt.template_name)) = 'APPRAISEE FEEDBACK' THEN 'Appraisee feedback' WHEN mt.rank_name IS NOT NULL AND TRIM(mt.rank_name) != '' TH... |
| 3 | derived | - | name | - | CASE WHEN UPPER(TRIM(mt.template_name)) = 'APPRAISEE FEEDBACK' THEN 'Appraisee feedback' WHEN mt.rank_name IS NOT NULL AND TRIM(mt.rank_name) != '' THEN INITCAP(TRIM(mt.template... | CASE WHEN UPPER(TRIM(mt.template_name)) = 'APPRAISEE FEEDBACK' THEN 'Appraisee feedback' WHEN mt.rank_name IS NOT NULL AND TRIM(mt.rank_name) != '' THEN INITCAP(TRIM(mt.template... |
| 4 | derived | - | description | - | NULLIF(TRIM(mt.template_name), '') as description | NULLIF(TRIM(mt.template_name), '') |
| 5 | derived | - | form_type_id | - | current_setting('migration.appraisal_form_type_id')::uuid as form_type_id | current_setting('migration.appraisal_form_type_id')::uuid |
| 6 | derived | - | form_template | - | COALESCE(mt.template, '{}'::jsonb) as form_template | COALESCE(mt.template, '{}'::jsonb) |
| 7 | derived | - | collaboration_level | - | 0 as collaboration_level | 0 |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | - | - | parent_id | - | NULL | NULL::uuid |
| 10 | derived | - | version | - | COALESCE(mt.version, 1) as version | COALESCE(mt.version, 1) |
| 11 | derived | - | created_at | - | COALESCE(mt.created_at, NOW()) as created_at | COALESCE(mt.created_at, NOW()) |
| 12 | derived | - | updated_at | - | COALESCE(mt.updated_at, mt.created_at, NOW()) as updated_at | COALESCE(mt.updated_at, mt.created_at, NOW()) |
| 13 | derived | - | deleted_at | - | mt.deleted_at as deleted_at | mt.deleted_at |
| 14 | - | - | archived_at | - | NULL | NULL::timestamp |
| 15 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar ) |
| 16 | - | - | request_data_json | - | NULL | NULL::jsonb |
| 17 | - | - | module_id | - | NULL | NULL::uuid |
| 18 | - | - | level | - | NULL | NULL::numeric |
| 19 | - | - | tags | - | NULL | NULL::text[] |
| 20 | derived | - | status | - | CASE WHEN mt.deleted_at IS NOT NULL THEN 3 WHEN mt.status IS NULL THEN 0 WHEN UPPER(TRIM(mt.status)) = 'ACTIVE' OR TRIM(mt.status) = '0' THEN 0 WHEN UPPER(TRIM(mt.status)) = 'DR... | CASE WHEN mt.deleted_at IS NOT NULL THEN 3 WHEN mt.status IS NULL THEN 0 WHEN UPPER(TRIM(mt.status)) = 'ACTIVE' OR TRIM(mt.status) = '0' THEN 0 WHEN UPPER(TRIM(mt.status)) = 'DR... |
| 21 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 22 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 23 | - | - | report_template | - | NULL | NULL::text |

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
