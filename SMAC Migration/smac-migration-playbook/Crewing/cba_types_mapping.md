# Table Mapping: cba_types → cba_types

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: cba_types
- **New Database**: smac_crewing_migration
- **New Schema**: crewing
- **New Table**: cba_types
- **Migration Priority**: HIGH (must migrate before cbas)
- **Estimated Row Count**: TBD (to be determined via discovery)

## Source Table Structure (Legacy)
```sql
CREATE TABLE IF NOT EXISTS public.cba_types (
    id uuid NOT NULL DEFAULT public.gen_random_uuid(),
    name text,
    description text,
    identifier text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT cba_types_pkey PRIMARY KEY (id)
);
```

## Target Table Structure (New)
```sql
CREATE TABLE IF NOT EXISTS crewing.cba_types (
    id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    description text,
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
    CONSTRAINT "PK_cba_types" PRIMARY KEY (id)
);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | uuid | id | uuid | COALESCE(id, gen_random_uuid()) | Preserve legacy UUID id when available |
| 2 | identifier | text | - | - | Stored in audit_info | Legacy identifier for reference |
| 3 | - | - | code | text | UPPER(REPLACE(LEFT(TRIM(name), 15), ' ', '_')) | Generate code from name |
| 4 | name | text | name | text | TRIM(name) | Direct copy, trim whitespace |
| 5 | description | text | description | text | CASE WHEN NULL/empty THEN NULL ELSE TRIM() END | Map with null/empty handling |
| 6 | - | - | tenant_id | uuid | :'DEFAULT_TENANT_ID'::uuid | From constants.sql |
| 7 | - | - | parent_id | uuid | NULL | Not applicable from legacy |
| 8 | - | - | version | integer | 1 | Initial version |
| 9 | created_at | timestamp | created_at | timestamp | COALESCE(created_at, NOW()) | Preserve, default to NOW() |
| 10 | updated_at | timestamp | updated_at | timestamp | COALESCE(updated_at, NOW()) | Preserve, default to NOW() |
| 11 | - | - | deleted_at | timestamp | NULL | No deleted_at in source |
| 12 | - | - | archived_at | timestamp | NULL | Not applicable from legacy |
| 13 | id, identifier | uuid, text | audit_info | jsonb | jsonb_build_object() | SMAC audit_info structure |
| 14 | - | - | level | numeric | NULL | Not applicable from legacy |
| 15 | - | - | tags | text[] | NULL | Not applicable from legacy |
| 16 | - | - | status | integer | 0 | Active (0) - see constants.sql |
| 17 | - | - | workflow_status | integer | :'DEFAULT_WORKFLOW_STATUS'::integer | Approved (2) - see constants.sql |
| 18 | - | - | defined_by | integer | :'DEFAULT_DEFINED_BY'::integer | Global (0) - see constants.sql |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- None (master table)

### Dependents (migrate after this table)
- **cbas** (REQUIRED) - cbas.cba_type_id references cba_types.id (direct UUID match)

## Data Transformation Rules

### 1. Primary Key Preservation
```sql
COALESCE(id, gen_random_uuid()) as id
-- Preserve legacy UUID id when available
-- Source table uses UUID for id column
```

### 2. Code Generation
```sql
UPPER(REPLACE(LEFT(TRIM(name), 15), ' ', '_')) as code
-- Generate code from name: first 15 chars, uppercase, replace spaces with underscores
```

### 3. Description Mapping
```sql
CASE 
    WHEN description IS NULL THEN NULL
    WHEN TRIM(description) = '' THEN NULL
    ELSE TRIM(description)
END as description
```

### 4. Audit Information (includes legacy_id for mapping)
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
    'legacy_id', id::text,
    'legacy_identifier', identifier
) AS audit_info
```

### 5. Required Field Defaults
- `tenant_id`: :'DEFAULT_TENANT_ID'::uuid (from constants.sql)
- `version`: 1
- `defined_by`: :'DEFAULT_DEFINED_BY'::integer (0 = Global)
- `workflow_status`: :'DEFAULT_WORKFLOW_STATUS'::integer (2 = Approved)
- `status`: 0 (Active)
- `created_at`: NOW() (if NULL)
- `updated_at`: NOW() (if NULL)

## Data Filtering

### Filtering Rules
```sql
WHERE name IS NOT NULL 
  AND TRIM(name) != ''
-- Only migrate rows with non-empty name
```

**Important**: All records are migrated (no deleted_at filtering since source has no deleted_at column).

## Validation Checklist

- [ ] Row count matches legacy table (excluding NULL/empty names)
- [ ] All required fields are populated
- [ ] UUID preservation verified (legacy UUID id = new id when available)
- [ ] Mapping records created correctly in migration.table_mappings
- [ ] All status/workflow_status/defined_by values are valid integers
- [ ] Audit info structure follows SMAC standard format
- [ ] Code generation verified (first 15 chars from name)
- [ ] Description null/empty handling verified
- [ ] No duplicate codes

## Migration Notes

- **UUID Preservation**: Legacy `id` UUID is preserved as new `id` when available. Source table uses UUID for `id` column.
- **Identifier Field**: The `identifier` text field from source is stored in `audit_info` for reference.
- **Code Generation**: Generates code from name (first 15 characters, uppercase, replace spaces with underscores).
- **Tenant ID**: Uses `:'DEFAULT_TENANT_ID'::uuid` variable from constants.sql.
- **Workflow Status**: Uses `:'DEFAULT_WORKFLOW_STATUS'::integer` (2 = Approved) from constants.sql.
- **No Deleted At**: Source table has no `deleted_at` column, all records are active.

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2025-12-20 | Migration Team | Updated mapping based on provided table specifications |

