# Table Mapping: role_claims → role_claims

## Overview
- **Legacy Database**: See migration script
- **Legacy Schema**: -
- **Legacy Table**: -
- **New Database**: smac_master_migration
- **New Schema**: -
- **New Table**: role_claims
- **Source Script**: `04-migration-scripts/idp/role_claims_migration.sql`


## Business Key

- **Composite Key**: (`role_id`, `claim_type`)
- **Source (orchestration)**: Role Claims (`RoleClaims` → `role_claims`)

## Migration Notes

- Source has integer "Id", target has integer id (IDENTITY)

## Special Considerations

- Orchestration dependencies: `roles`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 1

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `roles_id_mapping` | FK lookup | `legacy_id`, `target_id` | `migration.table_mappings` (see SQL) | - |

### `roles_id_mapping`

- **Output columns**: legacy_id, target_id
- **migration.table_mappings**: target_table=roles

```sql
CREATE TEMP TABLE roles_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'roles'
  AND target_db = current_database();
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | derived | - | id | - | nextval(pg_get_serial_sequence('public.role_claims', 'id')) as id | nextval(pg_get_serial_sequence('public.role_claims', 'id')) |
| 2 | derived | - | role_id | - | COALESCE(role_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) as role_id | COALESCE(role_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | derived | - | claim_type | - | TRIM(legacy_data."ClaimType") as claim_type | TRIM(legacy_data."ClaimType") |
| 4 | derived | - | claim_value | - | TRIM(legacy_data."ClaimValue") as claim_value | TRIM(legacy_data."ClaimValue") |
| 5 | derived | - | claim_id | - | '00000000-0000-0000-0000-000000000000'::uuid as claim_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 6 | derived | - | tenant_id | - | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid as tenant_id | '67c4470e-7812-4456-bc1b-c71e6df60d1d'::uuid |
| 7 | derived | - | archived_at | - | NULL as archived_at | NULL |
| 8 | derived | - | created_at | - | NOW() as created_at | NOW() |
| 9 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 10 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 11 | derived | - | audit_info | - | jsonb_build_object( 'legacy_id', legacy_data."Id"::text, 'legacy_role_id', legacy_data."RoleId", 'migrated_at', NOW(), 'migration_source', 'synergy_identity_shore_prod.public."R... | jsonb_build_object( 'legacy_id', legacy_data."Id"::text, 'legacy_role_id', legacy_data."RoleId", 'migrated_at', NOW(), 'migration_source', 'synergy_identity_shore_prod.public."R... |
| 12 | derived | - | status | - | 0 as status | 0 |
| 13 | - | - | role_claim_guid | - | gen_random_uuid() as role_claim_guid | gen_random_uuid() |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Roles ID Mapping
**Output columns**: `legacy_id, target_id`
**migration.table_mappings**: `target_table='roles'`

```sql
CREATE TEMP TABLE roles_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id
FROM migration.table_mappings
WHERE target_table = 'roles'
  AND target_db = current_database();
```

Full migration context: `04-migration-scripts/idp/role_claims_migration.sql`

## Validation

- Run `05-validation/idp/role_claims_validation.sql` if available
- Run `06-rollback/idp/role_claims_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
