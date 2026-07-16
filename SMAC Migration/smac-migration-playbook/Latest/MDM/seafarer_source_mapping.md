# Table Mapping: seafarer_sources → seafarer_source

## Overview
- **Legacy Database**: synergy_master
- **Legacy Schema**: public
- **Legacy Table**: seafarer_sources
- **New Database**: smac_master_migration
- **New Schema**: crewing
- **New Table**: seafarer_source
- **Source Script**: `04-migration-scripts/master/seafarer_source_migration.sql`

- **Legacy Path**: `synergy_master.public.seafarer_sources`
- **New Path**: `smac_master_migration.crewing.seafarer_source`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Seafarer Sources (`seafarer_sources` → `seafarer_source`)

## Migration Notes

- Source (commented block): additional static seed rows include `parent_id` and `archived_at`
- Primary dblink INSERT migrates `synergy_master.public.seafarer_sources` → `crewing.seafarer_source`
- Additional static seed rows (POS, COM, etc.) inserted via separate INSERT blocks
- Pre-migration duplicate UUID check on `id` still runs against legacy table
- Commented block would preserve SAC `id` via `resolve_target_id()` with `p_target_id = id`
- Commented block includes additional seeds: SMAC, Preseacadet; post-UPDATE tags by name

## Special Considerations

- Run schema discovery first to verify identifier/uuid columns exist
- Script performs `TRUNCATE TABLE crewing.seafarer_source` before insert (full table reload).

## Column Mapping| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `—` | — | `id` | uuid | Hardcoded UUIDs in seed INSERT VALUES | Not from dblink in active script |
| 2 | `—` | — | `code` | text | Hardcoded per seed: POS, COM, COMSSA, SAP, LOCAL |  |
| 3 | `—` | — | `name` | text | Hardcoded per seed: Poseidon, Compass, Compass SSA, Sap, local |  |
| 4 | `—` | — | `description` | text | `NULL` for all active seeds |  |
| 5 | `—` | — | `tenant_id` | uuid | Hardcoded tenant UUID in seed VALUES | Primary dblink INSERT uses `:'DEFAULT_TENANT_ID'::uuid` |
| 6 | `—` | — | `level` | numeric | Hardcoded `0` |  |
| 7 | `—` | — | `version` | integer | Hardcoded `1` |  |
| 8 | `—` | — | `defined_by` | integer | Hardcoded `0` |  |
| 9 | `—` | — | `workflow_status` | integer | Hardcoded `0` or `2` per seed row | Primary dblink INSERT uses constants |
| 10 | `deleted_at` | timestamp without time zone | `status` | integer | Rule 2.2.1 Case 1: `deleted_at IS NOT NULL` → 3 (Deleted); else 0 (Active) |  |
| 11 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy from legacy; NULL in seed rows |  |
| 12 | `created_at` | timestamp | `created_at` | timestamp | `COALESCE(created_at, NOW())` in dblink INSERT; hardcoded in seeds |  |
| 13 | `updated_at` | timestamp | `updated_at` | timestamp | `COALESCE(updated_at, created_at, NOW())` in dblink INSERT; hardcoded in seeds |  |
| 14 | `—` | — | `audit_info` | jsonb | `migration.build_audit_info()` in dblink INSERT; hardcoded JSONB in seeds |  |
| 15 | `—` | — | `tags` | text[] | Generated from code/name in dblink INSERT; hardcoded per seed |  |



**SAC columns not migrated:** None from primary dblink SELECT; additional static seed rows documented separately in script.

**Additional seed INSERTs:** Static rows (POS, COM, COMSSA, SAP, LOCAL, SMAC, etc.) may include `parent_id` and `archived_at` columns not present in the primary dblink INSERT.

**Commented migration would map:** `id`, `identifier`, `name`, `created_at`, `updated_at`, `deleted_at` with `generate_meaningful_code`, Case 1 status, and tag post-UPDATE.
## Foreign Key Dependencies

### Prerequisites (from source script)

- None documented in migration script or orchestration config

## Data Transformation Rules

Column-level transformations are defined in the source script. Refer to:
- `04-migration-scripts/master/seafarer_source_migration.sql`

## Validation

- Run `05-validation/master/seafarer_source_validation.sql` if available
- Run `06-rollback/master/seafarer_source_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.