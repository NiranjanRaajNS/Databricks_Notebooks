# Table Mapping: seafarer_competency_tasks → seafarer_competency_tasks

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_competency_tasks
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_competency_tasks
- **Source Script**: `04-migration-scripts/crewing/seafarer_competency_tasks_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_competency_tasks`
- **New Path**: `smac_crewing_migration.public.seafarer_competency_tasks`

## Business Key

- **Composite Key**: (`task_id`, `seafarer_id`, `vessel_id`)
- **Source (orchestration)**: Seafarer Competency Tasks (`seafarer_competency_tasks` → `seafarer_competency_tasks`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates seafarer_competency_tasks table. Maps seafarer_uuid to seafarer_id, vessel_id (bigint) to vessel_id (uuid), and competency_type (text) to competency_type_id (uuid). Converts jsonb fields (comments, attachment_ids) to text.

## Special Considerations

- Script performs `TRUNCATE TABLE public.seafarer_competency_tasks` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `vessels`, `ranks`, `vessel_categories`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessels_id_mapping` | FK lookup | `vessel_details_id`, `vessel_legacy_id`, `vessel_id_target` | `migration.table_mappings` (see SQL) | `synergy_seafarer` |
| `rank_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `vessels_id_mapping`

- **Output columns**: vessel_details_id, vessel_legacy_id, vessel_id_target
- **migration.table_mappings**: target_table=
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT DISTINCT
    vd.id as vessel_details_id,
    vd.vessel_id as vessel_legacy_id,
    tm.target_id::uuid as vessel_id_target
FROM dblink('synergy_seafarer',
    'SELECT DISTINCT vessel_id
     FROM public.seafarer_competency_tasks
     WHERE vessel_id IS NOT NULL AND vessel_id != 0'
) AS sct(vessel_id bigint)
INNER JOIN dblink('synergy_vessel',
    'SELECT id, vessel_id
     FROM public.vessel_details
     WHERE id IS NOT NULL'
) AS vd(id bigint, vessel_id bigint)
    ON vd.id = sct.vessel_id
LEFT JOIN dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''vessels'' AND target_db = current_database()'
) AS tm(source_id text, target_id uuid)
    ON tm.source_id = vd.vessel_id::text;
```

### `rank_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=ranks

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    source_id::text AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.id) migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_competency_tasks'::VARCHAR(100), legacy_data.id::te... |
| 2 | task_id | - | task_id | - | legacy_data.task_id as task_id | legacy_data.task_id |
| 3 | seafarer_uuid | - | seafarer_id | - | legacy_data.seafarer_uuid as seafarer_id | legacy_data.seafarer_uuid |
| 4 | vessel_category_id | - | vessel_category_id | - | legacy_data.vessel_category_id as vessel_category_id | legacy_data.vessel_category_id |
| 5 | derived | - | competency_type_id | - | COALESCE(ct_map.competency_type_id, NULL) as competency_type_id | COALESCE(ct_map.competency_type_id, NULL) |
| 6 | derived | - | vessel_id | - | COALESCE(v_map.vessel_id_target, '00000000-0000-0000-0000-000000000000'::uuid) as vessel_id | COALESCE(v_map.vessel_id_target, '00000000-0000-0000-0000-000000000000'::uuid) |
| 7 | rank_id | - | rank_id | - | COALESCE(r_map.new_id, legacy_data.rank_id) as rank_id | COALESCE(r_map.new_id, legacy_data.rank_id) |
| 8 | approved_by | - | approved_by | - | legacy_data.approved_by as approved_by | legacy_data.approved_by |
| 9 | approved_on | - | approved_at | - | legacy_data.approved_on as approved_at | legacy_data.approved_on |
| 10 | rejected_by | - | rejected_by | - | legacy_data.rejected_by as rejected_by | legacy_data.rejected_by |
| 11 | rejected_on | - | rejected_at | - | legacy_data.rejected_on as rejected_at | legacy_data.rejected_on |
| 12 | comments | - | comments | - | CASE WHEN legacy_data.comments IS NULL THEN NULL WHEN jsonb_typeof(legacy_data.comments) = 'string' THEN legacy_data.comments::text ELSE legacy_data.comments::text END as comments | CASE WHEN legacy_data.comments IS NULL THEN NULL WHEN jsonb_typeof(legacy_data.comments) = 'string' THEN legacy_data.comments::text ELSE legacy_data.comments::text END |
| 13 | rejection_reason_id | - | rejection_reason_id | - | legacy_data.rejection_reason_id as rejection_reason_id | legacy_data.rejection_reason_id |
| 14 | expiry_date | - | expiry_at | - | legacy_data.expiry_date as expiry_at | legacy_data.expiry_date |
| 15 | attachment_ids | - | attachment_ids | - | CASE WHEN legacy_data.attachment_ids IS NULL THEN NULL WHEN jsonb_typeof(legacy_data.attachment_ids) = 'string' THEN legacy_data.attachment_ids::text ELSE legacy_data.attachment... | CASE WHEN legacy_data.attachment_ids IS NULL THEN NULL WHEN jsonb_typeof(legacy_data.attachment_ids) = 'string' THEN legacy_data.attachment_ids::text ELSE legacy_data.attachment... |
| 16 | derived | - | workflow_status_id | - | COALESCE( (SELECT id FROM default_workflow_status), '00000000-0000-0000-0000-000000000000'::uuid ) as workflow_status_id | COALESCE( (SELECT id FROM default_workflow_status), '00000000-0000-0000-0000-000000000000'::uuid ) |
| 17 | derived | - | is_verified | - | FALSE as is_verified | FALSE |
| 18 | derived | - | verified_at | - | NULL as verified_at | NULL |
| 19 | derived | - | verified_by_id | - | NULL as verified_by_id | NULL |
| 20 | derived | - | verification_notes | - | NULL as verification_notes | NULL |
| 21 | status | - | status | - | TRIM(COALESCE(legacy_data.status, '')) as status | TRIM(COALESCE(legacy_data.status, '')) |
| 22 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 23 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 24 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 25 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 26 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 27 | created_by_id, deleted_by_id, updated_by_id, created_by_name, updated_by_name, seafarer_uuid, vessel_id, competency_type | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, legacy_data.deleted_by_id::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::times... |
| 28 | derived | - | name | - | NULL as name | NULL |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessels ID Mapping
**Output columns**: `vessel_details_id, vessel_legacy_id, vessel_id_target`
**migration.table_mappings**: see SQL below
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT DISTINCT
    vd.id as vessel_details_id,
    vd.vessel_id as vessel_legacy_id,
    tm.target_id::uuid as vessel_id_target
FROM dblink('synergy_seafarer',
    'SELECT DISTINCT vessel_id
     FROM public.seafarer_competency_tasks
     WHERE vessel_id IS NOT NULL AND vessel_id != 0'
) AS sct(vessel_id bigint)
INNER JOIN dblink('synergy_vessel',
    'SELECT id, vessel_id
     FROM public.vessel_details
     WHERE id IS NOT NULL'
) AS vd(id bigint, vessel_id bigint)
    ON vd.id = sct.vessel_id
LEFT JOIN dblink('smac_master_migration',
    'SELECT source_id, target_id
     FROM migration.table_mappings
     WHERE target_table = ''vessels'' AND target_db = current_database()'
) AS tm(source_id text, target_id uuid)
    ON tm.source_id = vd.vessel_id::text;
```

### 2. Rank ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='ranks'`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT
    source_id::text AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_competency_tasks_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_competency_tasks_validation.sql` if available
- Run `06-rollback/crewing/seafarer_competency_tasks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
