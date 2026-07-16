# Table Mapping: seafarer_remarks_attachments → seafarer_attachments

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/seafarer_remarks_attachments_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_remarks.profile_remark.supporting_documents[]`
- **New Path**: `smac_crewing_migration.public.seafarer_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Remarks Supporting Documents (`seafarer_remarks` → `seafarer_attachments`)

## Migration Notes

- Unnests `supporting_documents` from `seafarer_remarks.profile_remark` JSONB array elements
- Filter: only remarks with non-empty `supporting_documents` array
- `id` via `migration.resolve_target_id()` — composite source_id = `remark_id || '_doc_' || doc_idx`
- `seafarer_id` via `seafarer_id_mapping`; nil UUID if unmapped
- `reference_entity` hardcoded `'seafarer_remarks'`; `reference_id` via `seafarer_remarks_id_mapping`
- File metadata extracted from JSON: `file_name`, `file_content_type`, `file_size`, `url`
- `file_content_type` split on `/` into `file_type` / `file_sub_type`
- `status` hardcoded `'ACTIVE'`; `deleted_at` = `NULL`
- Requires `seafarers` and `seafarer_remarks` migrated first

## Special Considerations

- Orchestration dependencies: `seafarers`, `seafarer_remarks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_id_mapping` | Clear existing data from target table (only | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `seafarer_remarks_id_mapping` | FK lookup | `legacy_id_text`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_id_mapping`

- **Purpose**: Clear existing data from target table (only
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

### `seafarer_remarks_id_mapping`

- **Output columns**: legacy_id_text, new_id
- **migration.table_mappings**: target_table=seafarer_remarks

```sql
CREATE TEMP TABLE seafarer_remarks_id_mapping AS
SELECT
    source_id AS legacy_id_text,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_remarks'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, doc index | bigint, integer | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text \|\| '_doc_' \|\| doc_idx` | Composite business key per document |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping`; nil UUID if unmapped | Lookup: `table_mappings` where `target_table = 'seafarers'` |
| 3 | `supporting_documents` → `file_name` | jsonb | `file_name` | text | `COALESCE(NULLIF(TRIM(doc->>'file_name'), ''), '')` | Extracted from unnested JSON element |
| 4 | `supporting_documents` → `file_content_type` | jsonb | `file_type` | text | `SPLIT_PART` before `/`; else `'application'` | MIME major part from JSON |
| 5 | `supporting_documents` → `file_content_type` | jsonb | `file_sub_type` | text | `SPLIT_PART` after `/`; else `NULL` | MIME minor part from JSON |
| 6 | — | — | `master_document_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 7 | `supporting_documents` → `file_content_type` | jsonb | `file_content_type` | text | `NULLIF(TRIM(doc->>'file_content_type'), '')` | Full MIME from JSON |
| 8 | `supporting_documents` → `file_size` | jsonb | `file_size` | bigint | `COALESCE((doc->>'file_size')::bigint, 0)` | From JSON element |
| 9 | `supporting_documents` → `url` | jsonb | `file_url` | text | `COALESCE(NULLIF(TRIM(doc->>'url'), ''), '')` | From JSON element |
| 10 | — | — | `checksum` | text | `NULL` | No equivalent in SAC; not populated |
| 11 | — | — | `reference_entity` | text | Hardcoded `'seafarer_remarks'` | Parent entity type |
| 12 | `id` | bigint | `reference_id` | uuid | Map via `seafarer_remarks_id_mapping` | Links to parent remark SMAC row |
| 13 | — | — | `version_number` | integer | Hardcoded `1` | Initial version |
| 14 | — | — | `valid_from` | date | `NULL` | No equivalent in SAC; not populated |
| 15 | — | — | `valid_until` | date | `NULL` | No equivalent in SAC; not populated |
| 16 | — | — | `status` | text | Hardcoded `'ACTIVE'` | All migrated attachments active |
| 17 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 18 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | From parent remark row |
| 19 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | From parent remark row |
| 20 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 21 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Not populated for attachments |
| 22 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all audit fields NULL | Source remark has no per-doc audit |

**SMAC columns not migrated:** None beyond defaults.

**SAC columns not migrated:** `profile_remark` fields other than `supporting_documents` (remark text migrated in `seafarer_remarks` script).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.seafarer_remarks`
- `public.seafarers`
- `seafarer_remarks`
- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer ID Mapping
**Purpose**: Clear existing data from target table (only
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

### 2. Seafarer Remarks ID Mapping
**Output columns**: `legacy_id_text, new_id`
**migration.table_mappings**: `target_table='seafarer_remarks'`

```sql
CREATE TEMP TABLE seafarer_remarks_id_mapping AS
SELECT
    source_id AS legacy_id_text,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_remarks'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_remarks_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_remarks_attachments_validation.sql` if available
- Run `06-rollback/crewing/seafarer_remarks_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
