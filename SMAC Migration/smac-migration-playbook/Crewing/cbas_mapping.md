# Table Mapping: cbas → cbas

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: cbas
- **New Database**: smac_crewing_migration
- **New Schema**: crewing
- **New Table**: cbas
- **Migration Priority**: MEDIUM (depends on cba_types, currencies)
- **Estimated Row Count**: TBD (to be determined via discovery script)

## Source Table Structure (Legacy)
```sql
CREATE TABLE IF NOT EXISTS public.cbas (
    id bigint NOT NULL DEFAULT nextval('cbas_id_seq'::regclass),
    name character varying,
    code character varying,
    alpha2_code character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    created_by_id character varying,
    created_by_name character varying,
    updated_by_id character varying,
    updated_by_name character varying,
    deleted_at timestamp without time zone,
    description character varying,
    cba_type uuid NOT NULL,
    nationality jsonb,
    currency text,
    include_superior_certificate boolean DEFAULT false,
    CONSTRAINT cbas_pkey PRIMARY KEY (id),
    CONSTRAINT fk_cbas_cba_types_cba_type FOREIGN KEY (cba_type)
        REFERENCES public.cba_types (id)
);
```

## Target Table Structure (New)
```sql
CREATE TABLE IF NOT EXISTS crewing.cbas (
    id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    description text,
    cba_type_id uuid NOT NULL,
    currency_id uuid,
    include_superior_certificate boolean NOT NULL,
    tenant_id uuid NOT NULL,
    parent_id uuid,
    version integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone,
    deleted_at timestamp without time zone,
    archived_at timestamp without time zone,
    audit_info jsonb,
    is_all_nationalities boolean NOT NULL DEFAULT false,
    level numeric,
    tags text[],
    status integer NOT NULL DEFAULT 0,
    workflow_status integer NOT NULL DEFAULT 0,
    defined_by integer NOT NULL DEFAULT 0,
    CONSTRAINT "PK_cbas" PRIMARY KEY (id)
);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | bigint | id | uuid | gen_random_uuid() | Generate new UUID (source has bigint) |
| 2 | code | varchar | code | text | TRIM(code) | Use code from source table directly |
| 3 | name | varchar | name | text | TRIM(name) | Direct copy, trim whitespace |
| 4 | description | varchar | description | text | CASE WHEN NULL/empty THEN NULL ELSE TRIM() END | Map with null/empty handling |
| 5 | cba_type | uuid | cba_type_id | uuid | Direct UUID match | FK to cba_types (direct match) |
| 6 | currency | text | currency_id | uuid | Map via currency code | FK to currencies (match by code) |
| 7 | include_superior_certificate | boolean | include_superior_certificate | boolean | COALESCE(value, false) | Direct copy with default |
| 8 | nationality | jsonb | is_all_nationalities | boolean | Parse for "ALL" | Check if contains ["ALL"] |
| 9 | alpha2_code | varchar | - | - | Stored in audit_info | Legacy reference |
| 10 | - | - | tenant_id | uuid | :'DEFAULT_TENANT_ID'::uuid | From constants.sql |
| 11 | - | - | parent_id | uuid | NULL | Not applicable |
| 12 | - | - | version | integer | 1 | Initial version |
| 13 | created_at | timestamp | created_at | timestamp | COALESCE(created_at, NOW()) | Preserve timestamp |
| 14 | updated_at | timestamp | updated_at | timestamp | COALESCE(updated_at, NOW()) | Preserve timestamp |
| 15 | deleted_at | timestamp | deleted_at | timestamp | deleted_at | Preserve deletion timestamp |
| 16 | - | - | archived_at | timestamp | NULL | Not applicable |
| 17 | created_by_*, updated_by_*, id | various | audit_info | jsonb | migration.build_audit_info() | SMAC structure |
| 18 | - | - | level | numeric | NULL | Not applicable |
| 19 | - | - | tags | text[] | NULL | Not applicable |
| 20 | deleted_at | timestamp | status | integer | CASE WHEN deleted_at IS NOT NULL THEN 3 ELSE 0 END | Map based on deleted_at |
| 21 | - | - | workflow_status | integer | :'DEFAULT_WORKFLOW_STATUS'::integer | Approved (2) |
| 22 | - | - | defined_by | integer | :'DEFAULT_DEFINED_BY'::integer | Global (0) |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- **cba_types** (REQUIRED) - cba_type_id references cba_types.id (direct UUID match)
- **currencies** (REQUIRED) - currency_id references currencies.id (matched by code)

### Dependents (migrate after this table)
- **cba_nationalities** - cba_nationalities.cba_id references cbas.id
- **cba_wage_charts** - cba_wage_charts.cba_id references cbas.id

## Data Transformation Rules

### 1. Primary Key Generation
```sql
gen_random_uuid() as id
-- Generate new UUID (source table uses bigint id)
```

### 2. Foreign Key Mapping (cba_type_id)
```sql
cba_types_lookup.id as cba_type_id
-- Map via direct UUID match (cba_types preserves UUID):
LEFT JOIN crewing.cba_types cba_types_lookup ON cba_types_lookup.id = legacy_data.cba_type
```

### 3. Foreign Key Mapping (currency_id)
```sql
currency_lookup.id as currency_id
-- Map via currency code matching (case-insensitive):
LEFT JOIN public.currencies currency_lookup ON UPPER(TRIM(currency_lookup.code)) = UPPER(TRIM(legacy_data.currency))
```

### 4. Description Mapping
```sql
CASE 
    WHEN legacy_data.description IS NULL THEN NULL
    WHEN TRIM(legacy_data.description) = '' THEN NULL
    ELSE TRIM(legacy_data.description)
END as description
```

### 5. Nationality to Boolean Mapping (is_all_nationalities)
```sql
CASE 
    WHEN legacy_data.nationality IS NULL THEN false
    WHEN TRIM(legacy_data.nationality::text) = '["ALL"]' THEN true
    WHEN legacy_data.nationality @> '["ALL"]'::jsonb THEN true
    ELSE false
END as is_all_nationalities
```

### 6. Status Mapping (Case 1: Only deleted_at)
```sql
CASE 
    WHEN legacy_data.deleted_at IS NOT NULL THEN 3  -- Deleted (3)
    ELSE 0  -- Active (0)
END as status
```

### 7. Audit Info Transformation
```sql
migration.build_audit_info(
    legacy_data.created_by_name::varchar,
    NULL::varchar,  -- deleted_by
    legacy_data.updated_by_name::varchar,
    NULL::varchar,  -- archived_by
    NULL::varchar,  -- submitted_by
    NULL::timestamp,  -- approved_at
    NULL::varchar,  -- approved_by
    NULL::text,  -- approval_notes
    NULL::varchar,  -- rejected_by
    NULL::text  -- notes
) || jsonb_build_object(
    'legacy_id', legacy_data.id::text,
    'legacy_cba_type', legacy_data.cba_type::text,
    'legacy_currency', legacy_data.currency,
    'legacy_alpha2_code', legacy_data.alpha2_code,
    'created_by_id', legacy_data.created_by_id,
    'created_by_name', legacy_data.created_by_name,
    'updated_by_id', legacy_data.updated_by_id,
    'updated_by_name', legacy_data.updated_by_name
) as audit_info
```

### 8. Required Field Defaults
- `tenant_id`: :'DEFAULT_TENANT_ID'::uuid (from constants.sql)
- `version`: 1
- `defined_by`: :'DEFAULT_DEFINED_BY'::integer (0 = Global)
- `workflow_status`: :'DEFAULT_WORKFLOW_STATUS'::integer (2 = Approved)
- `status`: 0 (Active, default) or 3 (Deleted, when deleted_at IS NOT NULL)
- `include_superior_certificate`: false (if NULL)

## Data Filtering

### Filtering Rules
```sql
WHERE legacy_data.name IS NOT NULL 
  AND TRIM(legacy_data.name) != ''
```

**Important**: All records are migrated, including deleted ones. The `deleted_at` timestamp is preserved and used for status mapping.

## Special Considerations

### Nationality JSONB Processing
The `nationality` column in the legacy table is JSONB containing an array of nationality codes. This data is processed in two ways:
1. **is_all_nationalities flag**: Set to `true` if nationality contains `["ALL"]`
2. **cba_nationalities junction table**: Individual nationality values (except "ALL") are extracted and migrated to create junction records

## Validation Checklist

- [ ] Row count matches legacy table (excluding empty names)
- [ ] All required fields are populated
- [ ] Foreign key integrity verified:
  - [ ] cba_type_id references valid cba_types.id
  - [ ] currency_id references valid currencies.id (where not NULL)
- [ ] Mapping records created correctly in migration.table_mappings
- [ ] All status values are valid integers (0 or 3)
- [ ] Audit info structure follows SMAC standard format
- [ ] deleted_at timestamp preserved correctly
- [ ] Status mapping verified (deleted_at IS NOT NULL → status = 3)
- [ ] Code values properly populated from source
- [ ] is_all_nationalities boolean correctly mapped

## Migration Notes

- **UUID Generation**: Generates new UUIDs for `id` (source has bigint).
- **Mapping Pattern**: Uses Pattern B (legacy_id stored in audit_info).
- **Foreign Key Mapping**:
  - `cba_type_id`: Direct UUID match (cba_types preserves UUID).
  - `currency_id`: Matched via currency code (case-insensitive).
- **Status Mapping**: Case 1 pattern (only deleted_at column).
- **Nationality Processing**: Extracted to cba_nationalities junction table.
- **Tenant ID**: Uses psql variable from constants.sql.
- **Workflow Status**: Uses psql variable (2 = Approved) from constants.sql.

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2025-12-20 | Migration Team | Updated mapping based on provided table specifications |

