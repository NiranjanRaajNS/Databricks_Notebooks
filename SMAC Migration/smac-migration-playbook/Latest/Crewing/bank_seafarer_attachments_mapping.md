# Table Mapping: bank_seafarer_attachments → bank_seafarer_attachments

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_attachments
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Source Script**: `04-migration-scripts/crewing/bank_seafarer_attachments_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_attachments`
- **New Path**: `smac_crewing_migration.public.seafarer_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Bank Seafarer Attachments (`seafarer_attachments` → `seafarer_attachments`)

## Migration Notes

- Subset migration: SAC `seafarer_attachments` where `entity_type = 'BankDetail'` → SMAC `seafarer_attachments` with `reference_entity = 'seafarer_bank_accounts'`
- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- Deduplicate by `uuid`: prefer rows with `file_name`, then highest `id`
- `seafarer_uuid` (varchar) joined to `public.seafarers.id` via `seafarer_uuid_mapping`
- `entity_uuid` joined to `seafarer_bank_accounts.id` for `reference_id`
- `file_type` / `file_content_type` derived from URL extension with fallback to `document_type` / `file_content_type`
- `status`: `DELETED` when `deleted_at IS NOT NULL`, else `ACTIVE`
- Clears only bank attachment rows (`reference_entity` in `seafarer_bank_accounts`, `SeafarerBankAccount`)
- Requires `seafarers` and `seafarer_bank_accounts` migrated first

## Special Considerations

- Orchestration dependencies: `seafarers`, `seafarer_bank_accounts`

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
| 1 | `id`, `uuid` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC `uuid` as SMAC `id` |
| 2 | `seafarer_uuid` | character varying | `seafarer_id` | uuid | Join `seafarer_uuid_mapping` on `seafarers.id::text`; default nil UUID | Lookup: `public.seafarers` by UUID text match |
| 3 | `file_name` | text | `file_name` | text | `COALESCE(NULLIF(TRIM(file_name), ''), '')` | NOT NULL in SMAC |
| 4 | `url`, `document_type` | text | `file_type` | text | URL contains `pdf` → `application/pdf`; `jpg` → `image/jpeg`; else `TRIM(document_type)` | Derived MIME from URL with fallback |
| 5 | `entity_type` | text | `file_sub_type` | text | `COALESCE(NULLIF(TRIM(entity_type), ''), '')` | Filter: only `BankDetail` rows migrated |
| 6 | — | — | `master_document_id` | uuid | `NULL` | No equivalent in SAC |
| 7 | `url`, `file_content_type` | text | `file_content_type` | text | URL contains `png` → `image/png`; else `NULLIF(TRIM(file_content_type), '')` | Nullable |
| 8 | `file_size` | integer | `file_size` | bigint | `COALESCE(file_size::bigint, 0)` | Cast int → bigint |
| 9 | `url` | text | `file_url` | text | `COALESCE(NULLIF(TRIM(url), ''), '')` | NOT NULL in SMAC |
| 10 | — | — | `checksum` | text | `NULL` | No equivalent in SAC |
| 11 | — | — | `reference_entity` | text | Hardcoded `'seafarer_bank_accounts'` | SMAC polymorphic reference type |
| 12 | `entity_uuid` | character varying | `reference_id` | uuid | Join `seafarer_bank_accounts` on `id::text = entity_uuid` | Requires `seafarer_bank_accounts` migrated |
| 13 | — | — | `version_number` | integer | Hardcoded `1` | SMAC default |
| 14 | — | — | `valid_from` | date | `NULL` | No equivalent in SAC |
| 15 | — | — | `valid_until` | date | `NULL` | No equivalent in SAC |
| 16 | `deleted_at` | timestamp without time zone | `status` | text | `deleted_at IS NOT NULL` → `DELETED`; else `ACTIVE` | Text status (not integer constants) |
| 17 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 18 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL in SMAC |
| 19 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | NOT NULL in SMAC |
| 20 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 21 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 22 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all audit fields NULL | SAC has no audit columns for attachments |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `id` (bigint) — used only as `source_id` for mapping; `entity_type` values other than `BankDetail` excluded by filter.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `public.seafarers`
- `seafarer_bank_accounts`
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

Full migration context: `04-migration-scripts/crewing/bank_seafarer_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/bank_seafarer_attachments_validation.sql` if available
- Run `06-rollback/crewing/bank_seafarer_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
