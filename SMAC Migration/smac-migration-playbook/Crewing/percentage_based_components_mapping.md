# Table Mapping: percentage_based_components → percentage_based_components

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: wages
- **Legacy Table**: percentage_based_components
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: percentage_based_components
- **Migration Priority**: MEDIUM
- **Estimated Row Count**: To be determined via discovery script

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | uuid | id | uuid | COALESCE(id, gen_random_uuid()) | Primary key - preserve legacy UUID id when available |
| 2 | proportion | numeric | proportion | numeric | COALESCE(proportion, 0::numeric) | Preserve proportion from source, default to 0 if NULL |
| 3 | derived_component_id | uuid | derived_component_id | uuid | derived_component_id | Preserve derived_component_id from source |
| 4 | derived_from_component_id | uuid | derived_from_component_id | uuid | derived_from_component_id | Preserve derived_from_component_id from source |
| 5 | isactive | boolean | isactive | boolean | COALESCE(isactive, true) | Preserve isactive boolean, default to true if NULL |
| 6 | - | - | derived_from_component_type | integer | 0 | New column - default to 0 (integer, not enum) |
| 7 | - | - | tenant_id | uuid | '67c4470e-7812-4456-bc1b-c71e6df60d1d' | New column for multi-tenancy (see constants.sql) |
| 8 | - | - | version | integer | 1 | New column |
| 9 | - | - | defined_by | integer | 0 | New column - Global (0). Integer, not enum. See constants.sql |
| 10 | - | - | workflow_status | integer | 0 | New column - Draft (0). Integer, not enum. See constants.sql |
| 11 | - | - | status | integer | 0 | New column - Active (0). Integer, not enum. See constants.sql |
| 12 | - | - | created_at | timestamptz | NOW() | Legacy table doesn't have created_at column |
| 13 | - | - | updated_at | timestamptz | NOW() | Legacy table doesn't have updated_at column |
| 14 | - | - | audit_info | jsonb | Build JSON with legacy data | New column for audit trail |

## ID Field Handling

**IMPORTANT**: Source table has `id` as `uuid`, target table has `id` as `uuid`.

- **Implementation Pattern**: Use `COALESCE(id, gen_random_uuid())` to preserve legacy UUID when available
- **Legacy ID Storage**: Store `legacy_id` and `legacy_uuid` in `audit_info` JSONB for reference
- **Mapping Table**: Store mapping in `migration.table_mappings` with `legacy_id` as the uuid id from source

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- None (master table, but may reference other component tables)

### Dependents (migrate after this table)
- Any tables that reference percentage_based_components

## Data Transformation Rules

### 1. Primary Key Generation
```sql
-- Source table id is uuid, target table id is uuid
-- Preserve legacy UUID when available
COALESCE(id, gen_random_uuid()) AS id
```

### 2. Proportion Handling
```sql
-- Preserve proportion from source, default to 0 if NULL
COALESCE(proportion, 0::numeric) AS proportion
```

### 3. Derived Component IDs
```sql
-- Preserve derived_component_id and derived_from_component_id from source
-- These are UUID foreign keys that may reference other component tables
derived_component_id AS derived_component_id,
derived_from_component_id AS derived_from_component_id
```

### 4. Required Field Defaults
```sql
'67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid AS tenant_id,  -- See constants.sql for DEFAULT_TENANT_ID
1 AS version,
0 AS defined_by,  -- Global (0) - see constants.sql
0 AS workflow_status,  -- Draft (0) - see constants.sql
0 AS status,  -- Active (0) - see constants.sql
0 AS derived_from_component_type,  -- Default to 0 (integer, not enum)
NOW() AS created_at,  -- Legacy table doesn't have created_at column
NOW() AS updated_at  -- Legacy table doesn't have updated_at column
```

### 5. Audit Information
```sql
jsonb_build_object(
    'legacy_id', id::text,
    'legacy_uuid', id::text,  -- Store legacy UUID for reference
    'migrated_at', NOW(),
    'migration_source', 'synergy_master.wages'
) AS audit_info
```

## Validation Checklist

- [ ] Row count matches legacy table
- [ ] All required fields are populated
- [ ] No duplicate IDs
- [ ] All status/workflow_status/defined_by values are valid integers (0-3)
- [ ] Proportion values are valid numeric values
- [ ] isactive values are valid booleans
- [ ] Mapping records created correctly
- [ ] UUID preservation verified (legacy UUIDs preserved when available)

