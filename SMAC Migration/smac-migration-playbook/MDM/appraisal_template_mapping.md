# Table Mapping: appraisal_templates → appraisal_template

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: appraisal_templates
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: appraisal_template
- **Source Script**: `04-migration-scripts/master/appraisal_template_migration.sql`

- **Legacy Path**: `synergy_master.public.appraisal_templates`
- **New Path**: `smac_master_migration.crewing.appraisal_template`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Appraisal Templates (`appraisal_templates` → `appraisal_template`)

## Migration Notes

- Preserve legacy identifier/uuid (UUID) as id if available, otherwise generate new UUIDs
- Record legacy id (integer) → new uuid (identifier/uuid) in migration.table_mappings
- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- SAC id (UUID) → SMAC id (UUID) - use directly
- Migrates appraisal_templates preserving identifier/uuid UUID as id

## Special Considerations

- Use DISTINCT ON (source_id) to prevent duplicate mappings
- Script performs `TRUNCATE TABLE crewing.appraisal_template` before insert (full table reload).

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | d.target_id AS id | d.target_id |
| 2 | derived | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(COALESCE(d.template_name, '')), NULL) |
| 3 | derived | - | name | - | COALESCE( NULLIF(d.template_name, ''), 'Appraisal Template ' || RIGHT(d.target_id::text, 8) ) AS name | COALESCE( NULLIF(d.template_name, ''), 'Appraisal Template ' || RIGHT(d.target_id::text, 8) ) |
| 4 | derived | - | template | - | CASE WHEN d.legacy_template IS NOT NULL THEN d.legacy_template::jsonb ELSE to_jsonb('Default Template'::text)::jsonb END AS template | CASE WHEN d.legacy_template IS NOT NULL THEN d.legacy_template::jsonb ELSE to_jsonb('Default Template'::text)::jsonb END |
| 5 | derived | - | template_type | - | NULLIF(d.template_type, '') AS template_type | NULLIF(d.template_type, '') |
| 6 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 7 | derived | - | version | - | 1 AS version | 1 |
| 8 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 9 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 10 | derived | - | status | - | 0 AS status | 0 |
| 11 | derived | - | created_at | - | NOW() AS created_at | NOW() |
| 12 | derived | - | updated_at | - | NOW() AS updated_at | NOW() |
| 13 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( :'SYSTEM_USER_ID'::varchar, NULL::varchar, :'SYSTEM_USER_ID'::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL... |
| 14 | derived | - | level | - | 0 AS level | 0 |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/appraisal_template_migration.sql`

## Validation

- Run `05-validation/master/appraisal_template_validation.sql` if available
- Run `06-rollback/master/appraisal_template_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
