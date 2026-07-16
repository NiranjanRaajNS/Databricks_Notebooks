# Table Mapping: wellbeing_templates → wellbeing_templates

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: wellbeing_templates
- **Source Script**: `04-migration-scripts/master/wellbeing_templates_migration.sql`


## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Wellbeing Templates (`wellbeing_templates` → `wellbeing_templates`)

## Migration Notes

- SAC has minimal columns; SMAC requires name/code/version/defined_by/workflow_status/status.
- SAC public.wellbeing_templates (minimal columns) to SMAC crewing.wellbeing_templates. Preserves id via resolve_target_id; name/code derived from template JSON or id fallback.

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.wellbeing_templates` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `rank_sac_to_smac_uuid` | FK lookup | `tm.source_id`, `tm.target_id` | `synergy_master.public.ranks` → `?.public.ranks` | - |

### `rank_sac_to_smac_uuid`

- **Output columns**: tm.source_id, tm.target_id
- **migration.table_mappings**: source_db=synergy_master, source_schema=public, source_table=ranks, target_schema=public, target_table=ranks

```sql
CREATE TEMP TABLE rank_sac_to_smac_uuid AS
SELECT
    tm.source_id,
    tm.target_id
FROM migration.table_mappings tm
WHERE tm.target_db = current_database()
  AND tm.target_schema = 'public'
  AND tm.target_table = 'ranks'
  AND tm.source_db = 'synergy_master'
  AND tm.source_schema = 'public'
  AND tm.source_table = 'ranks';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'wellbeing_templates'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR... |
| 2 | derived | - | name | - | x.display_name AS name | x.display_name |
| 3 | derived | - | code | - | x.generated_code AS code | x.generated_code |
| 4 | derived | - | description | - | x.display_name AS description | x.display_name |
| 5 | template | - | template | - | COALESCE(legacy_data.template, '{}'::jsonb) AS template | COALESCE(legacy_data.template, '{}'::jsonb) |
| 6 | applicable_rank_ids | - | applicable_rank_ids | - | COALESCE( ( SELECT COALESCE( array_agg(m.target_id ORDER BY u.ord) FILTER (WHERE m.target_id IS NOT NULL), '{}'::uuid[] ) FROM unnest(COALESCE(legacy_data.applicable_rank_ids, '... | COALESCE( ( SELECT COALESCE( array_agg(m.target_id ORDER BY u.ord) FILTER (WHERE m.target_id IS NOT NULL), '{}'::uuid[] ) FROM unnest(COALESCE(legacy_data.applicable_rank_ids, '... |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | - | - | parent_id | - | NULL | NULL::uuid |
| 9 | derived | - | level | - | 0::numeric AS level | 0::numeric |
| 10 | version | - | version | - | COALESCE(legacy_data.version, 1) AS version | COALESCE(legacy_data.version, 1) |
| 11 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 12 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 13 | deleted_at | - | status | - | STATUS_DELETED | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN :'STATUS_DELETED'::integer ELSE :'STATUS_ACTIVE'::integer END |
| 14 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 15 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 16 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 17 | - | - | archived_at | - | NULL | NULL::timestamp |
| 18 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 19 | derived | - | tags | - | CASE WHEN x.generated_code != x.name_tag THEN ARRAY[x.generated_code | CASE WHEN x.generated_code != x.name_tag THEN ARRAY[x.generated_code |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Rank Sac To Smac Uuid ID Mapping
**Output columns**: `tm.source_id, tm.target_id`
**migration.table_mappings**: `ranks` → `ranks` (source_db=`synergy_master`)

```sql
CREATE TEMP TABLE rank_sac_to_smac_uuid AS
SELECT
    tm.source_id,
    tm.target_id
FROM migration.table_mappings tm
WHERE tm.target_db = current_database()
  AND tm.target_schema = 'public'
  AND tm.target_table = 'ranks'
  AND tm.source_db = 'synergy_master'
  AND tm.source_schema = 'public'
  AND tm.source_table = 'ranks';
```

Full migration context: `04-migration-scripts/master/wellbeing_templates_migration.sql`

## Validation

- Run `05-validation/master/wellbeing_templates_validation.sql` if available
- Run `06-rollback/master/wellbeing_templates_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
