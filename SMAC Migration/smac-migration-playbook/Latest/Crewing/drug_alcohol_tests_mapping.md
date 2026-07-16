# Table Mapping: drug_alcohol_tests → drug_alcohol_tests

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: drug_alcohol_test_details
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: drug_alcohol_tests
- **Source Script**: `04-migration-scripts/crewing/drug_alcohol_tests_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.drug_alcohol_test_details`
- **New Path**: `smac_crewing_migration.public.drug_alcohol_tests`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Drug Alcohol Test Details (`drug_alcohol_test_details` → `drug_alcohol_tests`)

## Migration Notes

- SAC `id` (UUID) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `id`
- `seafarer_id` (SAC UUID) mapped via `seafarers_id_mapping`; default nil UUID if unmapped
- `test_type_id` mapped via `test_types_id_mapping` (dblink `smac_master_migration`)
- `vessel_id`, `vessel_category_id`, `port_id` (bigint) mapped via master DB lookups (nullable)
- `program_type_id` = PERIODIC type from `drug_alcohol_program_types`; `workflow_status_id` = APPROVED from `workflow_status`
- `status` integer: `deleted_at IS NOT NULL` → Deleted (3), else Active (0) per `constants.sql`
- `port_info` in SAC not migrated to SMAC column (not in target table)

## Special Considerations

- Maps test_type_id from smac_master_migration, vessel_id/vessel_category_id/port_id from smac_master_migration
- Script performs `TRUNCATE TABLE public.drug_alcohol_tests` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `drug_alcohol_test_types`, `vessels`, `vessel_categories`, `ports`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | Check for duplicate UUIDs in source table | `seafarer_uuid`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `test_types_id_mapping` | SELECT migration.check_duplicate_uuids( | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessels_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_categories_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `ports_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |

### `seafarers_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: seafarer_uuid, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    target_id as seafarer_uuid,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `test_types_id_mapping`

- **Purpose**: SELECT migration.check_duplicate_uuids(
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE test_types_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''drug_alcohol_test_types'''
) AS t(source_id text, target_id uuid);
```

### `vessels_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'''
) AS t(source_id text, target_id uuid);
```

### `vessel_categories_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_categories_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''categories'''
) AS t(source_id text, target_id uuid);
```

### `ports_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE ports_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
) AS t(source_id text, target_id uuid);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC UUID |
| 2 | `seafarer_id` | uuid | `seafarer_id` | uuid | Map via `seafarers_id_mapping`; default nil UUID | Lookup: `seafarers` in crewing DB; NOT NULL |
| 3 | `date_of_test` | timestamp without time zone | `date_of_test` | date | Cast timestamp → date | NOT NULL |
| 4 | — | — | `program_type_id` | uuid | Subquery: PERIODIC from `drug_alcohol_program_types` | Lookup: dblink `smac_master_migration` |
| 5 | `test_type` | uuid | `test_type_id` | uuid | Map via `test_types_id_mapping`; default nil UUID | Lookup: `drug_alcohol_test_types`; NOT NULL |
| 6 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessels_id_mapping` | Lookup: `vessels` (dblink); nullable |
| 7 | `vessel_category_id` | bigint | `vessel_category_id` | uuid | Map via `vessel_categories_id_mapping` | Lookup: `vessel_categories` (dblink); nullable |
| 8 | `vessel_imo` | bigint | `vessel_imo` | character varying(10) | `LEFT(vessel_imo::text, 10)` when not NULL | Truncated to 10 chars |
| 9 | `port_id` | bigint | `port_id` | uuid | Map via `ports_id_mapping` | Lookup: `ports` (dblink); nullable |
| 10 | — | — | `result_notes` | text | `NULL` | No equivalent in SAC |
| 11 | — | — | `workflow_status_id` | uuid | Subquery: APPROVED from `workflow_status` | Lookup: dblink `smac_master_migration` |
| 12 | `is_verified` | boolean | `is_verified` | boolean | `COALESCE(is_verified, false)` | NOT NULL |
| 13 | `verified_at` | timestamp without time zone | `verified_at` | timestamp without time zone | Direct copy | Nullable |
| 14 | `audit_info` → `verified_by_id` | jsonb | `verified_by_id` | uuid | Extract UUID from legacy `audit_info` JSONB | Nullable |
| 15 | — | — | `verification_notes` | text | `NULL` | No equivalent in SAC |
| 16 | `remarks` | text | `remarks` | text | Direct copy | Nullable |
| 17 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per `constants.sql` Case 1 |
| 18 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 19 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL |
| 20 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | NOT NULL |
| 21 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 22 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 23 | `audit_info` | jsonb | `audit_info` | jsonb | `migration.build_audit_info()` — created/updated/deleted by from legacy JSONB | Standardized SMAC audit structure |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `port_info` — JSONB not stored in SMAC target table.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `drug_alcohol_test_types`
- `ports`
- `seafarers`
- `vessel_categories`
- `vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `seafarer_uuid, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    target_id as seafarer_uuid,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Test Types ID Mapping
**Purpose**: SELECT migration.check_duplicate_uuids(
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE test_types_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''drug_alcohol_test_types'''
) AS t(source_id text, target_id uuid);
```

### 3. Vessels ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''vessels'''
) AS t(source_id text, target_id uuid);
```

### 4. Vessel Categories ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_categories_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''categories'''
) AS t(source_id text, target_id uuid);
```

### 5. Ports ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE ports_id_mapping AS
SELECT
    t.source_id::text as legacy_id,
    t.target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ports'''
) AS t(source_id text, target_id uuid);
```

Full migration context: `04-migration-scripts/crewing/drug_alcohol_tests_migration.sql`

## Validation

- Run `05-validation/crewing/drug_alcohol_tests_validation.sql` if available
- Run `06-rollback/crewing/drug_alcohol_tests_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
