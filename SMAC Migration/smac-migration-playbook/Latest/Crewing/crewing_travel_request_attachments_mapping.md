# Table Mapping: travel_documents → crewing_travel_request_attachments

## Overview
- **Legacy Database**: synergy_manning
- **Legacy Schema**: public
- **Legacy Table**: travel_documents
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: crewing_travel_request_attachments
- **Source Script**: `04-migration-scripts/crewing/crewing_travel_request_attachments_migration.sql`

- **Legacy Path**: `synergy_manning.public.travel_documents`
- **New Path**: `smac_crewing_migration.public.crewing_travel_request_attachments`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Crewing Travel Request Attachments (`travel_documents` → `crewing_travel_request_attachments`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates travel_documents to crewing_travel_request_attachments preserving UUID. Maps relief_id to travel_request_id via crewing_travel_requests. Uses default workflow_status_id from workflow_status table.

## Special Considerations

- Script performs `TRUNCATE TABLE public.crewing_travel_request_attachments` before insert (full table reload).
- Orchestration dependencies: `crewing_travel_requests`, `workflow_status`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 11

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `workflow_status_id_mapping` | FK lookup | `workflow_status_id` | - | `smac_master_migration` |
| `travel_request_id_direct_mapping` | Store in sess | `legacy_documentable_id`, `new_id` | `?.?.travel_ticket_requests` → `?.?.crewing_travel_requests` | - |
| `travel_request_id_via_tickets_mapping` | Ensure relief_summary has in | `legacy_relief_id`, `legacy_seafarer_id`, `new_id` | `?.?.travel_ticket_requests` → `?.?.crewing_travel_requests` | `synergy_manning` |
| `travel_request_id_mapping` | FK lookup | `legacy_relief_id`, `legacy_seafarer_id`, `new_id` | `?.?.travel_ticket_requests` → `?.?.crewing_travel_requests` | `synergy_manning` |
| `travel_request_id_fallback_mapping` | FK lookup | `legacy_relief_id`, `new_id` | `?.?.travel_ticket_requests` → `?.?.crewing_travel_requests` | `synergy_manning` |
| `travel_request_id_assignment_fallback_mapping` | Create travel_request lookup mapping by relief_id and seafarer_id (PR | `legacy_relief_id`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `travel_document_id_mapping_uuid` | FK lookup | `travel_document_id`, `document_uuid` | - | `smac_master_migration` |
| `travel_document_id_mapping_id` | FK lookup | `travel_document_id`, `legacy_travel_document_list_id` | - | `synergy_manning` |
| `seafarer_id_mapping` | FK lookup | `legacy_seafarer_id`, `new_seafarer_id` | `migration.table_mappings` (see SQL) | - |
| `seafarer_document_id_mapping_uuid` | FK lookup | `travel_document_uuid`, `legacy_seafarer_id`, `seafarer_document_id` | - | `synergy_manning` |
| `seafarer_document_id_mapping_id` | FK lookup | `legacy_travel_document_list_id`, `legacy_seafarer_id`, `seafarer_document_id` | - | `synergy_manning` |

### `workflow_status_id_mapping`

- **Output columns**: workflow_status_id
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

### `travel_request_id_direct_mapping`

- **Purpose**: Store in sess
- **Output columns**: legacy_documentable_id, new_id
- **migration.table_mappings**: source_table=travel_ticket_requests, target_table=crewing_travel_requests

```sql
CREATE TEMP TABLE travel_request_id_direct_mapping AS
SELECT DISTINCT ON (tr_map.source_id)
    tr_map.source_id::bigint AS legacy_documentable_id,
    tr_map.target_id AS new_id
FROM migration.table_mappings tr_map
WHERE tr_map.source_table = 'travel_ticket_requests'
    AND tr_map.target_table = 'crewing_travel_requests'
    AND tr_map.target_db = current_database()
    AND tr_map.source_id ~ '^[0-9]+$'
ORDER BY tr_map.source_id, tr_map.target_id;
```

### `travel_request_id_via_tickets_mapping`

- **Purpose**: Ensure relief_summary has in
- **Output columns**: legacy_relief_id, legacy_seafarer_id, new_id
- **migration.table_mappings**: source_table=travel_ticket_requests, target_table=crewing_travel_requests
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE travel_request_id_via_tickets_mapping AS
SELECT DISTINCT ON (tt.relief_id, tt.seafarer_id)
    tt.relief_id AS legacy_relief_id,
    tt.seafarer_id AS legacy_seafarer_id,
    tr_map.target_id AS new_id
FROM dblink('synergy_manning',
    'SELECT DISTINCT relief_id, seafarer_id FROM public.travel_tickets WHERE relief_id IS NOT NULL'
) AS tt(relief_id bigint, seafarer_id bigint)
JOIN dblink('synergy_manning',
    'SELECT DISTINCT id, relief_id, seafarer_id FROM public.travel_ticket_requests WHERE relief_id IS NOT NULL'
) AS ttr(id bigint, relief_id bigint, seafarer_id bigint)
    ON ttr.relief_id = tt.relief_id AND ttr.seafarer_id = tt.seafarer_id
JOIN migration.table_mappings tr_map ON tr_map.source_id = ttr.id::text
    AND tr_map.source_table = 'travel_ticket_requests'
    AND tr_map.target_table = 'crewing_travel_requests'
    AND tr_map.target_db = current_database()
WHERE tt.relief_id IS NOT NULL
ORDER BY tt.relief_id, tt.seafarer_id, tr_map.target_id;
```

### `travel_request_id_mapping`

- **Output columns**: legacy_relief_id, legacy_seafarer_id, new_id
- **migration.table_mappings**: source_table=travel_ticket_requests, target_table=crewing_travel_requests
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE travel_request_id_mapping AS
SELECT DISTINCT ON (ttr.relief_id, ttr.seafarer_id)
    ttr.relief_id AS legacy_relief_id,
    ttr.seafarer_id AS legacy_seafarer_id,
    tr_map.target_id AS new_id
FROM dblink('synergy_manning',
    'SELECT DISTINCT id, relief_id, seafarer_id FROM public.travel_ticket_requests WHERE relief_id IS NOT NULL AND seafarer_id IS NOT NULL'
) AS ttr(id bigint, relief_id bigint, seafarer_id bigint)
JOIN migration.table_mappings tr_map ON tr_map.source_id = ttr.id::text
    AND tr_map.source_table = 'travel_ticket_requests'
    AND tr_map.target_table = 'crewing_travel_requests'
    AND tr_map.target_db = current_database()
WHERE ttr.relief_id IS NOT NULL
  AND ttr.seafarer_id IS NOT NULL
ORDER BY ttr.relief_id, ttr.seafarer_id, tr_map.target_id;
```

### `travel_request_id_fallback_mapping`

- **Output columns**: legacy_relief_id, new_id
- **migration.table_mappings**: source_table=travel_ticket_requests, target_table=crewing_travel_requests
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE travel_request_id_fallback_mapping AS
SELECT DISTINCT ON (ttr.relief_id)
    ttr.relief_id AS legacy_relief_id,
    tr_map.target_id AS new_id
FROM dblink('synergy_manning',
    'SELECT DISTINCT id, relief_id FROM public.travel_ticket_requests WHERE relief_id IS NOT NULL'
) AS ttr(id bigint, relief_id bigint)
JOIN migration.table_mappings tr_map ON tr_map.source_id = ttr.id::text
    AND tr_map.source_table = 'travel_ticket_requests'
    AND tr_map.target_table = 'crewing_travel_requests'
    AND tr_map.target_db = current_database()
WHERE ttr.relief_id IS NOT NULL
ORDER BY ttr.relief_id, tr_map.target_id;
```

### `travel_request_id_assignment_fallback_mapping`

- **Purpose**: Create travel_request lookup mapping by relief_id and seafarer_id (PR
- **Output columns**: legacy_relief_id, new_id
- **migration.table_mappings**: target_table=seafarer_vessel_assignments

```sql
CREATE TEMP TABLE travel_request_id_assignment_fallback_mapping AS
SELECT DISTINCT ON (sva_map.source_id::bigint)
    sva_map.source_id::bigint AS legacy_relief_id,
    tr.id AS new_id
FROM migration.table_mappings sva_map
INNER JOIN public.seafarer_vessel_assignments sva ON sva.id = sva_map.target_id
INNER JOIN public.crewing_travel_requests tr ON tr.assignment_id = sva.id
WHERE sva_map.target_table = 'seafarer_vessel_assignments'
  AND sva_map.target_db = current_database()
  AND sva_map.source_id ~ '^[0-9]+$'
ORDER BY sva_map.source_id::bigint, tr.id;
```

### `travel_document_id_mapping_uuid`

- **Output columns**: travel_document_id, document_uuid
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE travel_document_id_mapping_uuid AS
SELECT
    td.id AS travel_document_id,
    td.id AS document_uuid
FROM dblink('smac_master_migration',
    'SELECT id
     FROM document.travel_documents
     WHERE id IS NOT NULL'
) AS td(
    id uuid
)
WHERE td.id IS NOT NULL;
```

### `travel_document_id_mapping_id`

- **Output columns**: travel_document_id, legacy_travel_document_list_id
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE travel_document_id_mapping_id AS
SELECT DISTINCT ON (tdl.id)
    td.id AS travel_document_id,
    tdl.id AS legacy_travel_document_list_id
FROM dblink('synergy_manning',
    'SELECT id, uuid FROM public.travel_document_lists WHERE uuid IS NOT NULL'
) AS tdl(
    id bigint,
    uuid uuid
)
JOIN dblink('smac_master_migration',
    'SELECT id FROM document.travel_documents WHERE id IS NOT NULL'
) AS td(
    id uuid
) ON td.id = tdl.uuid
WHERE tdl.uuid IS NOT NULL
ORDER BY tdl.id, td.id;
```

### `seafarer_id_mapping`

- **Output columns**: legacy_seafarer_id, new_seafarer_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    seafarer_map.source_id::bigint AS legacy_seafarer_id,
    seafarer_map.target_id AS new_seafarer_id
FROM migration.table_mappings seafarer_map
WHERE seafarer_map.target_table = 'seafarers'
  AND seafarer_map.target_db = current_database()
  AND seafarer_map.source_id ~ '^[0-9]+$';
```

### `seafarer_document_id_mapping_uuid`

- **Output columns**: travel_document_uuid, legacy_seafarer_id, seafarer_document_id
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE seafarer_document_id_mapping_uuid AS
SELECT DISTINCT ON (td.id, legacy_seafarer_map.legacy_seafarer_id)
    td.id AS travel_document_uuid,
    legacy_seafarer_map.legacy_seafarer_id AS legacy_seafarer_id,
    sd.id AS seafarer_document_id
FROM dblink('synergy_manning',
    'SELECT DISTINCT travel_document_list_uuid, seafarer_id FROM public.travel_documents WHERE travel_document_list_uuid IS NOT NULL AND travel_document_list_uuid <> ''00000000-0000-0000-0000-000000000000'' AND seafarer_id IS NOT NULL'
) AS legacy_td(travel_document_list_uuid uuid, seafarer_id bigint)
JOIN seafarer_id_mapping legacy_seafarer_map ON legacy_seafarer_map.legacy_seafarer_id = legacy_td.seafarer_id
JOIN dblink('smac_master_migration',
    'SELECT id, document_id FROM document.travel_documents WHERE id IS NOT NULL AND document_id IS NOT NULL'
) AS td(id uuid, document_id uuid)
    ON td.id = legacy_td.travel_document_list_uuid
JOIN public.seafarer_documents sd ON sd.document_id = td.document_id
    AND sd.seafarer_id = legacy_seafarer_map.new_seafarer_id
WHERE td.document_id IS NOT NULL
ORDER BY td.id, legacy_seafarer_map.legacy_seafarer_id, sd.id;
```

### `seafarer_document_id_mapping_id`

- **Output columns**: legacy_travel_document_list_id, legacy_seafarer_id, seafarer_document_id
- **dblink connection**: `synergy_manning`

```sql
CREATE TEMP TABLE seafarer_document_id_mapping_id AS
SELECT DISTINCT ON (legacy_td.travel_document_list_id, legacy_seafarer_map.legacy_seafarer_id)
    legacy_td.travel_document_list_id AS legacy_travel_document_list_id,
    legacy_seafarer_map.legacy_seafarer_id AS legacy_seafarer_id,
    sd.id AS seafarer_document_id
FROM dblink('synergy_manning',
    'SELECT DISTINCT travel_document_list_id, travel_document_list_uuid, seafarer_id FROM public.travel_documents WHERE travel_document_list_id IS NOT NULL AND seafarer_id IS NOT NULL AND (travel_document_list_uuid = ''00000000-0000-0000-0000-000000000000'' OR travel_document_list_uuid IS NULL)'
) AS legacy_td(travel_document_list_id bigint, travel_document_list_uuid uuid, seafarer_id bigint)
JOIN seafarer_id_mapping legacy_seafarer_map ON legacy_seafarer_map.legacy_seafarer_id = legacy_td.seafarer_id
JOIN dblink('synergy_manning',
    'SELECT id, uuid FROM public.travel_document_lists WHERE uuid IS NOT NULL'
) AS tdl(id bigint, uuid uuid)
    ON tdl.id = legacy_td.travel_document_list_id
JOIN dblink('smac_master_migration',
    'SELECT id, document_id FROM document.travel_documents WHERE id IS NOT NULL AND document_id IS NOT NULL'
)...
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id`, `uuid` | bigint, uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = uuid` | Preserves SAC UUID; `DISTINCT ON (id, uuid)` |
| 2 | `relief_id`, `seafarer_id`, `documentable_id` | bigint | `travel_request_id` | uuid | COALESCE chain: relief+seafarer map → direct → via tickets → relief-only → assignment fallback | Multiple lookup fallbacks |
| 3 | `travel_document_list_uuid`, `travel_document_list_id` | uuid, bigint | `travel_document_id` | uuid | UUID map or ID-based fallback to `document.travel_documents` | Lookup: dblink master |
| 4 | `travel_document_list_uuid`, `seafarer_id` | uuid, bigint | `seafarer_document_id` | uuid | Chain: travel doc → `seafarer_documents` by document_id + seafarer | UUID or ID fallback paths |
| 5 | `attachment_name` | text | `file_name` | text | `TRIM(attachment_name)` | NOT NULL |
| 6 | `attachment_url` | text | `file_url` | text | `TRIM(attachment_url)` | NOT NULL |
| 7 | `attachment_content_type` | text | `mime_type` | text | `TRIM(attachment_content_type)` | Nullable |
| 8 | — | — | `workflow_status_id` | uuid | APPROVED from `workflow_status` lookup; default nil UUID | Lookup: dblink master |
| 9 | — | — | `is_verified` | boolean | Hardcoded `false` | NOT NULL |
| 10 | — | — | `verified_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 11 | — | — | `verified_by_id` | uuid | `NULL` | No equivalent in SAC |
| 12 | — | — | `verification_notes` | text | `NULL` | No equivalent in SAC |
| 13 | `deleted_at` | timestamp without time zone | `status` | text | `deleted_at IS NOT NULL` → `Deleted`; else `Active` | NOT NULL |
| 14 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 15 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | NOT NULL |
| 16 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | Direct copy | Nullable |
| 17 | — | — | `archived_at` | timestamp without time zone | `NULL` | No equivalent in SAC |
| 18 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete preserved |
| 19 | `created_by_id`, `updated_by_id`, `created_by_name`, `updated_by_name` | text | `audit_info` | jsonb | Standard SMAC `audit_info` JSONB structure (inline `jsonb_build_object`) | Names in `notes` |
| 20 | `relief_id` | bigint | `assignment_id` | uuid | `relief_summary` planned then onboard; default nil UUID | Lookup: `relief_summary`; NOT NULL |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `attachment_size`, `documentable_type`, `documentable_id` (used only for travel_request fallback join, not stored).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `crewing_travel_requests`
- `workflow_status`

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Workflow Status ID Mapping
**Output columns**: `workflow_status_id`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE workflow_status_id_mapping AS
SELECT id AS workflow_status_id
FROM dblink('smac_master_migration',
    'SELECT id FROM public.workflow_status WHERE code = ''APPROVED'' LIMIT 1'
) AS t(id uuid);
```

### 2. Travel Request Id Direct ID Mapping
**Purpose**: Store in sess
**Output columns**: `legacy_documentable_id, new_id`
**migration.table_mappings**: `travel_ticket_requests` → `crewing_travel_requests`

```sql
CREATE TEMP TABLE travel_request_id_direct_mapping AS
SELECT DISTINCT ON (tr_map.source_id)
    tr_map.source_id::bigint AS legacy_documentable_id,
    tr_map.target_id AS new_id
FROM migration.table_mappings tr_map
WHERE tr_map.source_table = 'travel_ticket_requests'
    AND tr_map.target_table = 'crewing_travel_requests'
    AND tr_map.target_db = current_database()
    AND tr_map.source_id ~ '^[0-9]+$'
ORDER BY tr_map.source_id, tr_map.target_id;
```

### 3. Travel Request Id Via Tickets ID Mapping
**Purpose**: Ensure relief_summary has in
**Output columns**: `legacy_relief_id, legacy_seafarer_id, new_id`
**migration.table_mappings**: `travel_ticket_requests` → `crewing_travel_requests`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE travel_request_id_via_tickets_mapping AS
SELECT DISTINCT ON (tt.relief_id, tt.seafarer_id)
    tt.relief_id AS legacy_relief_id,
    tt.seafarer_id AS legacy_seafarer_id,
    tr_map.target_id AS new_id
FROM dblink('synergy_manning',
    'SELECT DISTINCT relief_id, seafarer_id FROM public.travel_tickets WHERE relief_id IS NOT NULL'
) AS tt(relief_id bigint, seafarer_id bigint)
JOIN dblink('synergy_manning',
    'SELECT DISTINCT id, relief_id, seafarer_id FROM public.travel_ticket_requests WHERE relief_id IS NOT NULL'
) AS ttr(id bigint, relief_id bigint, seafarer_id bigint)
    ON ttr.relief_id = tt.relief_id AND ttr.seafarer_id = tt.seafarer_id
JOIN migration.table_mappings tr_map ON tr_map.source_id = ttr.id::text
    AND tr_map.source_table = 'travel_ticket_requests'
    AND tr_map.target_table = 'crewing_travel_requests'
    AND tr_map.target_db = current_database()
WHERE tt.relief_id IS NOT NULL
ORDER BY tt.relief_id, tt.seafarer_id, tr_map.target_id;
```

### 4. Travel Request ID Mapping
**Output columns**: `legacy_relief_id, legacy_seafarer_id, new_id`
**migration.table_mappings**: `travel_ticket_requests` → `crewing_travel_requests`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE travel_request_id_mapping AS
SELECT DISTINCT ON (ttr.relief_id, ttr.seafarer_id)
    ttr.relief_id AS legacy_relief_id,
    ttr.seafarer_id AS legacy_seafarer_id,
    tr_map.target_id AS new_id
FROM dblink('synergy_manning',
    'SELECT DISTINCT id, relief_id, seafarer_id FROM public.travel_ticket_requests WHERE relief_id IS NOT NULL AND seafarer_id IS NOT NULL'
) AS ttr(id bigint, relief_id bigint, seafarer_id bigint)
JOIN migration.table_mappings tr_map ON tr_map.source_id = ttr.id::text
    AND tr_map.source_table = 'travel_ticket_requests'
    AND tr_map.target_table = 'crewing_travel_requests'
    AND tr_map.target_db = current_database()
WHERE ttr.relief_id IS NOT NULL
  AND ttr.seafarer_id IS NOT NULL
ORDER BY ttr.relief_id, ttr.seafarer_id, tr_map.target_id;
```

### 5. Travel Request Id Fallback ID Mapping
**Output columns**: `legacy_relief_id, new_id`
**migration.table_mappings**: `travel_ticket_requests` → `crewing_travel_requests`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE travel_request_id_fallback_mapping AS
SELECT DISTINCT ON (ttr.relief_id)
    ttr.relief_id AS legacy_relief_id,
    tr_map.target_id AS new_id
FROM dblink('synergy_manning',
    'SELECT DISTINCT id, relief_id FROM public.travel_ticket_requests WHERE relief_id IS NOT NULL'
) AS ttr(id bigint, relief_id bigint)
JOIN migration.table_mappings tr_map ON tr_map.source_id = ttr.id::text
    AND tr_map.source_table = 'travel_ticket_requests'
    AND tr_map.target_table = 'crewing_travel_requests'
    AND tr_map.target_db = current_database()
WHERE ttr.relief_id IS NOT NULL
ORDER BY ttr.relief_id, tr_map.target_id;
```

### 6. Travel Request Id Assignment Fallback ID Mapping
**Purpose**: Create travel_request lookup mapping by relief_id and seafarer_id (PR
**Output columns**: `legacy_relief_id, new_id`
**migration.table_mappings**: `target_table='seafarer_vessel_assignments'`

```sql
CREATE TEMP TABLE travel_request_id_assignment_fallback_mapping AS
SELECT DISTINCT ON (sva_map.source_id::bigint)
    sva_map.source_id::bigint AS legacy_relief_id,
    tr.id AS new_id
FROM migration.table_mappings sva_map
INNER JOIN public.seafarer_vessel_assignments sva ON sva.id = sva_map.target_id
INNER JOIN public.crewing_travel_requests tr ON tr.assignment_id = sva.id
WHERE sva_map.target_table = 'seafarer_vessel_assignments'
  AND sva_map.target_db = current_database()
  AND sva_map.source_id ~ '^[0-9]+$'
ORDER BY sva_map.source_id::bigint, tr.id;
```

### 7. Travel Document Id Mapping Uuid
**Output columns**: `travel_document_id, document_uuid`
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE travel_document_id_mapping_uuid AS
SELECT
    td.id AS travel_document_id,
    td.id AS document_uuid
FROM dblink('smac_master_migration',
    'SELECT id
     FROM document.travel_documents
     WHERE id IS NOT NULL'
) AS td(
    id uuid
)
WHERE td.id IS NOT NULL;
```

### 8. Travel Document Id Mapping Id
**Output columns**: `travel_document_id, legacy_travel_document_list_id`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE travel_document_id_mapping_id AS
SELECT DISTINCT ON (tdl.id)
    td.id AS travel_document_id,
    tdl.id AS legacy_travel_document_list_id
FROM dblink('synergy_manning',
    'SELECT id, uuid FROM public.travel_document_lists WHERE uuid IS NOT NULL'
) AS tdl(
    id bigint,
    uuid uuid
)
JOIN dblink('smac_master_migration',
    'SELECT id FROM document.travel_documents WHERE id IS NOT NULL'
) AS td(
    id uuid
) ON td.id = tdl.uuid
WHERE tdl.uuid IS NOT NULL
ORDER BY tdl.id, td.id;
```

### 9. Seafarer ID Mapping
**Output columns**: `legacy_seafarer_id, new_seafarer_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT
    seafarer_map.source_id::bigint AS legacy_seafarer_id,
    seafarer_map.target_id AS new_seafarer_id
FROM migration.table_mappings seafarer_map
WHERE seafarer_map.target_table = 'seafarers'
  AND seafarer_map.target_db = current_database()
  AND seafarer_map.source_id ~ '^[0-9]+$';
```

### 10. Seafarer Document Id Mapping Uuid
**Output columns**: `travel_document_uuid, legacy_seafarer_id, seafarer_document_id`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE seafarer_document_id_mapping_uuid AS
SELECT DISTINCT ON (td.id, legacy_seafarer_map.legacy_seafarer_id)
    td.id AS travel_document_uuid,
    legacy_seafarer_map.legacy_seafarer_id AS legacy_seafarer_id,
    sd.id AS seafarer_document_id
FROM dblink('synergy_manning',
    'SELECT DISTINCT travel_document_list_uuid, seafarer_id FROM public.travel_documents WHERE travel_document_list_uuid IS NOT NULL AND travel_document_list_uuid <> ''00000000-0000-0000-0000-000000000000'' AND seafarer_id IS NOT NULL'
) AS legacy_td(travel_document_list_uuid uuid, seafarer_id bigint)
JOIN seafarer_id_mapping legacy_seafarer_map ON legacy_seafarer_map.legacy_seafarer_id = legacy_td.seafarer_id
JOIN dblink('smac_master_migration',
    'SELECT id, document_id FROM document.travel_documents WHERE id IS NOT NULL AND document_id IS NOT NULL'
) AS td(id uuid, document_id uuid)
    ON td.id = legacy_td.travel_document_list_uuid
JOIN public.seafarer_documents sd ON sd.document_id = td.document_id
    AND sd.seafarer_id = legacy_seafarer_map.new_seafarer_id
WHERE td.document_id IS NOT NULL
ORDER BY td.id, legacy_seafarer_map.legacy_seafarer_id, sd.id;
```

### 11. Seafarer Document Id Mapping Id
**Output columns**: `legacy_travel_document_list_id, legacy_seafarer_id, seafarer_document_id`
**dblink**: `synergy_manning`

```sql
CREATE TEMP TABLE seafarer_document_id_mapping_id AS
SELECT DISTINCT ON (legacy_td.travel_document_list_id, legacy_seafarer_map.legacy_seafarer_id)
    legacy_td.travel_document_list_id AS legacy_travel_document_list_id,
    legacy_seafarer_map.legacy_seafarer_id AS legacy_seafarer_id,
    sd.id AS seafarer_document_id
FROM dblink('synergy_manning',
    'SELECT DISTINCT travel_document_list_id, travel_document_list_uuid, seafarer_id FROM public.travel_documents WHERE travel_document_list_id IS NOT NULL AND seafarer_id IS NOT NULL AND (travel_document_list_uuid = ''00000000-0000-0000-0000-000000000000'' OR travel_document_list_uuid IS NULL)'
) AS legacy_td(travel_document_list_id bigint, travel_document_list_uuid uuid, seafarer_id bigint)
JOIN seafarer_id_mapping legacy_seafarer_map ON legacy_seafarer_map.legacy_seafarer_id = legacy_td.seafarer_id
JOIN dblink('synergy_manning',
    'SELECT id, uuid FROM public.travel_document_lists WHERE uuid IS NOT NULL'
) AS tdl(id bigint, uuid uuid)
    ON tdl.id = legacy_td.travel_document_list_id
JOIN dblink('smac_master_migration',
    'SELECT id, document_id FROM document.travel_documents WHERE id IS NOT NULL AND document_id IS NOT NULL'
) AS td(id uuid, document_id uuid)
    ON td.id = tdl.uuid
JOIN public.seafarer_documents sd ON sd.document_id = td.document_id
    AND sd.seafarer_id = legacy_seafarer_map.new_seafarer_id
WHERE td.document_id IS NOT NULL
ORDER BY legacy_td.travel_document_list_id, legacy_seafarer_map.legacy_seafarer_id, sd.id;
```

Full migration context: `04-migration-scripts/crewing/crewing_travel_request_attachments_migration.sql`

## Validation

- Run `05-validation/crewing/crewing_travel_request_attachments_validation.sql` if available
- Run `06-rollback/crewing/crewing_travel_request_attachments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
