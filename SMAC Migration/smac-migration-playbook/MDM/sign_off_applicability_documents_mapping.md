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

- Generate new UUID for id (preserve uuid as p_target_id for idempotency)
- Map master_type to signoff_reason_id via sign_off_reasons lookup
- Map master_document_identifier to document_id via documents lookup
- Store extended_document_identifier, is_mandatory, is_visible_ahoy in audit_info
- Map is_active boolean to status integer (true → 0 Active, false → 2 Inactive)
- Migrates seafarer_signoff_applicability to sign_off_applicability_documents. Generates new UUID for id (preserves uuid as p_target_id for idempotency). Maps master_type to signoff_reason_id via sign_off_reasons lookup (match by code/name). Maps master_document_identifier to document_id via documents lookup (match by identifier). Maps feature to code. Maps is_active boolean to status integer (false → 0 Active, false → 2 Inactive). Stores extended_document_identifier, is_mandatory, is_visible_ahoy in audit_info JSONB.

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
| 1 | id, uuid | - | id | - | migration.resolve_target_id() | DISTINCT ON (legacy_data.id) migration.resolve_target_id( 'synergy_manning'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarer_signoff_applicability'::VARCHAR(100), legacy_data.id... |
| 2 | derived | - | signoff_reason_id | - | '00000000-0000-0000-0000-000000000000'::uuid AS signoff_reason_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 3 | master_type, master_document_identifier | - | document_id | - | COALESCE( CASE WHEN UPPER(TRIM(COALESCE(legacy_data.master_type, ''))) = 'SIGNOFF_DOCUMENT' AND legacy_data.master_document_identifier IS NOT NULL AND TRIM(legacy_data.master_do... | COALESCE( CASE WHEN UPPER(TRIM(COALESCE(legacy_data.master_type, ''))) = 'SIGNOFF_DOCUMENT' AND legacy_data.master_document_identifier IS NOT NULL AND TRIM(legacy_data.master_do... |
| 4 | feature, uuid | - | code | - | generate_meaningful_code() | generate_meaningful_code(TRIM(legacy_data.feature), legacy_data.uuid::text) |
| 5 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 6 | - | - | parent_id | - | NULL | NULL::uuid |
| 7 | derived | - | level | - | 0::numeric as level | 0::numeric |
| 8 | derived | - | version | - | 1 as version | 1 |
| 9 | - | - | defined_by | - | DEFAULT_DEFINED_BY | :'DEFAULT_DEFINED_BY'::integer |
| 10 | - | - | workflow_status | - | DEFAULT_WORKFLOW_STATUS | :'DEFAULT_WORKFLOW_STATUS'::integer |
| 11 | is_active | - | status | - | CASE WHEN legacy_data.is_active = true THEN 0 ELSE 2 END as status | CASE WHEN legacy_data.is_active = true THEN 0 ELSE 2 END |
| 12 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 13 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 14 | - | - | deleted_at | - | NULL | NULL::timestamp |
| 15 | - | - | archived_at | - | NULL | NULL::timestamp |
| 16 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) |
| 17 | - | - | tags | - | NULL | NULL::text[] |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

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
