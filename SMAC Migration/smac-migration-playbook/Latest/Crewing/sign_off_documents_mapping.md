# Table Mapping: seafarer_signoff_documents → sign_off_documents

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: seafarer_signoff_documents
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: sign_off_documents
- **Source Script**: `04-migration-scripts/crewing/sign_off_documents_migration.sql`

- **Legacy Path**: `synergy_manning.public.seafarer_signoff_documents`
- **New Path**: `smac_crewing_migration.public.sign_off_documents`

## Business Key

- **Business Key**: `mapper_uuid`
- **Source (orchestration)**: Sign Off Documents (`seafarer_signoff_documents` → `sign_off_documents`)

## Migration Notes

- Source `seafarer_signoff_documents` → `public.sign_off_documents`
- `id` via `migration.resolve_target_id()` from bigint `id` (`p_target_id = NULL`) — `mapper_uuid` has duplicates, not used
- `sign_off_detail_id` → `sign_off_id` via `signoff_id_mapping` (INNER JOIN required)
- `master_document_id` copied directly to `seafarer_document_id`
- `DISTINCT ON (sign_off_detail_id, master_document_id)` deduplication
- Filter: `sign_off_detail_id IS NOT NULL AND master_document_id IS NOT NULL`
- Requires `sign_off_details` mappings migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.sign_off_documents` before insert (full table reload).
- Orchestration dependencies: `signoff_details`, `seafarer_documents`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `signoff_id_mapping` | FK lookup | `legacy_signoff_detail_id`, `sign_off_id` | `migration.table_mappings` (see SQL) | - |

### `signoff_id_mapping`

- **Output columns**: legacy_signoff_detail_id, sign_off_id
- **migration.table_mappings**: target_table=sign_off_details

```sql
CREATE TEMP TABLE signoff_id_mapping AS
SELECT
    source_id::bigint AS legacy_signoff_detail_id,
    target_id AS sign_off_id
FROM migration.table_mappings
WHERE target_table = 'sign_off_details'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — new UUID (`p_target_id = NULL`) | Not `mapper_uuid` |
| 2 | `sign_off_detail_id` | bigint | `sign_off_id` | uuid | Via `signoff_id_mapping` | INNER JOIN required |
| 3 | `master_document_id` | uuid | `seafarer_document_id` | uuid | Direct copy | |
| 4 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 5 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | |
| 6 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | |
| 7 | — | — | `archived_at` | timestamp without time zone | `NULL` | |
| 8 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | |
| 9 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | character varying | `audit_info` | jsonb | `migration.build_audit_info()` — names in `notes` | Standardized SMAC audit structure; no `legacy_id` |
| 10 | `deleted_at` | timestamp without time zone | `status` | text | `'Deleted'` / `'Active'` | Derived from `deleted_at` |

**SMAC columns not migrated:** `archived_at` — always NULL.

**SAC columns not migrated:** `mapper_uuid` — explicitly not used (duplicates in source).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_documents`
- `signoff_details`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Signoff ID Mapping
**Output columns**: `legacy_signoff_detail_id, sign_off_id`
**migration.table_mappings**: `target_table='sign_off_details'`

```sql
CREATE TEMP TABLE signoff_id_mapping AS
SELECT
    source_id::bigint AS legacy_signoff_detail_id,
    target_id AS sign_off_id
FROM migration.table_mappings
WHERE target_table = 'sign_off_details'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

Full migration context: `04-migration-scripts/crewing/sign_off_documents_migration.sql`

## Validation

- Run `05-validation/crewing/sign_off_documents_validation.sql` if available
- Run `06-rollback/crewing/sign_off_documents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
