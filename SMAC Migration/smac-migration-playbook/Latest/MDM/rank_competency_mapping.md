# Table Mapping: ranks → rank_competency_mapping

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: ranks
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: rank_competency_mapping
- **Source Script**: `04-migration-scripts/master/rank_competency_mapping_migration.sql`

- **Legacy Path**: `synergy_master.public.ranks`
- **New Path**: `smac_master_migration.public.rank_competency_mapping`

## Migration Notes

- Source: SAC `ranks.certificate_of_competency` JSON array — one mapping row per (rank, document UUID) pair
- `id` via `migration.resolve_target_id()` with composite source_id `rank_id::text || '|' || document_uuid`; idempotent via `id_mappings`
- `rank_id` mapped via `ranks_id_mapping`; `document_id` mapped via `documents_id_mapping` (`synergy_master.document.documents`)
- `code` generated from rank name via `generate_meaningful_code()`
- `status` derived from `deleted_at` (Case 1 — `deleted_at IS NOT NULL` → Deleted)
- Filter: only rows where rank and document mappings exist and cert UUID is non-empty
- Requires `ranks` and `documents` migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE public.rank_competency_mapping` before insert (full table reload).

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `ranks_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `documents_id_mapping` | FK lookup | `legacy_document_id`, `new_document_id` | `synergy_master.document.documents` → `?.document.documents` | - |

### `ranks_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=ranks

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

### `documents_id_mapping`

- **Output columns**: legacy_document_id, new_document_id
- **migration.table_mappings**: source_db=synergy_master, source_schema=document, source_table=documents, target_schema=document, target_table=documents

```sql
CREATE TEMP TABLE documents_id_mapping AS
SELECT
    TRIM(source_id) as legacy_document_id,
    target_id as new_document_id
FROM migration.table_mappings
WHERE source_db = 'synergy_master'
  AND source_schema = 'document'
  AND source_table = 'documents'
  AND target_table = 'documents'
  AND target_schema = 'document'
  AND target_db = current_database()
  AND source_db = 'synergy_master'
  AND source_schema = 'document';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `certificate_of_competency` | bigint, jsonb | `id` | uuid | `migration.resolve_target_id()` — source_id = `rank_id::text \|\| '\|' \|\| TRIM(cert_uuid)` | Composite key per rank-document pair; idempotent via `id_mappings` |
| 2 | `name` | text | `code` | text | `generate_meaningful_code(TRIM(rank_name), NULL)` | Business code from rank name; NOT NULL in SMAC |
| 3 | `id` | bigint | `rank_id` | uuid | Map via `ranks_id_mapping` on `legacy_id = id::text` | Lookup: `migration.table_mappings` where `target_table = 'ranks'` |
| 4 | `certificate_of_competency` | jsonb | `document_id` | uuid | Unnest JSON array; map each UUID via `documents_id_mapping` | Lookup: `migration.table_mappings` for `document.documents`; extracts `id` if element is JSON object |
| 5 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default; not in SAC source |
| 6 | — | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 7 | — | — | `level` | numeric | Hardcoded `0` | Default hierarchy level; not in SAC source |
| 8 | — | — | `version` | integer | Hardcoded `1` | Initial migration version; not in SAC source |
| 9 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 10 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 11 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 12 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 13 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — `SYSTEM_USER_ID` for created/updated by | Standardized SMAC audit structure; composite source_id in `id_mappings` |
| 14 | — | — | `tags` | text[] | `NULL` | Not populated from SAC source |
| 15 | `deleted_at` | timestamp without time zone | `status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Per project rule Case 1 |
| 16 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2); not in SAC source |
| 17 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0); not in SAC source |

**SMAC columns not migrated:** None — all target columns populated.

**SAC columns not migrated:** Other `ranks` attributes (`short_code`, `position`, etc.) — only `id`, `name`, `certificate_of_competency`, and audit timestamps used.

## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Ranks ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='ranks'`

```sql
CREATE TEMP TABLE ranks_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'ranks'
  AND target_db = current_database();
```

### 2. Documents ID Mapping
**Output columns**: `legacy_document_id, new_document_id`
**migration.table_mappings**: `documents` → `documents` (source_db=`synergy_master`)

```sql
CREATE TEMP TABLE documents_id_mapping AS
SELECT
    TRIM(source_id) as legacy_document_id,
    target_id as new_document_id
FROM migration.table_mappings
WHERE source_db = 'synergy_master'
  AND source_schema = 'document'
  AND source_table = 'documents'
  AND target_table = 'documents'
  AND target_schema = 'document'
  AND target_db = current_database()
  AND source_db = 'synergy_master'
  AND source_schema = 'document';
```

Full migration context: `04-migration-scripts/master/rank_competency_mapping_migration.sql`

## Validation

- Run `05-validation/master/rank_competency_mapping_validation.sql` if available
- Run `06-rollback/master/rank_competency_mapping_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
