# Table Mapping: seafarer_employee_reference → seafarer_employee_references

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_employee_reference
- **New Database**: smac_crewing_migration
- **New Schema**: shore
- **New Table**: seafarer_employee_references
- **Source Script**: `04-migration-scripts/crewing/seafarer_employee_references_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_employee_reference`
- **New Path**: `smac_crewing_migration.shore.seafarer_employee_references`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Seafarer Employee References (`seafarer_employee_reference` → `seafarer_employee_references`)

## Migration Notes

- SAC `id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Duplicate UUID check on SAC `id` is commented out in script (`id` is PK and already unique)
- `seafarer_id` is uuid in SAC — cast directly when valid UUID format; no `table_mappings` lookup needed
- `workflow_status_id` from `approved_workflow_status` lookup (`public.workflow_status` where `code = 'APPROVED'` via dblink `smac_master_migration`)
- `status` hardcoded `'active'` for all migrated records (SAC has no `deleted_at` or `status`)
- Uses `migration.build_audit_info()` — source has no audit columns
- Requires `seafarers` table migrated first

## Special Considerations

- Script performs `TRUNCATE TABLE shore.seafarer_employee_references` before insert (full table reload).
- Orchestration dependencies: `seafarers`

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_id = `id::text`; `p_target_id = id` | Preserves SAC uuid as SMAC `id`; idempotent via `id_mappings` |
| 2 | `seafarer_id` | uuid | `seafarer_id` | uuid | Cast to uuid when valid UUID format; else `NULL` | SAC stores uuid directly; no `table_mappings` lookup |
| 3 | — | — | `referred_by_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 4 | `referred_by` | text | `referred_by_name` | text | `TRIM(referred_by)` | SAC `referred_by` → SMAC `referred_by_name` |
| 5 | — | — | `employer_id` | uuid | `NULL` | No equivalent in SAC; not populated |
| 6 | `employer` | text | `employer_name` | text | `TRIM(employer)` | SAC `employer` → SMAC `employer_name` |
| 7 | `pic_contact` | text | `contact_person` | text | `TRIM(pic_contact)` | Direct rename |
| 8 | `email` | text | `contact_email` | text | `TRIM(email)` | Direct rename |
| 9 | `phone_number` | text | `contact_phone` | text | `TRIM(phone_number)` | Direct rename |
| 10 | `conduct` | text | `conduct_rating` | text | `TRIM(conduct)` | SAC `conduct` → SMAC `conduct_rating` |
| 11 | — | — | `remarks` | text | `NULL` | No equivalent in SAC; not populated |
| 12 | — | — | `workflow_status_id` | uuid | `(SELECT workflow_status_id FROM approved_workflow_status LIMIT 1)` | APPROVED workflow status lookup |
| 13 | — | — | `status` | text | Hardcoded `'active'` | SAC has no `deleted_at` or `status` column |
| 14 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 15 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 16 | `updated_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, NOW())` | Direct copy with fallback |
| 17 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` — all audit fields NULL | Source has no audit columns; no `legacy_id` (uuid preserved as `id`) |

**SMAC columns not migrated:** `archived_at`, `deleted_at` — no source equivalent in SAC `seafarer_employee_reference`.

**SAC columns not migrated:** `reference_data_source` — selected in dblink but not mapped to any SMAC column.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/crewing/seafarer_employee_references_migration.sql`

## Validation

- Run `05-validation/crewing/seafarer_employee_references_validation.sql` if available
- Run `06-rollback/crewing/seafarer_employee_references_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
