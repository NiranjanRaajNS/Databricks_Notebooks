# Table Mapping: dg_sign_on_sign_offs → seafarer_attachments

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: dg_sign_on_sign_offs
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/seafarer_dg_documents_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.dg_sign_on_sign_offs`
- **New Path**: `smac_crewing_migration.public.seafarer_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer DG Documents (`dg_sign_on_sign_offs` / `dg_file_attachments` → `seafarer_attachments`)

## Migration Notes

- Source: `dg_sign_on_sign_offs.file_attachment_ids` (JSONB array) unnested and joined to `dg_file_attachments`
- Target: `public.seafarer_attachments` (same table as other attachment migrations)
- Uses `migration.resolve_target_id()` with source_table=`dg_file_attachments`, target_table=`seafarer_attachments`
- `reference_entity = 'SeafarerMovement'`; `reference_id` from `seafarer_movements` mapping via `dg_sign_on_sign_offs.id`
- `file_sub_type` hardcoded `'DgSignOnSignOff'`; `original_file_name` → `file_name`, `file_path` → `file_url`
- `seafarer_id` from movement/seafarer lookup; requires `seafarer_movements` and `seafarers`

## Special Considerations

- Orchestration dependencies: `seafarers`, `seafarer_movements`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_movements_id_mapping` | FK lookup | `legacy_movement_id`, `movement_id` | `migration.table_mappings` (see SQL) | - |

### `seafarer_movements_id_mapping`

- **Output columns**: legacy_movement_id, movement_id
- **migration.table_mappings**: target_table=seafarer_movements

```sql
CREATE TEMP TABLE seafarer_movements_id_mapping AS
SELECT
    source_id::text AS legacy_movement_id,
    target_id AS movement_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_movements'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `dg_file_attachments.id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_table=`dg_file_attachments` | Idempotent UUID per file attachment |
| 2 | - | uuid | `seafarer_id` | uuid | `COALESCE(seafarer_id_from_movement.seafarer_id, nil UUID)` via `seafarer_movements_id_mapping` | Lookup: `shore.seafarer_movements` joined on movement mapping |
| 3 | `original_file_name` | varchar | `file_name` | text | `COALESCE(NULLIF(TRIM(original_file_name), ''), 'unnamed_file')` | NOT NULL default |
| 4 | `content_type` | varchar | `file_type` | text | `COALESCE(NULLIF(TRIM(content_type), ''), '')` | MIME/type string |
| 5 | — | — | `file_sub_type` | text | Hardcoded `'DgSignOnSignOff'` | SMAC classification |
| 6 | — | — | `master_document_id` | uuid | `NULL` | No SAC equivalent |
| 7 | — | — | `file_content_type` | text | `NULL` | Not populated from SAC |
| 8 | `content_size` | integer | `file_size` | bigint | `CAST(COALESCE(content_size, 0) AS bigint)` | Type cast |
| 9 | `file_path` | varchar | `file_url` | text | `COALESCE(NULLIF(TRIM(file_path), ''), '')` | Column rename |
| 10 | — | — | `checksum` | text | `NULL` | No SAC equivalent |
| 11 | — | — | `reference_entity` | text | Hardcoded `'SeafarerMovement'` | SMAC reference type |
| 12 | `dg_sign_on_sign_offs.id` | bigint | `reference_id` | uuid | Map via `seafarer_movements_id_mapping` | FK to `seafarer_movements.id` |
| 13 | — | — | `version_number` | integer | Hardcoded `1` | Default |
| 14 | — | — | `valid_from` | date | `NULL` | No SAC equivalent |
| 15 | — | — | `valid_until` | date | `NULL` | No SAC equivalent |
| 16 | `deleted_at` | timestamp | `status` | text | `'DELETED'` / `'ACTIVE'` based on `deleted_at` | Soft-delete drives status |
| 17 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 18 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 19 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 20 | — | — | `archived_at` | timestamp | `NULL` | No SAC equivalent |
| 21 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy | Soft-delete preserved |
| 22 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all params NULL | No audit columns in SAC source |

**SMAC columns not migrated:** `master_document_id`, `file_content_type`, `checksum`, `valid_from`, `valid_until`, `archived_at` — no SAC source equivalents.

**SAC columns not migrated:** `file_attachment_ids` on `dg_sign_on_sign_offs` — used only to unnest/join; not stored as column.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarer_movements`
- `seafarers`
- `shore.seafarer_movements`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarer Movements ID Mapping
**Output columns**: `legacy_movement_id, movement_id`
**migration.table_mappings**: `target_table='seafarer_movements'`

```sql
CREATE TEMP TABLE seafarer_movements_id_mapping AS
SELECT
    source_id::text AS legacy_movement_id,
    target_id AS movement_id
FROM migration.table_mappings
WHERE target_table = 'seafarer_movements'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_dg_documents_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_dg_documents_validation.sql` if available
- Run `06-rollback/crewing/seafarer_dg_documents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
