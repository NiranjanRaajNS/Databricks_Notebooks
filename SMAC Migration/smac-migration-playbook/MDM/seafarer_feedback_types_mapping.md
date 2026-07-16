# Table Mapping: feedback_reasons → seafarer_feedback_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: feedback_reasons
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: seafarer_feedback_types
- **Source Script**: `04-migration-scripts/master/seafarer_feedback_types_migration.sql`

- **Legacy Path**: `synergy_master.public.feedback_reasons`
- **New Path**: `smac_master_migration.crewing.seafarer_feedback_types`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Seafarer Feedback Types (`feedback_reasons` → `seafarer_feedback_types`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates seafarer_feedback_types from feedback_reasons table

## Special Considerations

- Script performs `TRUNCATE TABLE crewing.seafarer_feedback_types` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `feedback_category_id_mapping` | Check for duplicate UUIDs in source table | `legacy_enum_id`, `category_uuid` | - | `synergy_master` |

### `feedback_category_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: legacy_enum_id, category_uuid
- **dblink connection**: `synergy_master`

```sql
CREATE TEMP TABLE feedback_category_id_mapping AS
SELECT
    e.id::bigint AS legacy_enum_id,
    CASE
        WHEN e.identifier_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN e.identifier_text::uuid
        ELSE NULL
    END AS category_uuid
FROM dblink('synergy_master',
    'SELECT id, identifier::text FROM enum.feedbackreasontype WHERE identifier IS NOT NULL'
) AS e(id bigint, identifier_text text)
WHERE e.identifier_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_master'::VARCHAR(100), 'public'::VARCHAR(100), 'feedback_reasons'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(10... |
| 2 | name | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.name), NULL) |
| 3 | name | - | name | - | TRIM(legacy_data.name) as name | TRIM(legacy_data.name) |
| 4 | description | - | description | - | TRIM(legacy_data.description) as description | TRIM(legacy_data.description) |
| 5 | derived | - | level | - | (ROW_NUMBER() OVER (ORDER BY TRIM(name))::numeric / 1.0)::numeric(10,1) as level | (ROW_NUMBER() OVER (ORDER BY TRIM(name))::numeric / 1.0)::numeric(10,1) |
| 6 | - | - | feedback_category_id | - | COALESCE(fcm.category_uuid, NULL::uuid) AS feedback_category_id | COALESCE(fcm.category_uuid, NULL::uuid) |
| 7 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 8 | - | - | parent_id | - | NULL | NULL::uuid |
| 9 | derived | - | version | - | 1 as version | 1 |
| 10 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 11 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 12 | deleted_at, is_active | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN legacy_data.is_active = true OR UPPER(TRIM(legacy_data.is_active::text)) = 'TR... | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 WHEN legacy_data.is_active IS NULL THEN 0 WHEN legacy_data.is_active = true OR UPPER(TRIM(legacy_data.is_active::text)) = 'TR... |
| 13 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) as created_at | COALESCE(legacy_data.created_at, NOW()) |
| 14 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) as updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 15 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 16 | - | - | archived_at | - | NULL | NULL::timestamp |
| 17 | name | - | tags | - | generate_meaningful_code() | CASE WHEN generate_meaningful_code(TRIM(legacy_data.name), NULL) != LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(legacy_data.name), ' ', '_'), '-', '_'), '/', '_'), '.', '... |
| 18 | name | - | audit_info | - | generate_meaningful_code() | LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(legacy_data.name), ' ', '_'), '-', '_'), '/', '_'), '.', '_'), '''', '_')) ]::text[] ELSE ARRAY[generate_meaningful_code(TRIM(... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Feedback Category ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `legacy_enum_id, category_uuid`
**dblink**: `synergy_master`

```sql
CREATE TEMP TABLE feedback_category_id_mapping AS
SELECT
    e.id::bigint AS legacy_enum_id,
    CASE
        WHEN e.identifier_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN e.identifier_text::uuid
        ELSE NULL
    END AS category_uuid
FROM dblink('synergy_master',
    'SELECT id, identifier::text FROM enum.feedbackreasontype WHERE identifier IS NOT NULL'
) AS e(id bigint, identifier_text text)
WHERE e.identifier_text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

Full migration context: `04-migration-scripts/master/seafarer_feedback_types_migration.sql`

## Validation

- Run `05-validation/master/seafarer_feedback_types_validation.sql` if available
- Run `06-rollback/master/seafarer_feedback_types_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
