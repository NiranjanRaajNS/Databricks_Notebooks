# Table Mapping: cbas.nationality → cba_nationalities

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: cbas (column: nationality - JSONB)
- **New Database**: smac_crewing_migration
- **New Schema**: crewing
- **New Table**: cba_nationalities
- **Migration Priority**: LOW (depends on cbas, nationalities)
- **Estimated Row Count**: TBD (depends on number of nationality values per CBA)

## Table Type
**Junction/Linking Table**: This table creates many-to-many relationships between CBAs and Nationalities.

## Source Data Structure (Legacy)
The source data comes from the `nationality` JSONB column in `public.cbas`:
```sql
-- nationality column is JSONB array, examples:
-- ["IN", "PH", "BD"]  -- array of nationality codes
-- ["ALL"]              -- special value meaning all nationalities
-- NULL                 -- no nationalities specified
-- []                   -- empty array
```

## Target Table Structure (New)
```sql
CREATE TABLE IF NOT EXISTS crewing.cba_nationalities (
    id uuid NOT NULL,
    cba_id uuid NOT NULL,
    nationality uuid NOT NULL,
    tenant_id uuid NOT NULL,
    parent_id uuid,
    version integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone,
    deleted_at timestamp without time zone,
    archived_at timestamp without time zone,
    audit_info jsonb,
    level numeric,
    tags text[],
    status integer NOT NULL DEFAULT 0,
    workflow_status integer NOT NULL DEFAULT 0,
    defined_by integer NOT NULL DEFAULT 0,
    CONSTRAINT "PK_cba_nationalities" PRIMARY KEY (id)
);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | - | - | id | uuid | gen_random_uuid() | Generate new UUID for each junction record |
| 2 | cbas.id | bigint | cba_id | uuid | Map via migration.table_mappings | FK to crewing.cbas.id |
| 3 | cbas.nationality[*] | jsonb array element | nationality | uuid | Map nationality code to nationalities.id | FK to public.nationalities.id |
| 4 | - | - | tenant_id | uuid | :'DEFAULT_TENANT_ID'::uuid | From constants.sql |
| 5 | - | - | parent_id | uuid | NULL | Not applicable |
| 6 | - | - | version | integer | 1 | Initial version |
| 7 | cbas.created_at | timestamp | created_at | timestamp | COALESCE(created_at, NOW()) | Use CBA's created_at |
| 8 | cbas.updated_at | timestamp | updated_at | timestamp | COALESCE(updated_at, NOW()) | Use CBA's updated_at |
| 9 | cbas.deleted_at | timestamp | deleted_at | timestamp | cbas.deleted_at | Preserve from parent CBA |
| 10 | - | - | archived_at | timestamp | NULL | Not applicable |
| 11 | cbas.id, nationality | various | audit_info | jsonb | jsonb_build_object() | SMAC structure with legacy refs |
| 12 | - | - | level | numeric | NULL | Not applicable |
| 13 | - | - | tags | text[] | NULL | Not applicable |
| 14 | cbas.deleted_at | timestamp | status | integer | CASE WHEN deleted_at IS NOT NULL THEN 3 ELSE 0 END | Map based on parent CBA |
| 15 | - | - | workflow_status | integer | :'DEFAULT_WORKFLOW_STATUS'::integer | Approved (2) |
| 16 | - | - | defined_by | integer | :'DEFAULT_DEFINED_BY'::integer | Global (0) |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- **cbas** (REQUIRED) - cba_nationalities.cba_id references crewing.cbas.id
- **nationalities** (REQUIRED) - cba_nationalities.nationality references public.nationalities.id

### Dependents (migrate after this table)
- None (junction table)

## Data Transformation Rules

### 1. JSONB Parsing
```sql
-- Parse JSONB array and extract text values
SELECT 
    cba.id as cba_id,
    jsonb_array_elements_text(cba.nationality) as nationality_text
FROM public.cbas cba
WHERE cba.nationality IS NOT NULL 
  AND jsonb_typeof(cba.nationality) = 'array'
  AND cba.nationality != '[]'::jsonb
  AND NOT (cba.nationality @> '["ALL"]'::jsonb)  -- Skip "ALL" entries
```

### 2. Primary Key Generation
```sql
gen_random_uuid() AS id
-- Generate new UUID for each junction record
```

### 3. CBA ID Mapping
```sql
-- Create lookup table for cba_id foreign key resolution
CREATE TEMP TABLE cbas_id_mapping AS
SELECT 
    source_id::bigint as legacy_id,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'cbas'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';  -- Only numeric source_ids
```

### 4. Nationality UUID Mapping
```sql
-- Map nationality text/code to UUID from nationalities table
CREATE TEMP TABLE nationalities_id_mapping AS
SELECT 
    UPPER(TRIM(COALESCE(n.code, ''))) as normalized_code,
    n.id as nationality_id
FROM public.nationalities n
WHERE TRIM(COALESCE(n.code, '')) <> '';
```

### 5. Status Mapping (inherit from parent CBA)
```sql
CASE 
    WHEN legacy_cba.deleted_at IS NOT NULL THEN 3  -- Deleted (3)
    ELSE 0  -- Active (0)
END as status
```

### 6. Audit Information
```sql
jsonb_build_object(
    -- SMAC audit_info structure
    'created_by', NULL,
    'deleted_by', NULL,
    'updated_by', NULL,
    'archived_by', NULL,
    'submitted_by', NULL,
    'approved_at', NULL,
    'approved_by', NULL,
    'approval_notes', NULL,
    'rejected_by', NULL,
    'notes', NULL,
    -- Legacy migration metadata
    'legacy_cba_id', legacy_cba_id::text,
    'legacy_nationality_text', nationality_text,
    'migration_source', 'synergy_master.public.cbas.nationality'
) AS audit_info
```

## Business Key
- **Composite Key**: `(cba_id, nationality)` - Each CBA can have multiple nationalities, each nationality can be associated with multiple CBAs

## Data Quality Rules

1. **Required Fields**: `id`, `cba_id`, `nationality` must not be NULL
2. **JSONB Validation**: Only process valid JSONB arrays
3. **Skip "ALL"**: Skip entries where nationality contains `["ALL"]` (handled by `is_all_nationalities` flag in cbas table)
4. **Deduplication**: Ensure no duplicate `(cba_id, nationality)` combinations using DISTINCT ON
5. **Foreign Key Validation**: Only create records where both `cba_id` and `nationality` can be resolved

## Data Filtering

```sql
WHERE cbas_id_mapping.new_id IS NOT NULL  -- Only migrate where cba_id resolved
  AND nationalities_id_mapping.nationality_id IS NOT NULL  -- Only migrate where nationality resolved
  AND TRIM(COALESCE(legacy_cba.nationality_text, '')) <> ''  -- Skip empty values
```

## Validation Checklist

- [ ] Prerequisites migrated: cbas and nationalities tables
- [ ] Row count validation: Count of junction records matches expected combinations
- [ ] Foreign key integrity: All cba_id values exist in crewing.cbas
- [ ] Foreign key integrity: All nationality values exist in public.nationalities
- [ ] No duplicate (cba_id, nationality) combinations
- [ ] No NULL values in required fields (id, cba_id, nationality)
- [ ] JSONB parsing correctly extracts all nationality values
- [ ] "ALL" entries are properly skipped
- [ ] Status inherited correctly from parent CBA
- [ ] Sample records spot-checked for correctness

## Special Considerations

### JSONB Array Handling
- The `nationality` column is JSONB containing arrays of nationality codes
- Each array element creates one junction record
- Empty arrays (`[]`) are skipped
- `["ALL"]` entries are skipped (handled by `is_all_nationalities` flag)

### Nationality Code Matching
- Match nationality values to nationalities table by code (iso_code)
- Use case-insensitive matching with UPPER(TRIM())
- Log unmatched nationality codes for review

### Inheritance from Parent CBA
- `created_at`, `updated_at`, `deleted_at` are inherited from the parent CBA record
- `status` is derived from parent CBA's `deleted_at` (deleted if parent is deleted)

## Migration Notes

- **Junction Table**: Creates many-to-many relationships between CBAs and Nationalities
- **One Record Per Combination**: Creates one record per `(cba_id, nationality)` pair
- **Skip "ALL"**: Does not create records for `["ALL"]` - handled by `is_all_nationalities` boolean
- **Deduplication**: Uses `DISTINCT ON (cba_id, nationality)` to prevent duplicate records
- **Tenant ID**: Uses psql variable from constants.sql
- **Workflow Status**: Uses psql variable (2 = Approved) from constants.sql

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2025-12-20 | Migration Team | Updated mapping based on provided table specifications |

