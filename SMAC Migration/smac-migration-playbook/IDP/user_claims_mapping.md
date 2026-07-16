# Table Mapping: user_claims → user_claims

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: user_claims
- **Source Script**: `04-migration-scripts/idp/user_claims_migration.sql`


## Business Key

- **Composite Key**: (`user_id`, `claim_type`)
- **Source (orchestration)**: User Claims (`UserClaims` → `user_claims`)

## Special Considerations

- Orchestration dependencies: `users`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `users_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |

### `users_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=users

```sql
CREATE TEMP TABLE users_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'users'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | nextval(pg_get_serial_sequence('public.user_claims', 'id')) as id | nextval(pg_get_serial_sequence('public.user_claims', 'id')) |
| 2 | derived | - | user_id | - | COALESCE(user_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) as user_id | COALESCE(user_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | claim_type | - | claim_type | - | TRIM(legacy_data.claim_type) as claim_type | TRIM(legacy_data.claim_type) |
| 4 | claim_value | - | claim_value | - | TRIM(legacy_data.claim_value) as claim_value | TRIM(legacy_data.claim_value) |
| 5 | derived | - | claim_id | - | '00000000-0000-0000-0000-000000000000'::uuid as claim_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 6 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 7 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 8 | id, user_id | - | audit_info | - | jsonb_build_object( 'legacy_id', legacy_data.id::text, 'legacy_user_id', legacy_data.user_id::text, 'migrated_at', NOW(), 'migration_source', 'synergy_identity_shore_prod' ) as ... | jsonb_build_object( 'legacy_id', legacy_data.id::text, 'legacy_user_id', legacy_data.user_id::text, 'migrated_at', NOW(), 'migration_source', 'synergy_identity_shore_prod' ) |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Users ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='users'`

```sql
CREATE TEMP TABLE users_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'users'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/idp/user_claims_migration.sql`

## Validation

- Run `05-validation/idp/user_claims_validation.sql` if available
- Run `06-rollback/idp/user_claims_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
