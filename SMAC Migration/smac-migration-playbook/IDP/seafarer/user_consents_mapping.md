# Table Mapping: "Users" (columns: GdPrConsentAcceptedat, Gdpr_Consent) → user_consents

## Overview
- **Legacy Database**: IdentityAdmin_prod
- **Legacy Schema**: public
- **Legacy Table**: "Users" (columns: GdPrConsentAcceptedat, Gdpr_Consent)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: user_consents
- **Source Script**: `04-migration-scripts/idp/seafarer/user_consents_migration.sql`

- **Legacy Path**: `IdentityAdmin_prod.public."Users" (columns: GdPrConsentAcceptedat, Gdpr_Consent)`
- **New Path**: `smac_idp_dev.public.user_consents`

## Business Key

- **Business Key**: `user_id`
- **Source (orchestration)**: User Consents - Seafarer (`Users` → `user_consents`)

## Migration Notes

- This migration extracts GDPR consent data from Users table columns and creates user_consents records.
- Migrates GDPR consent data from Users table columns (GdPrConsentAcceptedat, Gdpr_Consent) in IdentityAdmin_prod database. Extracts consent data and creates user_consents records. Separate from shore user_consents migration. Uses seafarer subfolder for migration scripts. Requires users (seafarer) to be migrated first.

## Special Considerations

- Script performs `TRUNCATE TABLE public.user_consents` before insert (full table reload).
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
| 1 | user_id_text | - | id | - | migration.resolve_id_mapping( 'IdentityAdmin_prod'::VARCHAR(100), 'public'::VARCHAR(100), 'Users'::VARCHAR(100), legacy_data.user_id_text || '|GDPR', current_database()::text::V... | migration.resolve_id_mapping( 'IdentityAdmin_prod'::VARCHAR(100), 'public'::VARCHAR(100), 'Users'::VARCHAR(100), legacy_data.user_id_text || '|GDPR', current_database()::text::V... |
| 2 | derived | - | user_id | - | COALESCE(user_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) as user_id | COALESCE(user_map.target_id, '00000000-0000-0000-0000-000000000000'::uuid) |
| 3 | gdpr_consent | - | consent_id | - | CASE WHEN legacy_data.gdpr_consent IS NOT NULL AND legacy_data.gdpr_consent::text ~ '^[\s]*[\{\[]' THEN legacy_data.gdpr_consent::jsonb WHEN legacy_data.gdpr_consent IS NOT NULL... | CASE WHEN legacy_data.gdpr_consent IS NOT NULL AND legacy_data.gdpr_consent::text ~ '^[\s]*[\{\[]' THEN legacy_data.gdpr_consent::jsonb WHEN legacy_data.gdpr_consent IS NOT NULL... |
| 4 | derived | - | consent_file_path | - | NULL as consent_file_path | NULL |
| 5 | gdpr_consent_accepted_at | - | created_at | - | CASE WHEN legacy_data.gdpr_consent_accepted_at IS NOT NULL AND legacy_data.gdpr_consent_accepted_at::text ~ '^\d{4}-\d{2}-\d{2}' THEN legacy_data.gdpr_consent_accepted_at::times... | CASE WHEN legacy_data.gdpr_consent_accepted_at IS NOT NULL AND legacy_data.gdpr_consent_accepted_at::text ~ '^\d{4}-\d{2}-\d{2}' THEN legacy_data.gdpr_consent_accepted_at::times... |
| 6 | derived | - | updated_at | - | NOW() as updated_at | NOW() |
| 7 | derived | - | deleted_at | - | NULL as deleted_at | NULL |
| 8 | audit fields | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::varchar, NULL::timestamp, NULL::varchar, NULL::text, NULL::varchar, NULL::text ) |
| 9 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 10 | gdpr_consent | - | status | - | CASE WHEN legacy_data.gdpr_consent IS NOT NULL AND legacy_data.gdpr_consent::boolean = true THEN 0 ELSE 2 END as status | CASE WHEN legacy_data.gdpr_consent IS NOT NULL AND legacy_data.gdpr_consent::boolean = true THEN 0 ELSE 2 END |

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

Full migration context: `04-migration-scripts/idp/seafarer/user_consents_migration.sql`

## Validation

- Run `05-validation/idp/user_consents_validation.sql` if available
- Run `06-rollback/idp/user_consents_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
