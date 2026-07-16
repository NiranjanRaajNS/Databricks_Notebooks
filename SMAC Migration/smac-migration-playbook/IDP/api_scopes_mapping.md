# Table Mapping: ApiScopes → api_scopes

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: ApiScopes (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: api_scopes (lowercase)
- **Migration Priority**: HIGH
- **Estimated Row Count**: To be determined via discovery script

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | Id | text/uuid | id | uuid | Convert text "Id" to uuid if valid, otherwise gen_random_uuid() | Preserve legacy UUID if available |
| 2 | Name | text | name | text | TRIM(name) | Direct copy, trim whitespace |
| 3 | DisplayName | text | display_name | text | TRIM(display_name) | Direct copy, trim whitespace |
| 4 | Description | text | description | text | TRIM(description) | Direct copy, trim whitespace, handle NULL/empty |
| 5 | Enabled | boolean | enabled | boolean | Direct copy | Direct copy |
| 6 | Required | boolean | required | boolean | Direct copy | Direct copy |
| 7 | Emphasize | boolean | emphasize | boolean | Direct copy | Direct copy |
| 8 | ShowInDiscoveryDocument | boolean | show_in_discovery_document | boolean | Direct copy | Direct copy |
| 9 | - | - | code | text | UPPER(REPLACE(REGEXP_REPLACE(TRIM(name), '[^A-Za-z0-9]', '_', 'g'), '__', '_')) | Generate code from name if not in source |
| 10 | - | - | tenant_id | uuid | '67c4470e-7812-4456-bc1b-c71e6df60d1d' | New column for multi-tenancy (see constants.sql) |
| 11 | - | - | version | integer | 1 | New column |
| 12 | - | - | defined_by | integer | 0 | New column - Global (0). Integer, not enum. See constants.sql |
| 13 | - | - | workflow_status | integer | 0 | New column - Draft (0). Integer, not enum. See constants.sql |
| 14 | - | - | status | integer | 0 | New column - Active (0). Integer, not enum. See constants.sql |
| 15 | Created | timestamp | created_at | timestamptz | COALESCE(created, NOW()) | Convert to UTC |
| 16 | Updated | timestamp | updated_at | timestamptz | COALESCE(updated, created_at, NOW()) | Convert to UTC |
| 17 | LastAccessed | timestamp | last_accessed | timestamptz | Direct copy | Direct copy, nullable |
| 18 | NonEditable | boolean | non_editable | boolean | Direct copy | Direct copy |
| 19 | - | - | deleted_at | timestamp | NULL | Not in source |
| 20 | - | - | archived_at | timestamp | NULL | Not in source |
| 21 | - | - | audit_info | jsonb | Build JSON with legacy data | New column for audit trail |

**Note**: Actual column mapping will be determined after running schema discovery script (`01-discovery/idp/inspect_api_scopes_schema.sql`)

## ID Field Handling

**IMPORTANT**: Run schema discovery to verify if `Id` column exists and its type in source table.

**Implementation Status**: ⚠️ PENDING - Needs schema discovery verification

- **Check for `Id` column**: Run discovery script to verify
- **If Id is UUID**: Use `COALESCE(Id, gen_random_uuid()) as id`
- **If Id is text**: Check if valid UUID format, convert if valid, otherwise generate new UUID
- **If Id doesn't exist**: Use `gen_random_uuid() as id` (default)

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- None (master table for API scopes)

### Dependents (migrate after this table)
- **api_resource_scopes** (if exists) - references api_scopes.id
- **api_scope_properties** (if exists) - references api_scopes.id

## Data Transformation Rules

### 1. Primary Key Generation
```sql
-- Pattern 1 (if Id is UUID):
COALESCE(Id, gen_random_uuid()) AS id

-- Pattern 2 (if Id is text):
CASE 
    WHEN Id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' 
        THEN Id::uuid
    ELSE gen_random_uuid()
END AS id

-- Pattern 3 (if Id doesn't exist - default):
gen_random_uuid() AS id
```

### 2. Code Generation
```sql
-- If code exists in source:
TRIM(code) AS code

-- If code doesn't exist, generate from name:
UPPER(REPLACE(REGEXP_REPLACE(TRIM(name), '[^A-Za-z0-9]', '_', 'g'), '__', '_')) AS code
```

### 3. Data Filtering
```sql
-- Only migrate scopes with valid names
WHERE name IS NOT NULL 
  AND TRIM(name) != ''
```

### 4. Required Field Defaults
```sql
'67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid AS tenant_id,  -- See constants.sql for DEFAULT_TENANT_ID
1 AS version,
0 AS defined_by,  -- Global (0) - see constants.sql
0 AS workflow_status,  -- Draft (0) - see constants.sql
0 AS status  -- Active (0) - see constants.sql
```

### 5. Boolean Field Defaults
```sql
COALESCE(enabled, false) AS enabled,
COALESCE(required, false) AS required,
COALESCE(emphasize, false) AS emphasize,
COALESCE(show_in_discovery_document, true) AS show_in_discovery_document,
COALESCE(non_editable, false) AS non_editable
```

### 6. Audit Information
```sql
jsonb_build_object(
    'legacy_id', Id::text,
    'migrated_at', NOW(),
    'migration_source', 'synergy_identity_shore_prod'
) AS audit_info
```

## Discovery Script

Run the following to discover actual schema:
```sql
-- Source schema
SELECT column_name, data_type, is_nullable
FROM dblink('synergy_identity_shore_prod',
    'SELECT column_name, data_type, is_nullable
     FROM information_schema.columns 
     WHERE table_schema = ''public'' 
       AND table_name = ''ApiScopes''
     ORDER BY ordinal_position'
) AS t(column_name text, data_type text, is_nullable text);

-- Target schema
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'api_scopes'
ORDER BY ordinal_position;
```

## Validation Checklist

- [ ] Schema discovery completed - verified all columns
- [ ] Id column checked and handled appropriately
- [ ] Row counts match between legacy and new
- [ ] Primary keys are unique and not null
- [ ] No NULL values in required columns (name, code)
- [ ] Sample records spot-checked
- [ ] Business key uniqueness maintained (code or name)
- [ ] Date/time conversions correct
- [ ] Filtered records are appropriate
- [ ] Case sensitivity handled correctly (ApiScopes → api_scopes)
- [ ] Boolean fields properly migrated
- [ ] Code generation works correctly

