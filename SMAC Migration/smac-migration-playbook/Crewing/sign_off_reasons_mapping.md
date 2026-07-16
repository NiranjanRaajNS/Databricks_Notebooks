# Table Mapping: sign_off_reasons → sign_off_reasons

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: sign_off_reasons
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: sign_off_reasons
- **Migration Priority**: MEDIUM
- **Estimated Row Count**: To be determined via discovery script

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | identifier | uuid | id | uuid | identifier | Primary key - preserve legacy identifier UUID |
| 2 | id | bigint | - | - | Stored in audit_info | Legacy bigint id stored in audit_info for reference |
| 3 | name | text | name | text | TRIM(COALESCE(name, 'UNKNOWN')) | Direct copy, trim whitespace, default to 'UNKNOWN' if NULL |
| 4 | - | - | code | text | Generated from name + UUID suffix | Generate unique code from name (source table doesn't have code column) |
| 5 | created_at | timestamp | created_at | timestamptz | COALESCE(created_at, NOW()) | Convert to UTC, default to NOW() if NULL |
| 6 | updated_at | timestamp | updated_at | timestamptz | COALESCE(updated_at, NOW()) | Default to NOW() if NULL |
| 7 | deleted_at | timestamp | - | - | Filter out deleted records | Exclude deleted records (WHERE deleted_at IS NULL) |
| 8 | - | - | tenant_id | uuid | '67c4470e-7812-4456-bc1b-c71e6df60d1d' | New column for multi-tenancy (see constants.sql) |
| 9 | - | - | version | integer | 1 | New column |
| 10 | - | - | defined_by | integer | 0 | New column - Global (0). Integer, not enum. See constants.sql |
| 11 | - | - | workflow_status | integer | 0 | New column - Draft (0). Integer, not enum. See constants.sql |
| 12 | - | - | status | integer | 0 | New column - Active (0). Integer, not enum. See constants.sql |
| 13 | - | - | audit_info | jsonb | Build JSON with legacy data | New column for audit trail |

## ID Field Handling

**IMPORTANT**: Source table has `identifier` as `uuid`, target table has `id` as `uuid`.

- **Implementation Pattern**: Use `identifier` directly as `id` (preserve legacy UUID identifier)
- **Legacy ID Storage**: Store `legacy_id` (bigint id) in `audit_info` JSONB for reference
- **Mapping Table**: Store mapping in `migration.table_mappings` with `legacy_id` as the bigint id from source and `new_id` as the preserved UUID identifier

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- None (master table)

### Dependents (migrate after this table)
- Any tables that reference sign_off_reasons

## Data Transformation Rules

### 1. Primary Key Generation
```sql
-- Source table has identifier (uuid), target table has id (uuid)
-- Preserve legacy identifier UUID directly as new id
identifier AS id
```

### 2. Code Generation
```sql
-- Generate unique code from name: first 15 chars + last 4 hex chars of UUID for uniqueness
UPPER(REPLACE(LEFT(TRIM(name), 15), ' ', '_') || '_' || RIGHT(REPLACE(identifier::text, '-', ''), 4)) AS code
```

### 3. Name Handling
```sql
-- Preserve name from source, trim whitespace, default to 'UNKNOWN' if NULL
COALESCE(TRIM(name), 'UNKNOWN') AS name
```

### 4. Required Field Defaults
```sql
'67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid AS tenant_id,  -- See constants.sql for DEFAULT_TENANT_ID
1 AS version,
0 AS defined_by,  -- Global (0) - see constants.sql
0 AS workflow_status,  -- Draft (0) - see constants.sql
0 AS status,  -- Active (0) - see constants.sql
COALESCE(created_at, NOW()) AS created_at,
COALESCE(updated_at, NOW()) AS updated_at
```

### 5. Audit Information
```sql
jsonb_build_object(
    'legacy_id', id::text,  -- Store legacy bigint id for reference
    'migrated_at', NOW(),
    'migration_source', 'synergy_master'
) AS audit_info
```

### 6. Filtering Rules
- **Exclude deleted records**: `WHERE deleted_at IS NULL`
- **Exclude records without identifier**: `WHERE identifier IS NOT NULL`
- **Exclude records with empty name**: `WHERE TRIM(COALESCE(name, '')) <> ''`

## Validation Checklist

- [ ] Row count matches legacy table (excluding deleted records and records without identifier)
- [ ] All required fields are populated
- [ ] No duplicate codes
- [ ] All status/workflow_status/defined_by values are valid integers (0-3)
- [ ] No NULL or empty names
- [ ] No NULL or empty codes
- [ ] Mapping records created correctly
- [ ] UUID preservation verified (legacy identifier UUIDs preserved)

