# Table Mapping: seafarer_movements_attachments → seafarer_attachments

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/seafarer_movements_attachments_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.dg_sign_on_sign_offs.file_attachment_ids[]`
- **New Path**: `smac_crewing_migration.public.seafarer_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Movements Attachments (`dg_sign_on_sign_offs` → `seafarer_attachments`)

## Migration Notes

- Unnests `dg_sign_on_sign_offs.file_attachment_ids` JSONB array — one SMAC row per file
- Filter: `jsonb_array_length(file_attachment_ids) > 0`
- Joins each file id to SAC `dg_file_attachments` for file metadata
- `id` via `migration.resolve_target_id()` with `p_target_id = NULL` (source = `dg_file_attachments.id`)
- `seafarer_id` via `seafarer_uuid_mapping` (match on `public.seafarers.id`); nil UUID if unmapped
- `reference_entity` hardcoded `'seafarer_movements'`; `reference_id` via `seafarer_movements_id_mapping`
- `content_type` split on `/` into `file_type` / `file_sub_type`
- `status`: either `dg_file` or parent `deleted_at` set → `'DELETED'`, else `'ACTIVE'`
- Requires `seafarers` and `seafarer_movements` migrated first

## Special Considerations

- Orchestration dependencies: `seafarers`, `seafarer_movements`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_uuid_mapping` | FK lookup | `target_id`, `seafarer_uuid_text` | - | - |
| `seafarer_movements_id_mapping` | FK lookup | `legacy_id_text`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_uuid_mapping`

- **Output columns**: target_id, seafarer_uuid_text

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT DISTINCT
    s.id as target_id,
    s.id::text as seafarer_uuid_text
FROM public.seafarers s
WHERE s.id IS NOT NULL;
```

### `seafarer_movements_id_mapping`

- **Output columns**: legacy_id_text, new_id
- **migration.table_mappings**: target_table=seafarer_movements

```sql
CREATE TEMP TABLE seafarer_movements_id_mapping AS
SELECT
    source_id AS legacy_id_text,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_movements'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `dg_file_attachments.id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `dg_file.id::text`; `p_target_id = NULL` | Idempotent UUID per file attachment |
| 2 | `seafarer_uuid` | uuid | `seafarer_id` | uuid | Map via `seafarer_uuid_mapping`; nil UUID if unmapped | Lookup: `public.seafarers.id` |
| 3 | `original_file_name` | text | `file_name` | text | `COALESCE(NULLIF(TRIM(original_file_name), ''), '')` | From `dg_file_attachments` |
| 4 | `content_type` | text | `file_type` | text | `SPLIT_PART` before `/`; else `'application'` | MIME major part |
| 5 | `content_type` | text | `file_sub_type` | text | `SPLIT_PART` after `/`; else `NULL` | MIME minor part |
| 6 | — | — | `master_document_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 7 | `content_type` | text | `file_content_type` | text | `NULLIF(TRIM(content_type), '')` | Full MIME string |
| 8 | `content_size` | text | `file_size` | bigint | Cast to bigint when numeric; else 0 | SAC stores size as text |
| 9 | `file_path` | text | `file_url` | text | `COALESCE(NULLIF(TRIM(file_path), ''), '')` | SAC path → SMAC URL |
| 10 | — | — | `checksum` | text | `NULL` | No equivalent in SAC; not populated |
| 11 | — | — | `reference_entity` | text | Hardcoded `'seafarer_movements'` | Parent entity type |
| 12 | `dg_sign_on_sign_offs.id` | uuid | `reference_id` | uuid | Map via `seafarer_movements_id_mapping` | Links to parent movement record |
| 13 | — | — | `version_number` | integer | Hardcoded `1` | Initial version |
| 14 | — | — | `valid_from` | date | `NULL` | No equivalent in SAC; not populated |
| 15 | — | — | `valid_until` | date | `NULL` | No equivalent in SAC; not populated |
| 16 | `deleted_at` (file + parent) | timestamp | `status` | text | Either deleted_at set → `'DELETED'`; else `'ACTIVE'` | Checks both file and parent row |
| 17 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 18 | `created_at` (file + parent) | timestamp | `created_at` | timestamp without time zone | `COALESCE(dg_file.created_at, parent.created_at, NOW())` | Multi-source fallback |
| 19 | `updated_at` (file + parent) | timestamp | `updated_at` | timestamp without time zone | `COALESCE(dg_file.updated_at, parent.updated_at, NOW())` | Multi-source fallback |
| 20 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 21 | `deleted_at` (file + parent) | timestamp | `deleted_at` | timestamp without time zone | `COALESCE(dg_file.deleted_at, parent.deleted_at)` | Either source may carry delete |
| 22 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all audit fields NULL | Source has no audit columns |

**SMAC columns not migrated:** None beyond defaults.

**SAC columns not migrated:** `file_attachment_ids` array elements (ids only — metadata from `dg_file_attachments`).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.seafarers`
- `seafarer_movements`
- `seafarers`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer Uuid ID Mapping
**Output columns**: `target_id, seafarer_uuid_text`

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT DISTINCT
    s.id as target_id,
    s.id::text as seafarer_uuid_text
FROM public.seafarers s
WHERE s.id IS NOT NULL;
```

### 2. Seafarer Movements ID Mapping
**Output columns**: `legacy_id_text, new_id`
**migration.table_mappings**: `target_table='seafarer_movements'`

```sql
CREATE TEMP TABLE seafarer_movements_id_mapping AS
SELECT
    source_id AS legacy_id_text,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_movements'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_movements_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_movements_attachments_validation.sql` if available
- Run `06-rollback/crewing/seafarer_movements_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
