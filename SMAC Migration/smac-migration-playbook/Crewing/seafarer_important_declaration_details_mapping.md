# Table Mapping: seafarer_other_details → seafarer_form_submissions

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_other_details
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_form_submissions
- **Source Script**: `04-migration-scripts/crewing/seafarer_important_declaration_details_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_other_details`
- **New Path**: `smac_crewing_migration.public.seafarer_form_submissions`

## Business Key

- **Composite Key**: (`seafarer_id`, `form_definitions_id`)
- **Source (orchestration)**: Seafarer Important Declaration Details (`seafarer_other_details` → `seafarer_form_submissions`)

## Migration Notes

- Generate new UUID for id using migration.resolve_target_id
- Map seafarer_id (bigint/uuid) → seafarer_id (uuid) via migration.table_mappings
- Filter: section_identifier = 'other_details' LIMIT 100
- Uses standardized SMAC audit_info structure
- Joins seafarer_other_details and seafarer_documents on seafarer_doc_id. Extracts submission_data from seafarer_documents.form_response JSONB. Maps seafarer_id via migration.table_mappings (try seafarer_uuid first, then seafarer_id). Maps is_confirmed to is_verified, verified_date to verified_at. Uses standardized SMAC audit_info structure. Only migrates records where form_response IS NOT NULL AND form_response::text <> '{}'.

## Special Considerations

- Use DISTINCT ON to prevent duplicate mappings
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 4

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `source_id`, `target_id` | `migration.table_mappings` (see SQL) | - |
| `seafarer_uuid_mapping` | FK lookup | `source_id`, `target_id` | `migration.table_mappings` (see SQL) | - |
| `rank_id_mapping` | FK lookup | `legacy_rank_id`, `new_rank_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `rank_name_lookup` | FK lookup | `rank_id`, `rank_name` | - | `smac_master_migration` |

### `seafarer_id_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
WITH filtered_numeric AS (
    SELECT source_id, target_id
    FROM migration.table_mappings
    WHERE target_table = 'seafarers'
      AND target_db = current_database()
      AND LENGTH(source_id) <= 20
      AND source_id !~ '[^0-9]'
)
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM filtered_numeric;
```

### `seafarer_uuid_mapping`

- **Output columns**: source_id, target_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
WITH filtered_mappings AS (
    SELECT source_id, target_id
    FROM migration.table_mappings
    WHERE target_table = 'seafarers'
      AND target_db = current_database()
      AND LENGTH(source_id) = 36
      AND source_id LIKE '________-____-____-____-____________'
      AND source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
)
SELECT source_id::uuid AS legacy_uuid, target_id AS new_id
FROM filtered_mappings;
```

### `rank_id_mapping`

- **Output columns**: legacy_rank_id, new_rank_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT source_id::bigint AS legacy_rank_id, target_id AS new_rank_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ranks'' AND LENGTH(source_id) <= 20 AND source_id !~ ''[^0-9]'''
) AS tm(source_id text, target_id uuid);
```

### `rank_name_lookup`

- **Output columns**: rank_id, rank_name
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_name_lookup AS
SELECT id AS rank_id, name AS rank_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.ranks WHERE id IS NOT NULL AND name IS NOT NULL'
) AS r(id uuid, name text);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_other_details'::VARCHAR(100), legacy_data.id::text, current_database()::text::VA... |
| 2 | derived | - | seafarer_id | - | COALESCE( seafarer_id_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) AS seafarer_id | COALESCE( seafarer_id_map.new_id, '00000000-0000-0000-0000-000000000000'::uuid ) |
| 3 | derived | - | form_type_id | - | NULLIF(current_setting('migration.form_type_id', true), '')::uuid AS form_type_id | NULLIF(current_setting('migration.form_type_id', true), '')::uuid |
| 4 | derived | - | form_definitions_id | - | NULLIF(current_setting('migration.form_definitions_id', true), '')::uuid AS form_definitions_id | NULLIF(current_setting('migration.form_definitions_id', true), '')::uuid |
| 5 | detail_response, seafarer_id | - | submission_data | - | COALESCE( ( WITH detail_array AS ( SELECT CASE WHEN legacy_data.detail_response IS NULL OR TRIM(legacy_data.detail_response) = '' THEN '[]'::jsonb WHEN legacy_data.detail_respon... | COALESCE( ( WITH detail_array AS ( SELECT CASE WHEN legacy_data.detail_response IS NULL OR TRIM(legacy_data.detail_response) = '' THEN '[]'::jsonb WHEN legacy_data.detail_respon... |
| 6 | derived | - | form_version | - | 1 AS form_version | 1 |
| 7 | derived | - | workflow_status_id | - | '00000000-0000-0000-0000-000000000000'::uuid AS workflow_status_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 8 | derived | - | is_verified | - | true AS is_verified | true |
| 9 | created_at | - | verified_at | - | COALESCE(legacy_data.created_at, NOW()) AS verified_at | COALESCE(legacy_data.created_at, NOW()) |
| 10 | - | - | verified_by_id | - | NULL | NULL::uuid |
| 11 | - | - | verification_notes | - | NULL | NULL::text |
| 12 | deleted_at | - | "Status" | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END AS "Status" | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END AS "Status" |
| 13 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 14 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 15 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 16 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 17 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 18 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
WITH filtered_numeric AS (
    SELECT source_id, target_id
    FROM migration.table_mappings
    WHERE target_table = 'seafarers'
      AND target_db = current_database()
      AND LENGTH(source_id) <= 20
      AND source_id !~ '[^0-9]'
)
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM filtered_numeric;
```

### 2. Seafarer Uuid ID Mapping
**Output columns**: `source_id, target_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
WITH filtered_mappings AS (
    SELECT source_id, target_id
    FROM migration.table_mappings
    WHERE target_table = 'seafarers'
      AND target_db = current_database()
      AND LENGTH(source_id) = 36
      AND source_id LIKE '________-____-____-____-____________'
      AND source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
)
SELECT source_id::uuid AS legacy_uuid, target_id AS new_id
FROM filtered_mappings;
```

### 3. Rank ID Mapping
**Output columns**: `legacy_rank_id, new_rank_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT source_id::bigint AS legacy_rank_id, target_id AS new_rank_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ranks'' AND LENGTH(source_id) <= 20 AND source_id !~ ''[^0-9]'''
) AS tm(source_id text, target_id uuid);
```

### 4. Rank Name ID Mapping
**Output columns**: `rank_id, rank_name`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE rank_name_lookup AS
SELECT id AS rank_id, name AS rank_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.ranks WHERE id IS NOT NULL AND name IS NOT NULL'
) AS r(id uuid, name text);
```

Full migration context: `04-migration-scripts/crewing/seafarer_important_declaration_details_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_important_declaration_details_validation.sql` if available
- Run `06-rollback/crewing/seafarer_important_declaration_details_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
