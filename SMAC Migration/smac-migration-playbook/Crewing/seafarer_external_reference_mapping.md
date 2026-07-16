# Table Mapping: seafarer_external_reference → seafarer_external_reference

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: seafarer_external_reference
- **Source Script**: `04-migration-scripts/crewing/seafarer_external_reference_migration.sql`


## Business Key

- **Composite Key**: (`entity_type`, `entity_id`, `source_reference_no`, `source_system_id`)
- **Source (orchestration)**: Seafarer SAP BP External References (`seafarers` → `external_references`)

## Migration Notes

- migration.check_existing_mapping + migration.is_repeated_migration session flag
- SAP source_system_id: fixed UUID aa84561c-960c-490e-aef2-157c594ac43a (no constants.sql entry).
- TEMP TABLE seafarers_id_mapping from migration.table_mappings (legacy bigint id → ensures seamen migrated)
- audit_info: NULL for migrated SAP BP rows
- status: Active for all migrated SAP BP rows
- migration.resolve_target_id() for id (reuse UUID when mappings exist for
- Target table matches DDL below (created if missing): PK id, entity_type text,
- Partial index idx_shore_external_references_seafarers_sap_bp_slice (created below if missing):
- dblink connection "synergy_seafarer" (legacy seafarers pull)
- public.seafarers migrated (table_mappings rows for target_table = seafarers)
- Migrates synergy_seafarer seafarers.sap_bp_number into shore.external_references for SAP BP linkage. Runs after public.seafarers migration so seafarer UUIDs exist in migration.table_mappings.

## Special Considerations

- Orchestration dependencies: `seafarers`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | - migration.resolve_target_id() for id (reuse UUID when mappings exist for | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | - |

### `seafarers_id_mapping`

- **Purpose**: - migration.resolve_target_id() for id (reuse UUID when mappings exist for
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT source_id::text AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'seafarers'::VARCHAR(100), legacy.id::text, current_database()::text::VARCHAR(100), 'shore... |
| 2 | derived | - | entity_type | - | 'seafarers'::text AS entity_type | 'seafarers'::text |
| 3 | uuid | - | entity_id | - | legacy.uuid::uuid AS entity_id | legacy.uuid::uuid |
| 4 | derived | - | source_system_id | - | 'aa84561c-960c-490e-aef2-157c594ac43a'::uuid AS source_system_id | 'aa84561c-960c-490e-aef2-157c594ac43a'::uuid |
| 5 | sap_bp_number | - | source_reference_no | - | TRIM(legacy.sap_bp_number)::text AS source_reference_no | TRIM(legacy.sap_bp_number)::text |
| 6 | derived | - | reference_type | - | 'sap_bp_number'::text AS reference_type | 'sap_bp_number'::text |
| 7 | derived | - | status | - | 'Active'::varchar(50) AS status | 'Active'::varchar(50) |
| 8 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 9 | created_at | - | created_at | - | COALESCE(legacy.created_at, NOW())::timestamp AS created_at | COALESCE(legacy.created_at, NOW())::timestamp |
| 10 | updated_at, created_at | - | updated_at | - | COALESCE(legacy.updated_at, legacy.created_at, NOW())::timestamp AS updated_at | COALESCE(legacy.updated_at, legacy.created_at, NOW())::timestamp |
| 11 | - | - | archived_at | - | NULL | NULL::timestamp |
| 12 | deleted_at | - | deleted_at | - | legacy.deleted_at::timestamp AS deleted_at | legacy.deleted_at::timestamp |
| 13 | - | - | audit_info | - | NULL | NULL::jsonb |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Purpose**: - migration.resolve_target_id() for id (reuse UUID when mappings exist for
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT source_id::text AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/crewing/seafarer_external_reference_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_external_reference_validation.sql` if available
- Run `06-rollback/crewing/seafarer_external_reference_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
