# Table Mapping: seafarer_attachments → seafarer_attachments

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_attachments
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/seafarer_debrief_attachments_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_attachments`
- **New Path**: `smac_crewing_migration.public.seafarer_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Debrief Attachments (`seafarer_attachments` → `seafarer_attachments`)

## Migration Notes

- Source: `synergy_seafarer.public.seafarer_attachments` filtered to `entity_type = 'APPRAISAL_DEBRIEF'`
- SAC `uuid` preserved as target `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- `seafarer_uuid` (varchar) → `seafarer_id` via `seafarers.id` direct match
- `entity_uuid` joined to `shore.seafarer_debriefs.id` for `reference_id`; `reference_entity = 'seafarer_debriefs'`
- `file_content_type` split into `file_type` / `file_sub_type` (MIME before/after `/`); default `file_type = 'application'`
- `url` → `file_url`; `deleted_at` drives status (`ACTIVE` / `DELETED`)
- Requires `seafarers` and `seafarer_debriefs` migrated first

## Special Considerations

- Orchestration dependencies: `seafarers`, `seafarer_debriefs`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_uuid_mapping` | FK lookup | `target_id`, `seafarer_uuid_text` | - | - |

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

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `uuid` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC `uuid` |
| 2 | `seafarer_uuid` | varchar | `seafarer_id` | uuid | Join `seafarer_uuid_mapping`; nil UUID default | FK to `seafarers.id` |
| 3 | `file_name` | varchar | `file_name` | text | `COALESCE(NULLIF(TRIM(file_name), ''), '')` | NOT NULL |
| 4 | `file_content_type` | varchar | `file_type` | text | `SPLIT_PART` before `/`; else `'application'` | MIME type part |
| 5 | `file_content_type` | varchar | `file_sub_type` | text | `SPLIT_PART` after `/`; else NULL | MIME subtype part |
| 6 | — | — | `master_document_id` | uuid | `NULL` | No SAC equivalent |
| 7 | `file_content_type` | varchar | `file_content_type` | text | `NULLIF(TRIM(file_content_type), '')` | Full MIME string preserved |
| 8 | `file_size` | integer | `file_size` | bigint | `COALESCE(file_size::bigint, 0)` | Type cast int → bigint |
| 9 | `url` | varchar | `file_url` | text | `COALESCE(NULLIF(TRIM(url), ''), '')` | Column rename |
| 10 | — | — | `checksum` | text | `NULL` | No SAC equivalent |
| 11 | `entity_type` | varchar | `reference_entity` | text | `'seafarer_debriefs'` when `APPRAISAL_DEBRIEF` | Hardcoded entity name |
| 12 | `entity_uuid` | uuid | `reference_id` | uuid | Join `shore.seafarer_debriefs` on `entity_uuid` | FK to parent debrief |
| 13 | — | — | `version_number` | integer | Hardcoded `1` | Default for migrated records |
| 14 | — | — | `valid_from` | date | `NULL` | No SAC equivalent |
| 15 | — | — | `valid_until` | date | `NULL` | No SAC equivalent |
| 16 | `deleted_at` | timestamp | `status` | text | `'DELETED'` when `deleted_at IS NOT NULL`, else `'ACTIVE'` | Soft-delete drives status |
| 17 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 18 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 19 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 20 | — | — | `archived_at` | timestamp | `NULL` | No SAC equivalent |
| 21 | `deleted_at` | timestamp | `deleted_at` | timestamp | Direct copy | Soft-delete preserved |
| 22 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all audit params NULL | No audit columns in SAC source |

**SMAC columns not migrated:** `master_document_id`, `checksum`, `valid_from`, `valid_until` — no SAC source equivalents.

**SAC columns not migrated:** `document_type` — not referenced in migration script.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.seafarers`
- `seafarer_debriefs`
- `seafarers`
- `shore.seafarer_debriefs`

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

Full migration context: `04-migration-scripts/crewing/seafarer_debrief_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_debrief_attachments_validation.sql` if available
- Run `06-rollback/crewing/seafarer_debrief_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
