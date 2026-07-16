# Table Mapping: seafarer_remarks → seafarer_remarks

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_remarks
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_remarks
- **Source Script**: `04-migration-scripts/crewing/seafarer_remarks_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_remarks`
- **New Path**: `smac_crewing_migration.shore.seafarer_remarks`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Remarks (`seafarer_remarks` → `seafarer_remarks`)

## Migration Notes

- Generate new UUID for id (source table has bigint id)
- Map seafarer_id (bigint) → seafarer_id (uuid) via migration.table_mappings
- Map SAC remark_type → crewing.profile_remark_types.name (lookup uses LOWER(name)):
- profile_remark_reason_id: SAC remark_json->>'remark_identifier' → legacy seafarer_profile_remarks.id;
- Map created_by_id (varchar) → created_by_id (uuid)
- Uses standardized SMAC audit_info structure
- Migrates seafarer_remarks table. Generates new UUIDs for id column (source has bigint, target has uuid). Maps seafarer_id (bigint) to uuid via migration.table_mappings. Extracts remark_text from profile_remark JSONB. Maps created_by_id (varchar) to uuid. Uses standardized SMAC audit_info structure. Requires seafarers table to be migrated first.

## Special Considerations

- Extract remark_text from profile_remark JSONB
- Script performs `TRUNCATE TABLE shore.seafarer_remarks` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |
| `profile_remark_type_mapping` | FK lookup | `name_lower`, `target_id` | - | `smac_master_migration` |
| `profile_remark_reason_mappings` | Create profile_remark_types lookup mapping by name (SMAC LOWER(name) → id | `x.source_id`, `x.target_id` | `?.?.seafarer_profile_remarks` → `?.?.profile_remark_reasons` | `smac_master_migration` |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `profile_remark_type_mapping`

- **Output columns**: name_lower, target_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_remark_type_mapping AS
SELECT
    LOWER(TRIM(name)) AS name_lower,
    id AS target_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM crewing.profile_remark_types'
) AS t(id uuid, name text);
```

### `profile_remark_reason_mappings`

- **Purpose**: Create profile_remark_types lookup mapping by name (SMAC LOWER(name) → id
- **Output columns**: x.source_id, x.target_id
- **migration.table_mappings**: source_table=seafarer_profile_remarks, target_table=profile_remark_reasons
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_remark_reason_mappings AS
SELECT x.source_id, x.target_id
FROM dblink(
    'smac_master_migration',
    $q$
    SELECT DISTINCT ON (norm.source_id)
        norm.source_id,
        norm.target_id
    FROM (
        SELECT
            CASE
                WHEN trim(coalesce(tm.source_id, '')) ~ '^[0-9]+$'
                THEN trim(tm.source_id)::bigint::text
                ELSE trim(tm.source_id)
            END AS source_id,
            tm.target_id
        FROM migration.table_mappings tm
        WHERE tm.target_table = 'profile_remark_reasons'
          AND tm.source_table = 'seafarer_profile_remarks'
          AND trim(coalesce(tm.source_id, '')) <> ''
    ) AS norm
    ORDER BY norm.source_id, norm.target_id
    $q$
) AS x(source_id text, target_id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | DISTINCT ON ( legacy_data.id::text || '|' || remark_obj.ordinality::text ) migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_remar... |
| 2 | derived | - | seafarer_id | - | COALESCE(seafarer_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid) AS seafarer_id | COALESCE(seafarer_mapping.target_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | profile_remark_type_id | - | prt_mapping.target_id AS profile_remark_type_id | prt_mapping.target_id |
| 4 | derived | - | profile_remark_reason_id | - | prr_mapping.target_id AS profile_remark_reason_id | prr_mapping.target_id |
| 5 | derived | - | remark_text | - | COALESCE( remark_obj.remark_json->>'remark', '' ) AS remark_text | COALESCE( remark_obj.remark_json->>'remark', '' ) |
| 6 | - | - | severity | - | NULL | NULL::text |
| 7 | derived | - | visibility | - | 'internal'::varchar(50) AS visibility | 'internal'::varchar(50) |
| 8 | - | - | related_entity | - | NULL | NULL::text |
| 9 | - | - | related_entity_id | - | NULL | NULL::uuid |
| 10 | created_by_id | - | created_by_id | - | CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_data.created_by_id::... | CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN legacy_data.created_by_id::... |
| 11 | derived | - | status | - | 'Active'::varchar(50) AS status | 'Active'::varchar(50) |
| 12 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 13 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 14 | updated_at, created_at | - | updated_at | - | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, legacy_data.created_at, NOW()) |
| 15 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 16 | derived | - | deleted_at | - | NULL AS deleted_at | NULL |
| 17 | created_by_id, updated_by_id, created_by_name, updated_by_name | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.created_by_id IS NOT NULL AND legacy_data.created_by_id::text <> '' THEN legacy_data.created_by_id::text ELSE NULL END::varchar... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS target_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Profile Remark Type ID Mapping
**Output columns**: `name_lower, target_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_remark_type_mapping AS
SELECT
    LOWER(TRIM(name)) AS name_lower,
    id AS target_id
FROM dblink('smac_master_migration',
    'SELECT id, name FROM crewing.profile_remark_types'
) AS t(id uuid, name text);
```

### 3. Profile Remark Reason Mappings ID Mapping
**Purpose**: Create profile_remark_types lookup mapping by name (SMAC LOWER(name) → id
**Output columns**: `x.source_id, x.target_id`
**migration.table_mappings**: `seafarer_profile_remarks` → `profile_remark_reasons`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE profile_remark_reason_mappings AS
SELECT x.source_id, x.target_id
FROM dblink(
    'smac_master_migration',
    $q$
    SELECT DISTINCT ON (norm.source_id)
        norm.source_id,
        norm.target_id
    FROM (
        SELECT
            CASE
                WHEN trim(coalesce(tm.source_id, '')) ~ '^[0-9]+$'
                THEN trim(tm.source_id)::bigint::text
                ELSE trim(tm.source_id)
            END AS source_id,
            tm.target_id
        FROM migration.table_mappings tm
        WHERE tm.target_table = 'profile_remark_reasons'
          AND tm.source_table = 'seafarer_profile_remarks'
          AND trim(coalesce(tm.source_id, '')) <> ''
    ) AS norm
    ORDER BY norm.source_id, norm.target_id
    $q$
) AS x(source_id text, target_id uuid);
```

Full migration context: `04-migration-scripts/crewing/seafarer_remarks_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_remarks_validation.sql` if available
- Run `06-rollback/crewing/seafarer_remarks_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
