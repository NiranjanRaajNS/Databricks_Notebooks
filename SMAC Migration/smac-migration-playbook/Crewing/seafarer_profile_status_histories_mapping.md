# Table Mapping: seafarer_profile_status_histories → seafarer_profile_status_histories

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: seafarer_profile_status_histories
- **Source Script**: `04-migration-scripts/crewing/seafarer_profile_status_histories_migration.sql`


## Business Key

- **Composite Key**: (`seafarer_id`, `status`, `changed_at`)
- **Source (orchestration)**: Seafarer Profile Status Histories (`seafarer_profile_status_histories` → `seafarer_profile_status_histories`)

## Migration Notes

- Source table has id (bigint) - uses migration.resolve_target_id() for idempotent UUID generation
- Maps seafarer_id via migration.table_mappings
- Maps status from INTEGER to seafarer_profile_statuses UUID by name (1='Active', 0='InActive')
- new_status_id: Maps SAC status directly to seafarer_profile_statuses.name (source status represents current/latest status)
- old_status_id: Set to opposite of new_status_id (Active ↔ InActive)
- Migrates seafarer_profile_status_histories. Preserves identifier/uuid when available. Maps seafarer_id (bigint) to seafarer_id (uuid) via migration.table_mappings. Requires seafarers table to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_profile_status_histories` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 6

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `seafarer_profile_statuses_mapping` | FK lookup | `status_name`, `status_id` | - | `smac_master_migration` |
| `workflow_status_id_mapping` | FK lookup | `workflow_status_id` | - | `smac_master_migration` |
| `profile_remark_reason_mappings_from_master` | FK lookup | `source_id`, `target_id` | `?.?.seafarer_profile_remarks` → `?.?.profile_remark_reasons` | `smac_master_migration` |
| `profile_remark_reason_mapping` | FK lookup | `source_id`, `reason_name`, `target_id` | - | `synergy_seafarer` |
| `seafarer_remarks_for_reason_mapping` | FK lookup | `DISTINCT ON (sr.seafarer_id) sr.seafarer_id`, `remark_identifier`, `remarks_text` | - | `synergy_seafarer` |

### `seafarers_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `seafarer_profile_statuses_mapping`

- **Output columns**: status_name, status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE seafarer_profile_statuses_mapping AS
SELECT
    sps.name as status_name,
    sps.id as status_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM crewing.seafarer_profile_statuses WHERE name IN (''Active'', ''InActive'')'
) AS sps(id uuid, name text)
WHERE sps.name IS NOT NULL;
```

### `workflow_status_id_mapping`

- **Output columns**: workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

### `profile_remark_reason_mappings_from_master`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: source_table=seafarer_profile_remarks, target_table=profile_remark_reasons
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_remark_reason_mappings_from_master AS
SELECT source_id, target_id
FROM dblink('smac_master_migration',
    $query$SELECT source_id, target_id FROM migration.table_mappings
           WHERE target_table = 'profile_remark_reasons'
             AND source_table = 'seafarer_profile_remarks'$query$
) AS tm(source_id text, target_id uuid);
```

### `profile_remark_reason_mapping`

- **Output columns**: source_id, reason_name, target_id
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE profile_remark_reason_mapping AS
SELECT
    spr.id::text AS source_id,
    spr.name AS reason_name,
    tm.target_id AS target_id
FROM dblink('synergy_seafarer',
    'SELECT id, name FROM public.seafarer_profile_remarks'
) AS spr(id bigint, name text)
LEFT JOIN profile_remark_reason_mappings_from_master tm ON
    tm.source_id = spr.id::text;
```

### `seafarer_remarks_for_reason_mapping`

- **Output columns**: DISTINCT ON (sr.seafarer_id) sr.seafarer_id, remark_identifier, remarks_text
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE seafarer_remarks_for_reason_mapping AS
SELECT DISTINCT ON (sr.seafarer_id)
    sr.seafarer_id,
    (first_elem->>'remark_identifier')::text as remark_identifier,

    (SELECT STRING_AGG(TRIM(COALESCE(elem->>'remark', '')), '; ' ORDER BY (elem->>'remark_identifier')::text)
     FROM jsonb_array_elements(sr.profile_remark) AS elem
     WHERE elem->>'remark' IS NOT NULL AND TRIM(elem->>'remark') != ''
    ) as remarks_text
FROM dblink('synergy_seafarer',
    'SELECT seafarer_id, profile_remark FROM public.seafarer_remarks WHERE profile_remark IS NOT NULL AND jsonb_typeof(profile_remark) = ''array'''
) AS sr(seafarer_id bigint, profile_remark jsonb)
CROSS JOIN LATERAL jsonb_array_elements(sr.profile_remark) AS first_elem
WHERE first_elem->>'remark_identifier' IS NOT NULL
ORDER BY sr.seafarer_id, (first_elem->>'remark_identifier')::text;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_profile_status_histories'::VARCHAR(100), legacy_data.id::text, current_database(... |
| 2 | derived | - | seafarer_id | - | COALESCE(seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) as seafarer_id | COALESCE(seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | status | - | old_status_id | - | CASE WHEN legacy_data.status = 1 THEN COALESCE(inactive_status_mapping.status_id, NULL::uuid) WHEN legacy_data.status = 0 THEN COALESCE(active_status_mapping.status_id, NULL::uu... | CASE WHEN legacy_data.status = 1 THEN COALESCE(inactive_status_mapping.status_id, NULL::uuid) WHEN legacy_data.status = 0 THEN COALESCE(active_status_mapping.status_id, NULL::uu... |
| 4 | status | - | new_status_id | - | CASE WHEN legacy_data.status = 1 THEN COALESCE(active_status_mapping.status_id, '00000000-0000-0000-0000-000000000000'::uuid) WHEN legacy_data.status = 0 THEN COALESCE(inactive_... | CASE WHEN legacy_data.status = 1 THEN COALESCE(active_status_mapping.status_id, '00000000-0000-0000-0000-000000000000'::uuid) WHEN legacy_data.status = 0 THEN COALESCE(inactive_... |
| 5 | - | - | reason_id | - | COALESCE(reason_mapping.target_id, NULL::uuid) as reason_id | COALESCE(reason_mapping.target_id, NULL::uuid) |
| 6 | - | - | source | - | NULL | NULL::text |
| 7 | - | - | remarks | - | COALESCE(srrfm.remarks_text, NULL::text) as remarks | COALESCE(srrfm.remarks_text, NULL::text) |
| 8 | derived | - | workflow_status_id | - | COALESCE(workflow_status_map.workflow_status_id, '00000000-0000-0000-0000-000000000000'::uuid) as workflow_status_id | COALESCE(workflow_status_map.workflow_status_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 9 | derived | - | is_verified | - | false as is_verified | false |
| 10 | - | - | verified_at | - | NULL | NULL::timestamp |
| 11 | - | - | verified_by_id | - | NULL | NULL::uuid |
| 12 | - | - | verification_notes | - | NULL | NULL::text |
| 13 | status | - | status | - | CASE WHEN legacy_data.status IS NULL THEN 'Active' WHEN legacy_data.status = 0 THEN 'Active' WHEN legacy_data.status = 1 THEN 'Draft' WHEN legacy_data.status = 2 THEN 'Inactive'... | CASE WHEN legacy_data.status IS NULL THEN 'Active' WHEN legacy_data.status = 0 THEN 'Active' WHEN legacy_data.status = 1 THEN 'Draft' WHEN legacy_data.status = 2 THEN 'Inactive'... |
| 14 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 15 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 16 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 17 | - | - | archived_at | - | NULL | NULL::timestamp |
| 18 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 19 | created_by_id | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::var... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Seafarer Profile Statuses ID Mapping
**Output columns**: `status_name, status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE seafarer_profile_statuses_mapping AS
SELECT
    sps.name as status_name,
    sps.id as status_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM crewing.seafarer_profile_statuses WHERE name IN (''Active'', ''InActive'')'
) AS sps(id uuid, name text)
WHERE sps.name IS NOT NULL;
```

### 3. Workflow Status ID Mapping
**Output columns**: `workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

### 4. Profile Remark Reason Mappings From Master ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `seafarer_profile_remarks` → `profile_remark_reasons`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_remark_reason_mappings_from_master AS
SELECT source_id, target_id
FROM dblink('smac_master_migration',
    $query$SELECT source_id, target_id FROM migration.table_mappings
           WHERE target_table = 'profile_remark_reasons'
             AND source_table = 'seafarer_profile_remarks'$query$
) AS tm(source_id text, target_id uuid);
```

### 5. Profile Remark Reason ID Mapping
**Output columns**: `source_id, reason_name, target_id`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE profile_remark_reason_mapping AS
SELECT
    spr.id::text AS source_id,
    spr.name AS reason_name,
    tm.target_id AS target_id
FROM dblink('synergy_seafarer',
    'SELECT id, name FROM public.seafarer_profile_remarks'
) AS spr(id bigint, name text)
LEFT JOIN profile_remark_reason_mappings_from_master tm ON
    tm.source_id = spr.id::text;
```

### 6. Seafarer Remarks For Reason ID Mapping
**Output columns**: `DISTINCT ON (sr.seafarer_id) sr.seafarer_id, remark_identifier, remarks_text`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE seafarer_remarks_for_reason_mapping AS
SELECT DISTINCT ON (sr.seafarer_id)
    sr.seafarer_id,
    (first_elem->>'remark_identifier')::text as remark_identifier,

    (SELECT STRING_AGG(TRIM(COALESCE(elem->>'remark', '')), '; ' ORDER BY (elem->>'remark_identifier')::text)
     FROM jsonb_array_elements(sr.profile_remark) AS elem
     WHERE elem->>'remark' IS NOT NULL AND TRIM(elem->>'remark') != ''
    ) as remarks_text
FROM dblink('synergy_seafarer',
    'SELECT seafarer_id, profile_remark FROM public.seafarer_remarks WHERE profile_remark IS NOT NULL AND jsonb_typeof(profile_remark) = ''array'''
) AS sr(seafarer_id bigint, profile_remark jsonb)
CROSS JOIN LATERAL jsonb_array_elements(sr.profile_remark) AS first_elem
WHERE first_elem->>'remark_identifier' IS NOT NULL
ORDER BY sr.seafarer_id, (first_elem->>'remark_identifier')::text;
```

Full migration context: `04-migration-scripts/crewing/seafarer_profile_status_histories_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_profile_status_histories_validation.sql` if available
- Run `06-rollback/crewing/seafarer_profile_status_histories_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
