# Table Mapping: seafarer_departures → seafarer_attachments

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: seafarer_departures
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/seafarer_departure_attachments_migration.sql`

- **Legacy Path**: `synergy_manning.public.seafarer_departures`
- **New Path**: `smac_crewing_migration.public.seafarer_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Departure Attachments (`seafarer_departures` → `seafarer_attachments`)

## Migration Notes

- Source: `synergy_manning.public.seafarer_departures` where `file_name` or `file_url` IS NOT NULL
- Target: `public.seafarer_attachments` with `reference_entity = 'predeparture_checklist'`
- Uses `migration.resolve_target_id()` with source_table = `seafarer_departures`, target_table = `seafarer_attachments`
- `seafarer_id` via `seafarer_id_mapping`; `reference_id` via `departure_id_mapping`
- `file_content_type` split into `file_type` / `file_sub_type` (MIME parts)
- `deleted_at` drives status (`ACTIVE` / `DELETED`); `valid_from`/`valid_until` set NULL in script
- Requires `seafarers` and `seafarer_departures` migrated first

## Special Considerations

- Orchestration dependencies: `seafarers`, `seafarer_departures`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `departure_id_mapping` | C | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `departure_id_mapping`

- **Purpose**: C
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarer_departures

```sql
CREATE TEMP TABLE departure_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_departures'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_table=`seafarer_departures`, target_table=`seafarer_attachments` | Idempotent; maps departure id to attachment id |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping`; nil UUID default | Lookup: `seafarers` |
| 3 | `file_name` | varchar | `file_name` | text | `COALESCE(NULLIF(TRIM(file_name), ''), '')` | NOT NULL |
| 4 | `file_content_type` | varchar | `file_type` | text | `SPLIT_PART` before `/` | MIME type part |
| 5 | `file_content_type` | varchar | `file_sub_type` | text | `SPLIT_PART` after `/` | MIME subtype part |
| 6 | — | — | `master_document_id` | uuid | `NULL` | No SAC equivalent |
| 7 | `file_content_type` | varchar | `file_content_type` | text | `NULLIF(TRIM(file_content_type), '')` | Full MIME preserved |
| 8 | `file_size` | integer | `file_size` | bigint | `COALESCE(file_size::bigint, 0)` | Type cast |
| 9 | `file_url` | varchar | `file_url` | text | `COALESCE(NULLIF(TRIM(file_url), ''), '')` | Direct copy |
| 10 | — | — | `checksum` | text | `NULL` | No SAC equivalent |
| 11 | — | — | `reference_entity` | text | Hardcoded `'predeparture_checklist'` | SMAC reference type |
| 12 | `id` | bigint | `reference_id` | uuid | Map via `departure_id_mapping` | FK to `shore.seafarer_departures.id` |
| 13 | — | — | `version_number` | integer | Hardcoded `1` | Default |
| 14 | — | — | `valid_from` | date | `NULL` | Not populated in script |
| 15 | — | — | `valid_until` | date | `NULL` | Not populated in script |
| 16 | `deleted_at` | timestamp | `status` | text | `'DELETED'` / `'ACTIVE'` based on `deleted_at` | Soft-delete drives status |
| 17 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 18 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 19 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 20 | — | — | `archived_at` | timestamp | `NULL` | No SAC equivalent |
| 21 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy | Soft-delete preserved |
| 22 | `created_by_id`, `updated_by_id` | varchar | `audit_info` | jsonb | `migration.build_audit_info()` | Standardized SMAC audit structure |

**SMAC columns not migrated:** `master_document_id`, `checksum`, `valid_from`, `valid_until`, `archived_at` — no SAC source or not populated.

**SAC columns not migrated:** `seafarer_signed_at`, `shore_user_signed_at`, `shore_user_id`, `status`, `relief_id` — used in parent `seafarer_departures` migration, not attachment row.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.seafarers`
- `seafarer_departures`
- `seafarers`
- `shore.seafarer_departures`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### 2. Departure ID Mapping
**Purpose**: C
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarer_departures'`

```sql
CREATE TEMP TABLE departure_id_mapping AS
SELECT
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_departures'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/crewing/seafarer_departure_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_departure_attachments_validation.sql` if available
- Run `06-rollback/crewing/seafarer_departure_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
