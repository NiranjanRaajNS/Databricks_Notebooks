# Table Mapping: seafarer_signoff_applicability → sign_off_applicability_documents

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: seafarer_signoff_applicability
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: sign_off_applicability_documents
- **Source Script**: `04-migration-scripts/master/sign_off_applicability_documents_migration.sql`

- **Legacy Path**: `synergy_manning.public.seafarer_signoff_applicability`
- **New Path**: `smac_master_migration.crewing.sign_off_applicability_documents`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Sign Off Applicability Documents (`seafarer_signoff_applicability` → `sign_off_applicability_documents`)

## Migration Notes

- SAC `uuid` preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = uuid`
- Pre-migration duplicate UUID check on SAC `uuid` column
- `document_id` resolved conditionally by `master_type`: `SIGNOFF_DOCUMENT`, `TRAVEL_DOCUMENT_LIST`, `DOCUMENT_SUB_CATEGORY`
- `signoff_reason_id` set to zero-UUID placeholder (not mapped from source)
- `code` generated from `feature` via `generate_meaningful_code()`
- `status` mapped from `is_active` boolean (true → Active 0, false → Inactive 2)
- `created_at`/`updated_at` set to `NOW()` — not in SAC source
- `DISTINCT ON (legacy_data.id)` prevents duplicate rows per legacy id
## Special Considerations

- Script performs `TRUNCATE TABLE crewing.sign_off_applicability_documents` before insert (full table reload).
- Orchestration dependencies: `sign_off_reasons`, `documents`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 3

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `document_sub_category_id_mapping` | Ch | `master_document_identifier`, `document_id` | - | `synergy_manning` |
| `travel_document_list_id_mapping` | FK lookup | `master_document_identifier`, `document_id` | `?.?.travel_document_lists` → `?.?.travel_documents` | `synergy_manning` |
| `signoff_document_id_mapping` | FK lookup | `master_document_identifier`, `document_id` | - | `synergy_manning` |

### `document_sub_category_id_mapping`

- **Purpose**: Ch
- **Output columns**: master_document_identifier, document_id
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE document_sub_category_id_mapping AS
SELECT DISTINCT ON (UPPER(TRIM(COALESCE(md.master_document_identifier, ''))))
    UPPER(TRIM(COALESCE(md.master_document_identifier, ''))) AS master_document_identifier,
    d.id AS document_id
FROM dblink('synergy_manning',
    'SELECT DISTINCT master_document_identifier FROM public.seafarer_signoff_applicability
     WHERE master_type = ''document_sub_category'' AND master_document_identifier IS NOT NULL'
) AS md(master_document_identifier text)
CROSS JOIN dblink('synergy_master',
    'SELECT uuid, document_identifier FROM public.document_sub_categories WHERE document_identifier IS NOT NULL'
) AS dsc(uuid uuid, document_identifier text)
JOIN document.documents d ON d.id = dsc.uuid
WHERE dsc.document_identifier ILIKE '%' || TRIM(md.master_document_identifier) || '%'
  AND md.master_document_identifier IS NOT NULL
  AND TRIM(md.master_document_identifier) <> ''
ORDER BY UPPER(TRIM(COALESCE(md.master_document_identifier, ''))), d.id;
```

### `travel_document_list_id_mapping`

- **Output columns**: master_document_identifier, document_id
- **migration.table_mappings**: source_table=travel_document_lists, target_table=travel_documents
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE travel_document_list_id_mapping AS
SELECT DISTINCT ON (UPPER(TRIM(COALESCE(md.master_document_identifier, ''))))
    UPPER(TRIM(COALESCE(md.master_document_identifier, ''))) AS master_document_identifier,
    tm.target_id AS document_id
FROM (
    SELECT DISTINCT master_document_identifier
    FROM dblink('synergy_manning',
        'SELECT master_document_identifier, master_type FROM public.seafarer_signoff_applicability
         WHERE master_type = ''travel_document_list'' AND master_document_identifier IS NOT NULL'
    ) AS sa(master_document_identifier text, master_type varchar)
) md
JOIN dblink('synergy_manning',
    'SELECT id, uuid, identifier FROM public.travel_document_lists WHERE identifier IS NOT NULL'
) AS tdl(id bigint, uuid uuid, identifier text) ON UPPER(TRIM(tdl.identifier)) = UPPER(TRIM(md.master_document_identifier))
JOIN migration.table_mappings tm ON tm.source_id = tdl.id::text
    AND tm.source_table = 'travel_document_lists'
    AND tm.target_table = 'travel_documents'
    AND tm.target_db = current_database()
WHERE md.master_document_identifier IS NOT NULL
  AND TRIM(md.master_document_identifier) <> ''
ORDER BY UPPER(TRIM(COALESCE(md.mast...
```

### `signoff_document_id_mapping`

- **Output columns**: master_document_identifier, document_id
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE signoff_document_id_mapping AS
SELECT DISTINCT ON (LOWER(TRIM(COALESCE(md.master_document_identifier, ''))))
    LOWER(TRIM(COALESCE(md.master_document_identifier, ''))) AS master_document_identifier,

    CASE
        WHEN EXISTS (
            SELECT 1
            FROM dblink('synergy_manning',
                'SELECT uuid FROM public.signoff_document_master WHERE uuid IS NOT NULL'
            ) AS sdm(uuid uuid)
            WHERE LOWER(TRIM(sdm.uuid::text)) = LOWER(TRIM(md.master_document_identifier))
        )
        THEN md.master_document_identifier::uuid
        ELSE NULL
    END AS document_id
FROM (
    SELECT DISTINCT master_document_identifier
    FROM dblink('synergy_manning',
        'SELECT master_document_identifier, master_type FROM public.seafarer_signoff_applicability
         WHERE master_type = ''signoff_document'' AND master_document_identifier IS NOT NULL'
    ) AS sa(master_document_identifier text, master_type varchar)
) md
WHERE md.master_document_identifier IS NOT NULL
  AND TRIM(md.master_document_identifier) <> ''
  AND md.master_document_identifier ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
ORDER BY LOWER(TRI...
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `uuid, id` | uuid, bigint | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC uuid as SMAC id |
| 2 | `—` | — | `signoff_reason_id` | uuid | Hardcoded `'00000000-0000-0000-0000-000000000000'` | Placeholder; not mapped from SAC |
| 3 | `master_type, master_document_identifier` | varchar, text | `document_id` | uuid | CASE on `master_type`: signoff/travel/document_sub_category lookups; else zero-UUID | FK via temp mapping tables |
| 4 | `feature, uuid` | varchar, uuid | `code` | text | `generate_meaningful_code(TRIM(feature), uuid::text)` | Generated from feature name |
| 5 | `—` | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 6 | `—` | — | `parent_id` | uuid | `NULL` | Not in SAC source |
| 7 | `—` | — | `level` | numeric | Hardcoded `0` | Default hierarchy level |
| 8 | `—` | — | `version` | integer | Hardcoded `1` | Initial migration version |
| 9 | `—` | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | Default: Global (0) |
| 10 | `—` | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | Default: Approved (2) |
| 11 | `is_active` | boolean | `status` | integer | `is_active = true` → Active (0); else Inactive (2) | No `deleted_at` in source |
| 12 | `—` | — | `created_at` | timestamp without time zone | `NOW()` | Not in SAC source |
| 13 | `—` | — | `updated_at` | timestamp without time zone | `NOW()` | Not in SAC source |
| 14 | `—` | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 15 | `—` | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 16 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` — all audit fields NULL | No audit columns in SAC |
| 17 | `—` | — | `tags` | text[] | `NULL` | Not populated |

**SAC columns not migrated:** `extended_document_identifier`, `is_mandatory`, `is_visible_ahoy` — not referenced in INSERT.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `documents`
- `sign_off_reasons`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Document Sub Category ID Mapping
**Purpose**: Ch
**Output columns**: `master_document_identifier, document_id`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE document_sub_category_id_mapping AS
SELECT DISTINCT ON (UPPER(TRIM(COALESCE(md.master_document_identifier, ''))))
    UPPER(TRIM(COALESCE(md.master_document_identifier, ''))) AS master_document_identifier,
    d.id AS document_id
FROM dblink('synergy_manning',
    'SELECT DISTINCT master_document_identifier FROM public.seafarer_signoff_applicability
     WHERE master_type = ''document_sub_category'' AND master_document_identifier IS NOT NULL'
) AS md(master_document_identifier text)
CROSS JOIN dblink('synergy_master',
    'SELECT uuid, document_identifier FROM public.document_sub_categories WHERE document_identifier IS NOT NULL'
) AS dsc(uuid uuid, document_identifier text)
JOIN document.documents d ON d.id = dsc.uuid
WHERE dsc.document_identifier ILIKE '%' || TRIM(md.master_document_identifier) || '%'
  AND md.master_document_identifier IS NOT NULL
  AND TRIM(md.master_document_identifier) <> ''
ORDER BY UPPER(TRIM(COALESCE(md.master_document_identifier, ''))), d.id;
```

### 2. Travel Document List ID Mapping
**Output columns**: `master_document_identifier, document_id`
**migration.table_mappings**: `travel_document_lists` → `travel_documents`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE travel_document_list_id_mapping AS
SELECT DISTINCT ON (UPPER(TRIM(COALESCE(md.master_document_identifier, ''))))
    UPPER(TRIM(COALESCE(md.master_document_identifier, ''))) AS master_document_identifier,
    tm.target_id AS document_id
FROM (
    SELECT DISTINCT master_document_identifier
    FROM dblink('synergy_manning',
        'SELECT master_document_identifier, master_type FROM public.seafarer_signoff_applicability
         WHERE master_type = ''travel_document_list'' AND master_document_identifier IS NOT NULL'
    ) AS sa(master_document_identifier text, master_type varchar)
) md
JOIN dblink('synergy_manning',
    'SELECT id, uuid, identifier FROM public.travel_document_lists WHERE identifier IS NOT NULL'
) AS tdl(id bigint, uuid uuid, identifier text) ON UPPER(TRIM(tdl.identifier)) = UPPER(TRIM(md.master_document_identifier))
JOIN migration.table_mappings tm ON tm.source_id = tdl.id::text
    AND tm.source_table = 'travel_document_lists'
    AND tm.target_table = 'travel_documents'
    AND tm.target_db = current_database()
WHERE md.master_document_identifier IS NOT NULL
  AND TRIM(md.master_document_identifier) <> ''
ORDER BY UPPER(TRIM(COALESCE(md.master_document_identifier, ''))), tm.target_id;
```

### 3. Signoff Document ID Mapping
**Output columns**: `master_document_identifier, document_id`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE signoff_document_id_mapping AS
SELECT DISTINCT ON (LOWER(TRIM(COALESCE(md.master_document_identifier, ''))))
    LOWER(TRIM(COALESCE(md.master_document_identifier, ''))) AS master_document_identifier,

    CASE
        WHEN EXISTS (
            SELECT 1
            FROM dblink('synergy_manning',
                'SELECT uuid FROM public.signoff_document_master WHERE uuid IS NOT NULL'
            ) AS sdm(uuid uuid)
            WHERE LOWER(TRIM(sdm.uuid::text)) = LOWER(TRIM(md.master_document_identifier))
        )
        THEN md.master_document_identifier::uuid
        ELSE NULL
    END AS document_id
FROM (
    SELECT DISTINCT master_document_identifier
    FROM dblink('synergy_manning',
        'SELECT master_document_identifier, master_type FROM public.seafarer_signoff_applicability
         WHERE master_type = ''signoff_document'' AND master_document_identifier IS NOT NULL'
    ) AS sa(master_document_identifier text, master_type varchar)
) md
WHERE md.master_document_identifier IS NOT NULL
  AND TRIM(md.master_document_identifier) <> ''
  AND md.master_document_identifier ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
ORDER BY LOWER(TRIM(COALESCE(md.master_document_identifier, '')));
```

Full migration context: `04-migration-scripts/master/sign_off_applicability_documents_migration.sql`

## Validation

- Run `05-validation/master/sign_off_applicability_documents_validation.sql` if available
- Run `06-rollback/master/sign_off_applicability_documents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
