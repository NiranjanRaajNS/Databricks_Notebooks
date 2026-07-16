# Table Mapping: seafarer_ml_form_documents → seafarer_ml_forms

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_ml_form_documents
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_ml_forms
- **Source Script**: `04-migration-scripts/crewing/seafarer_ml_forms_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_ml_form_documents`
- **New Path**: `smac_crewing_migration.shore.seafarer_ml_forms`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer ML Form Documents (`seafarer_ml_form_documents` → `seafarer_ml_forms`)

## Migration Notes

- Migrates seafarer_ml_form_documents to seafarer_ml_forms table. Uses direct mapping: id→id, seafarer_id→seafarer_id, ml_details_id→ml_forms_template_id. Maps generate_file_path to file_path. Sets default values: mailed_to_seafarer (false), workflow_status_id (default UUID), tenant_id. Only migrates records where seafarer_id exists in target seafarers table.

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_ml_forms` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `workflow_status_lookup` | Check for duplicate UUIDs in source table | `status_code`, `workflow_status_id` | - | `smac_master_migration` |
| `seafarers_id_mapping` | Check if any mapp | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `workflow_status_lookup`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: status_code, workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_lookup AS
SELECT
    ws.code::varchar(50) AS status_code,
    ws.id::uuid AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT code, id FROM public.workflow_status WHERE code = ''APPROVED'''
) AS ws(code text, id uuid);
```

### `seafarers_id_mapping`

- **Purpose**: Check if any mapp
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    target_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_ml_form_documents'::VARCHAR(100), legacy_data.id::text, current_database()::text... |
| 2 | derived | - | seafarer_id | - | COALESCE( seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) as seafarer_id | COALESCE( seafarer_mapping.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 3 | ml_details_id | - | ml_forms_template_id | - | legacy_data.ml_details_id as ml_forms_template_id | legacy_data.ml_details_id |
| 4 | derived | - | mailed_to_seafarer | - | false as mailed_to_seafarer | false |
| 5 | derived | - | content | - | NULL as content | NULL |
| 6 | generate_file_path | - | file_path | - | TRIM(legacy_data.generate_file_path) as file_path | TRIM(legacy_data.generate_file_path) |
| 7 | derived | - | workflow_status_id | - | COALESCE( (SELECT workflow_status_id FROM workflow_status_lookup WHERE status_code = 'APPROVED' LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid ) AS workflow_status_id | COALESCE( (SELECT workflow_status_id FROM workflow_status_lookup WHERE status_code = 'APPROVED' LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid ) |
| 8 | derived | - | verified_at | - | NULL as verified_at | NULL |
| 9 | derived | - | verified_by_id | - | NULL as verified_by_id | NULL |
| 10 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 11 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 12 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 13 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 14 | deleted_at | - | deleted_at | - | legacy_data.deleted_at as deleted_at | legacy_data.deleted_at |
| 15 | created_by_id, deleted_by_id, updated_by_id, created_by_name, updated_by_name, deleted_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, legacy_data.deleted_by_id::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::times... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Workflow Status ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `status_code, workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_lookup AS
SELECT
    ws.code::varchar(50) AS status_code,
    ws.id::uuid AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT code, id FROM public.workflow_status WHERE code = ''APPROVED'''
) AS ws(code text, id uuid);
```

### 2. Seafarers ID Mapping
**Purpose**: Check if any mapp
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    target_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_ml_forms_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_ml_forms_validation.sql` if available
- Run `06-rollback/crewing/seafarer_ml_forms_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
