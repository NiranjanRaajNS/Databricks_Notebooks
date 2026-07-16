# Table Mapping: vessel_details → vessel_revision_services

## Overview
- **Legacy Database**: synergy_vessel
- **Legacy Schema**: public
- **Legacy Table**: vessel_details
- **New Database**: smac_master_migration
- **New Schema**: vessel
- **New Table**: vessel_revision_services
- **Source Script**: `04-migration-scripts/master/vessel_revision_services_migration.sql`

- **Legacy Path**: `synergy_vessel.public.vessel_details`
- **New Path**: `smac_master_migration.vessel.vessel_revision_services`

## Business Key

- **Composite Key**: (`vessel_revision_id`, `service_type_id`)
- **Source (orchestration)**: Vessel Revision Services (`vessel_details` → `vessel_revision_services`)

## Migration Notes

- Source: `synergy_vessel.public.vessel_details` → `vessel.vessel_revision_services`
- SAC `id` + service name → composite `source_id` for `migration.resolve_target_id()` (e.g. `id|Crewing`, `id|Technical`, `id|Accounting`)
- `service_type = 1` (Crewing and Technical) splits into two rows: Crewing + Technical
- `service_type = 2/3/4` produces one row each (Technical, Crewing, Procurement)
- Extra Accounting row per vessel revision via `DISTINCT ON (identifier)` subquery
- `vessel_revision_id` = SAC `identifier` (direct UUID copy)
- `vessel_id` via `vessel_id_mapping` (`vessel_details.vessel_id` bigint → `vessel.vessels.id` uuid)
- `service_type_id` via `service_type_*_lookup` temp tables → `public.service_types`
- Filter: `service_type IS NOT NULL`; INNER JOIN on `vessel_id_mapping`
- Requires `vessel_revisions`, `vessels`, and `public.service_types` migrated first
- Mappings stored via `migration.resolve_target_id()` / `migration.check_existing_mapping()` for idempotent re-runs

## Special Considerations

- Uses `migration.resolve_target_id()` with composite source IDs for unpivot scenario (one source record can generate multiple target records)
- Unpivots `service_type` integer into individual `vessel_revision_services` records
- Script performs `TRUNCATE TABLE vessel.vessel_revision_services` before insert (full table reload)
- Orchestration dependencies: `vessel_revisions`, `vessels`, `service_types`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `vessel_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `service_type_crewing_lookup` | FK lookup | `service_type_id` | - | - |
| `service_type_technical_lookup` | FK lookup | `service_type_id` | - | - |
| `service_type_procurement_lookup` | FK lookup | `service_type_id` | - | - |
| `service_type_accounting_lookup` | FK lookup | `service_type_id` | - | - |

### `vessel_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=vessels

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### `service_type_crewing_lookup`

- **Output columns**: service_type_id

```sql
CREATE TEMP TABLE service_type_crewing_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'crewing'
LIMIT 1;
```

### `service_type_technical_lookup`

- **Output columns**: service_type_id

```sql
CREATE TEMP TABLE service_type_technical_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'technical'
LIMIT 1;
```

### `service_type_procurement_lookup`

- **Output columns**: service_type_id

```sql
CREATE TEMP TABLE service_type_procurement_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'procurement'
LIMIT 1;
```

### `service_type_accounting_lookup`

- **Output columns**: service_type_id

```sql
CREATE TEMP TABLE service_type_accounting_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'accounting'
LIMIT 1;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id, service_type name` | bigint, integer | `id` | uuid | `migration.resolve_target_id()` — composite source_id = `id\|Crewing`, `id\|Technical`, `id\|Procurement`, `id\|Accounting`, etc. | Multiple rows per source when `service_type = 1`; idempotent via `id_mappings` |
| 2 | `vessel_id` | bigint | `vessel_id` | uuid | Map via `vessel_id_mapping` | INNER JOIN required — rows without vessel mapping are excluded |
| 3 | `identifier` | uuid | `vessel_revision_id` | uuid | Direct copy of `identifier` | FK to `vessel_revisions` |
| 4 | `service_type` | integer | `service_type_id` | uuid | 1→crewing+technical (2 rows); 2→technical; 3→crewing; 4→procurement; +accounting row per revision | FK lookup via `service_type_*_lookup`; fallback zero UUID when lookup missing |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 6 | — | — | `parent_id` | uuid | Hardcoded NULL | Not in SAC source |
| 7 | — | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 8 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 9 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 10 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 11 | — | — | `archived_at` | timestamp without time zone | Hardcoded NULL | Not in SAC source |
| 12 | `audit_info` | jsonb | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID`; extracts `approved_at`, `approved_by`, `approval_notes`, `rejected_by` from SAC `audit_info`; names in `notes` | Pattern 4 — composite `source_id` used for `id` |
| 13 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 14 | `service_type name` | — | `tags` | text[] | `ARRAY[service_type_name, branch_label]` e.g. `['crewing', 'Crewing']` | Derived tag per unpivot branch |
| 15 | `status, deleted_at` | character varying, timestamp without time zone | `status` | integer | Rule 2.2.1 Case 2: `deleted_at IS NOT NULL` → 3; `status` NULL/blank → 0; ACTIVE/'0'→0; DRAFT/'1'→1; INACTIVE/'2'→2; DELETED/'3'→3; numeric string → integer; ELSE 0 | Crewing branch (type=1) uses alternate numeric mapping for '0'/'1' |
| 16 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Not sourced from SAC |
| 17 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Not sourced from SAC |

**SAC columns not migrated:** Other `vessel_details` columns — handled in other vessel migrations.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.service_types`
- `vessel.vessel_revisions`
- `vessel.vessels`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Vessel ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='vessels'`

```sql
CREATE TEMP TABLE vessel_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 2. Service Type Crewing ID Mapping
**Output columns**: `service_type_id`

```sql
CREATE TEMP TABLE service_type_crewing_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'crewing'
LIMIT 1;
```

### 3. Service Type Technical ID Mapping
**Output columns**: `service_type_id`

```sql
CREATE TEMP TABLE service_type_technical_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'technical'
LIMIT 1;
```

### 4. Service Type Procurement ID Mapping
**Output columns**: `service_type_id`

```sql
CREATE TEMP TABLE service_type_procurement_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'procurement'
LIMIT 1;
```

### 5. Service Type Accounting ID Mapping
**Output columns**: `service_type_id`

```sql
CREATE TEMP TABLE service_type_accounting_lookup AS
SELECT id AS service_type_id
FROM public.service_types
WHERE LOWER(TRIM(name)) = 'accounting'
LIMIT 1;
```

Full migration context: `04-migration-scripts/master/vessel_revision_services_migration.sql`

## Validation

- Run `05-validation/master/vessel_revision_services_validation.sql` if available
- Run `06-rollback/master/vessel_revision_services_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
