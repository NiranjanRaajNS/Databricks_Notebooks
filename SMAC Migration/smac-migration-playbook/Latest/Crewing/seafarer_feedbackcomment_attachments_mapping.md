# Table Mapping: seafarer_attachments → seafarer_attachments

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_attachments
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/seafarer_feedbackcomment_attachments_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_attachments`
- **New Path**: `smac_crewing_migration.public.seafarer_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Feedback Comment Attachments (`seafarer_attachments` → `seafarer_attachments`)

## Migration Notes

- Filter: SAC `entity_type = 'FeedbackComment'` AND `entity_uuid IS NULL` only
- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- Pre-migration duplicate UUID check on SAC `uuid` column
- `seafarer_id`: `seafarer_uuid_mapping` (direct match on `public.seafarers.id`) then `seafarer_id_mapping` fallback; nil UUID if unmapped
- `reference_entity` hardcoded `'seafarer_feedbacks'`; `reference_id` = `NULL` (no feedback UUID in source)
- `file_content_type` split on `/` into `file_type` and `file_sub_type`; default `file_type = 'application'`
- `status`: `deleted_at IS NOT NULL` → `'DELETED'`, else `'ACTIVE'`
- Uses `migration.build_audit_info()` — source has no audit columns
- Requires `seafarers` migrated first

## Special Considerations

- Orchestration dependencies: `seafarers`, `seafarer_feedbacks`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarer_uuid_mapping` | FK lookup | `target_id`, `seafarer_uuid_text` | - | - |
| `seafarer_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

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

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `uuid` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC `uuid` as SMAC `id` |
| 2 | `seafarer_uuid`, `seafarer_id` | character varying, bigint | `seafarer_id` | uuid | `COALESCE(seafarer_uuid_mapping.target_id, seafarer_id_mapping.new_id, nil UUID)` | Lookup: `public.seafarers` then `table_mappings` (`target_table = 'seafarers'`) |
| 3 | `file_name` | text | `file_name` | text | `COALESCE(NULLIF(TRIM(file_name), ''), '')` | NOT NULL in SMAC |
| 4 | `file_content_type` | text | `file_type` | text | `SPLIT_PART` before `/`; else `'application'` | MIME type major part |
| 5 | `file_content_type` | text | `file_sub_type` | text | `SPLIT_PART` after `/`; else `NULL` | MIME type minor part |
| 6 | — | — | `master_document_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 7 | `file_content_type` | text | `file_content_type` | text | `NULLIF(TRIM(file_content_type), '')` | Full MIME string preserved |
| 8 | `file_size` | bigint | `file_size` | bigint | `COALESCE(file_size::bigint, 0)` | NOT NULL in SMAC |
| 9 | `url` | text | `file_url` | text | `COALESCE(NULLIF(TRIM(url), ''), '')` | SAC `url` → SMAC `file_url` |
| 10 | — | — | `checksum` | text | `NULL` | No equivalent in SAC; not populated |
| 11 | — | — | `reference_entity` | text | Hardcoded `'seafarer_feedbacks'` | Parent entity type |
| 12 | `entity_uuid` | uuid | `reference_id` | uuid | `NULL` at INSERT; backfilled post-migration | See Post-Migration Updates (`update_seafarer_feedbackcomment_attachments_reference_id.sql`) |
| 13 | — | — | `version_number` | integer | Hardcoded `1` | Initial version |
| 14 | — | — | `valid_from` | date | `NULL` | No equivalent in SAC; not populated |
| 15 | — | — | `valid_until` | date | `NULL` | No equivalent in SAC; not populated |
| 16 | `deleted_at` | timestamp without time zone | `status` | text | `deleted_at IS NOT NULL` → `'DELETED'`; else `'ACTIVE'` | Case 1 — `deleted_at` only |
| 17 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 18 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 19 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 20 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC; not populated |
| 21 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 22 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all audit fields NULL | Source has no audit columns; no `legacy_id` (uuid preserved as `id`) |

**SMAC columns not migrated:** None beyond defaults.

**SAC columns not migrated:** `entity_type`, `entity_id`, `entity_uuid` (used for filtering only); `id` (bigint) used as `resolve_target_id` source_id only.

### Post-Migration Updates (`update_seafarer_feedbackcomment_attachments_reference_id.sql`)

Applied after `seafarer_feedbacks` and `seafarer_attachments` migrations. Source: `synergy_seafarer`.

| Target Table | Target Column | Legacy Source Table | Legacy Column | Legacy Type | Transformation | Conditions |
|--------------|---------------|---------------------|---------------|-------------|----------------|------------|
| `public.seafarer_attachments` | `reference_id` | `public.feedback_comments` | `id`, `uuid` | bigint, uuid | `COALESCE(table_mappings.target_id, feedback_uuid)` where mapping is `feedback_comments` → `seafarer_feedbacks` | `reference_entity = 'seafarer_feedbacks'`; `reference_id` NULL or differs |
| `public.seafarer_attachments` | `id` (match key) | `public.feedback_comments` | `attachments[]` | bigint[] | Unnest array → join `public.seafarer_attachments` on `a.id = attachment_id::bigint` | `entity_type = 'FEEDBACKCOMMENT'`; attachments non-empty |
| `public.seafarer_attachments` | `id` (match key) | `public.seafarer_attachments` | `uuid` | uuid | SMAC row matched where `seafarer_attachments.id = attachment_uuid` | SAC attachment uuid preserved as SMAC `id` |

**Lookup tables:** `migration.table_mappings` (`source_table = 'feedback_comments'`, `target_table = 'seafarer_feedbacks'`).

**Notes:** Migration INSERT sets `reference_id = NULL` because SAC `entity_uuid` is NULL for the FeedbackComment slice. This update resolves the parent feedback UUID via `feedback_comments.attachments[]` → SAC `seafarer_attachments.uuid`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.seafarers`
- `seafarer_feedbacks`
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

### 2. Seafarer ID Mapping
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

Full migration context: `04-migration-scripts/crewing/seafarer_feedbackcomment_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_feedbackcomment_attachments_validation.sql` if available
- Run `06-rollback/crewing/seafarer_feedbackcomment_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
