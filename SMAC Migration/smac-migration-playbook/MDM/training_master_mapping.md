# Table Mapping: training → training_master

## Overview
- **Legacy Database**: synergy_training
- **Legacy Schema**: public
- **Legacy Table**: training
- **New Database**: smac_crewing_migration
- **New Schema**: crewing
- **New Table**: training_master
- **Source Script**: `04-migration-scripts/master/training_master_migration.sql`

- **Legacy Path**: `synergy_training.public.training`
- **New Path**: `smac_crewing_migration.crewing.training_master`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Training Master (`training` → `training_master`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- training_type is seed data (not migrated), so lookup directly from target table
- Migrates training from synergy_training.public.training to smac_crewing_migration.crewing.training_master. Preserves legacy UUID (id) as target id using migration.resolve_target_id(). Maps type (uuid) to training_type_id via migration.table_mappings (training_types table). Uses default training_category_id from seed data. Maps include_In_appraisal to eligable_for_appraisal. Converts document_identifier (text) to document_id (uuid) if valid UUID format. Maps status based on deleted_at (NULL=0 Active, NOT NULL=3 Deleted). Stores course_type as tags array. Uses standardized SMAC audit_info structure. Requires training_types table to be migrated first and training_category seed data to be loaded.

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.training_master` before insert (full table reload).
- Orchestration dependencies: `training_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `training_type_id_mapping` | FK lookup | `legacy_id`, `new_id` | - | - |
| `document_id_mapping` | Get count of traini | `document_identifier`, `document_id` | - | - |

### `training_type_id_mapping`

- **Output columns**: legacy_id, new_id

```sql
CREATE TEMP TABLE training_type_id_mapping AS
SELECT id AS legacy_id, id AS new_id
FROM crewing.training_type;
```

### `document_id_mapping`

- **Purpose**: Get count of traini
- **Output columns**: document_identifier, document_id

```sql
CREATE TEMP TABLE document_id_mapping AS
SELECT DISTINCT
    TRIM(d.identifier) AS document_identifier,
    d.id AS document_id
FROM document.documents d
WHERE d.identifier IS NOT NULL
  AND TRIM(d.identifier) <> '';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_training'::VARCHAR(100), 'public'::VARCHAR(100), 'training'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(100), 'c... |
| 2 | name, id | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(COALESCE(legacy_data.name, 'UNKNOWN')), legacy_data.id::text) |
| 3 | name | - | name | - | TRIM(COALESCE(legacy_data.name, 'UNKNOWN')) as name | TRIM(COALESCE(legacy_data.name, 'UNKNOWN')) |
| 4 | description | - | description | - | TRIM(legacy_data.description) as description | TRIM(legacy_data.description) |
| 5 | derived | - | training_type_id | - | training_type_map.new_id as training_type_id | training_type_map.new_id |
| 6 | derived | - | training_category_id | - | COALESCE( training_category_map.id, (SELECT id FROM crewing.training_category WHERE code = 'TRAINING' LIMIT 1), (SELECT id FROM crewing.training_category ORDER BY created_at ASC... | COALESCE( training_category_map.id, (SELECT id FROM crewing.training_category WHERE code = 'TRAINING' LIMIT 1), (SELECT id FROM crewing.training_category ORDER BY created_at ASC... |
| 7 | include_In_appraisal | - | eligable_for_appraisal | - | COALESCE(legacy_data.include_In_appraisal, false) as eligable_for_appraisal | COALESCE(legacy_data.include_In_appraisal, false) |
| 8 | derived | - | document_id | - | document_map.document_id as document_id | document_map.document_id |
| 9 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 10 | derived | - | parent_id | - | NULL as parent_id | NULL |
| 11 | derived | - | level | - | 0 as level | 0 |
| 12 | derived | - | version | - | 1 as version | 1 |
| 13 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 14 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 15 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END as status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 16 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW())::timestamp without time zone as created_at | COALESCE(legacy_data.created_at, NOW())::timestamp without time zone |
| 17 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW())::timestamp without time zone as updated_at | COALESCE(legacy_data.updated_at, NOW())::timestamp without time zone |
| 18 | deleted_at | - | deleted_at | - | legacy_data.deleted_at::timestamp without time zone as deleted_at | legacy_data.deleted_at::timestamp without time zone |
| 19 | - | - | archived_at | - | NULL | NULL::timestamp without time zone |
| 20 | created_by_id, deleted_by_id, updated_by_id, created_by_name, updated_by_name, deleted_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( legacy_data.created_by_id::varchar, legacy_data.deleted_by_id::varchar, legacy_data.updated_by_id::varchar, NULL::varchar, NULL::varchar, NULL::times... |
| 21 | course_type | - | tags | - | CASE WHEN legacy_data.course_type IS NOT NULL AND TRIM(legacy_data.course_type) <> '' THEN ARRAY[TRIM(legacy_data.course_type)] ELSE NULL END::text[] as tags | CASE WHEN legacy_data.course_type IS NOT NULL AND TRIM(legacy_data.course_type) <> '' THEN ARRAY[TRIM(legacy_data.course_type)] ELSE NULL END::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Training Type ID Mapping
**Output columns**: `legacy_id, new_id`

```sql
CREATE TEMP TABLE training_type_id_mapping AS
SELECT id AS legacy_id, id AS new_id
FROM crewing.training_type;
```

### 2. Document ID Mapping
**Purpose**: Get count of traini
**Output columns**: `document_identifier, document_id`

```sql
CREATE TEMP TABLE document_id_mapping AS
SELECT DISTINCT
    TRIM(d.identifier) AS document_identifier,
    d.id AS document_id
FROM document.documents d
WHERE d.identifier IS NOT NULL
  AND TRIM(d.identifier) <> '';
```

Full migration context: `04-migration-scripts/master/training_master_migration.sql`

## Validation

- Run `05-validation/master/training_master_validation.sql` if available
- Run `06-rollback/master/training_master_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
