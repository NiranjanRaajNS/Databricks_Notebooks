# Table Mapping: "Department" → departments

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: "Department"
- **New Database**: smac_master_migration
- **New Schema**: public
- **New Table**: departments
- **Source Script**: `04-migration-scripts/master/departments_migration.sql`

- **Legacy Path**: `synergy_identity_shore_prod.public."Department"`
- **New Path**: `smac_master_migration.public.departments`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Departments (Master) (`departments` → `departments`)

## Migration Notes

- Source: `synergy_identity_shore_prod.public."Department"` (case-sensitive table name)
- Source `Id` (integer) -> `migration.resolve_target_id()` with `p_target_id = NULL`
- `code` from `CodeName` or `generate_meaningful_code(name)`
- No audit/timestamp columns in SAC — `created_at`/`updated_at` set to NOW()
- Filter: `Name IS NOT NULL AND TRIM(Name) <> ''`
- Second INSERT: hardcoded CSV seed rows (Engine, Galley, Deck)


## Special Considerations

- Script performs `TRUNCATE TABLE public.departments` before insert (full table reload).

## Column Mapping| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `Id` | integer | `id` | uuid | `migration.resolve_target_id()` — source_id = `Id::text`; `p_target_id = NULL` | Idempotent UUID; SAC integer PK |
| 2 | `Name` | text | `name` | text | `TRIM(Name)` | NOT NULL in SMAC |
| 3 | `CodeName`, `Name` | text | `code` | text | `COALESCE(NULLIF(TRIM(CodeName), ''), generate_meaningful_code(UPPER(TRIM(Name)), NULL))` | Generated when CodeName empty |
| 4 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | |
| 5 | — | — | `version` | integer | Hardcoded `1` | |
| 6 | — | — | `defined_by` | integer | `:'DEFAULT_DEFINED_BY'::integer` from `constants.sql` | |
| 7 | — | — | `workflow_status` | integer | `:'DEFAULT_WORKFLOW_STATUS'::integer` from `constants.sql` | |
| 8 | — | — | `status` | integer | Rule 2.2.1 Case 1: `deleted_at IS NOT NULL` → 3 (Deleted); else 0 (Active) | No `deleted_at` in SAC |
| 9 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 10 | — | — | `created_at` | timestamp without time zone | `NOW()` | Not in SAC source |
| 11 | — | — | `updated_at` | timestamp without time zone | `NOW()` | Not in SAC source |
| 12 | — | — | `deleted_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 13 | — | — | `level` | numeric | Hardcoded `0` | |
| 14 | — | — | `audit_info` | jsonb | `migration.build_audit_info()` with `SYSTEM_USER_ID` | No audit columns in SAC |
| 15 | `CodeName`, `Name` | text | `tags` | text[] | Distinct lowercase tags from code + normalized name | Derived |



**Additional seed records (not from SAC):** Engine, Galley, Deck from inline CSV with hardcoded UUIDs.


## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/departments_migration.sql`

## Validation

- Run `05-validation/master/departments_validation.sql` if available
- Run `06-rollback/master/departments_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.