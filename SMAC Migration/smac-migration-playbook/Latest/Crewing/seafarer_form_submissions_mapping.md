# Combined Table Mapping: SAC Form Data → seafarer_form_submissions

All three migrations below load data into the same SMAC target table: `smac_crewing_migration.public.seafarer_form_submissions`. Each migration is documented separately, one after another.

| # | SAC Source | Migration Script | Orchestration Group |
|---|------------|------------------|---------------------|
| 1 | `seafarer_joining_documents` + `seafarer_documents` | `seafarer_form_submissions_migration.sql` | SeafarerOther |
| 2 | `seafarer_other_details` (`section_identifier = 'other_details'`) | `seafarer_important_declaration_details_migration.sql` | SeafarerOther |
| 3 | `seafarer_other_details` (`section_identifier = 'self_declaration_details'`) | `seafarer_self_declaration_details_migration.sql` | SeafarerOther |

**Shared prerequisite:** `seafarers` must be migrated first (all scripts resolve `seafarer_id` via `migration.table_mappings`).

---

# 1. seafarer_joining_documents + seafarer_documents → seafarer_form_submissions

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Tables**: `seafarer_joining_documents`, `seafarer_documents` (joined on `seafarer_doc_id`)
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_form_submissions
- **Source Script**: `04-migration-scripts/crewing/seafarer_form_submissions_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_joining_documents` + `synergy_seafarer.public.seafarer_documents`
- **New Path**: `smac_crewing_migration.public.seafarer_form_submissions`

## Business Key

- **Business Key**: `seafarer_joining_documents.id` (uuid)
- **Source (orchestration)**: Seafarer Joining Documents (`seafarer_joining_documents` → `seafarer_form_submissions`)

## Migration Notes

- Inner join: `seafarer_documents.id = seafarer_joining_documents.seafarer_doc_id`
- Filter: `seafarer_documents.form_response IS NOT NULL` and `form_response` is not empty JSON `{}`
- SAC `seafarer_joining_documents.id` (uuid) preserved as SMAC `id` via `migration.resolve_target_id()` with `p_target_id = id`
- Pre-migration duplicate UUID check on SAC `seafarer_joining_documents.id`
- `seafarer_id`: resolve via `seafarer_uuid_mapping` (join `seafarer_uuid`) then `seafarer_id_mapping` (join `seafarer_id`); nil UUID if unmapped
- `submission_data` copied from `seafarer_documents.form_response`
- `is_verified` ← `is_confirmed`; `verified_at` ← `verified_date`; `verification_notes` ← `approval_comment` or `deviate_note`
- `Status`: `COALESCE(join.deleted_at, doc.deleted_at) IS NOT NULL` → Deleted (3), else Active (0) — Case 1
- `audit_info` includes `legacy_joining_document_id` for traceability; SAC user IDs merged from join and document tables
- Mapping `source_table` = `seafarer_joining_documents`
- Script performs `TRUNCATE TABLE public.seafarer_form_submissions` before insert (full table reload)

## Special Considerations

- Orchestration dependencies: `seafarers`
- `created_by_name` / `updated_by_name` selected from join table but not written to `audit_info` (only IDs used)

## ID Mappings

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) |
|--------------|---------|----------------|----------------------------------|
| `seafarer_id_mapping` | FK lookup by numeric SAC seafarer id | `legacy_id`, `new_id` | `seafarers` |
| `seafarer_uuid_mapping` | FK lookup by SAC seafarer uuid | `legacy_uuid`, `new_id` | `seafarers` |

### `seafarer_id_mapping`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

### `seafarer_uuid_mapping`

```sql
CREATE TEMP TABLE seafarer_uuid_mapping AS
SELECT source_id::uuid AS legacy_uuid, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `seafarer_joining_documents.id` | uuid | `id` | uuid | `migration.resolve_target_id()` — source_table = `seafarer_joining_documents`; source_id = `id::text`; `p_target_id = id` | Preserves joining-document uuid as SMAC `id` |
| 2 | `seafarer_joining_documents.seafarer_uuid`, `seafarer_joining_documents.seafarer_id` | uuid, bigint | `seafarer_id` | uuid | `COALESCE(seafarer_uuid_map.new_id, seafarer_id_map.new_id, nil UUID)` | Lookup: `migration.table_mappings` where `target_table = 'seafarers'`; uuid tried before bigint |
| 3 | — | — | `form_type_id` | uuid | `NULL` | Not available in SAC source |
| 4 | — | — | `form_definitions_id` | uuid | Hardcoded nil UUID (`00000000-0000-0000-0000-000000000000`) | Placeholder; not resolved from source |
| 5 | `seafarer_documents.form_response` | jsonb | `submission_data` | jsonb | `COALESCE(form_response, '{}'::jsonb)` | Form payload from joined document; filter requires non-empty response |
| 6 | — | — | `form_version` | integer | Hardcoded `1` | Initial version; not in SAC source |
| 7 | — | — | `workflow_status_id` | uuid | Hardcoded nil UUID | Not resolved from source |
| 8 | `seafarer_documents.is_confirmed` | boolean | `is_verified` | boolean | `COALESCE(is_confirmed, false)` | SAC confirmation flag |
| 9 | `seafarer_documents.verified_date` | date | `verified_at` | timestamp without time zone | Direct copy | Nullable; from document table |
| 10 | `seafarer_documents.verified_by_id` | character varying | `verified_by_id` | uuid | Cast to UUID when value matches UUID format; else `NULL` | From document table |
| 11 | `seafarer_documents.approval_comment`, `seafarer_documents.deviate_note` | character varying | `verification_notes` | text | `COALESCE(approval_comment, deviate_note)` | First non-null comment wins |
| 12 | `seafarer_joining_documents.deleted_at`, `seafarer_documents.deleted_at` | timestamp without time zone | `Status` | integer | `COALESCE(join.deleted_at, doc.deleted_at) IS NOT NULL` → Deleted (3); else Active (0) | Case 1 — either table soft-delete marks record deleted |
| 13 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 14 | `seafarer_joining_documents.created_at`, `seafarer_documents.created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(join.created_at, doc.created_at, NOW())` | Earliest available timestamp |
| 15 | `seafarer_joining_documents.updated_at`, `seafarer_documents.updated_at`, `created_at` (both) | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(join.updated_at, doc.updated_at, join.created_at, doc.created_at, NOW())` | Multi-level fallback chain |
| 16 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 17 | `seafarer_joining_documents.deleted_at`, `seafarer_documents.deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | `COALESCE(join.deleted_at, doc.deleted_at)` | Soft-delete from either table |
| 18 | `seafarer_joining_documents.created_by_id`, `seafarer_documents.created_by_id` | character varying | `audit_info` → `created_by` | text (jsonb) | Prefer join `created_by_id`; fallback to doc `created_by_id`; empty → default system user | Consolidated into SMAC `audit_info` JSON |
| 19 | `seafarer_joining_documents.updated_by_id`, `seafarer_documents.updated_by_id` | character varying | `audit_info` → `updated_by` | text (jsonb) | Prefer join `updated_by_id`; fallback to doc `updated_by_id`; empty → default system user | Consolidated into SMAC `audit_info` JSON |
| 20 | `seafarer_joining_documents.deleted_by_id` | character varying | `audit_info` → `deleted_by` | text (jsonb) | Direct copy when non-empty; else `NULL` | From joining-documents table only |
| 21 | `seafarer_joining_documents.id` | uuid | `audit_info` → `legacy_joining_document_id` | text (jsonb) | `legacy_join.id::text` appended to `audit_info` | Traceability for mapping; SAC uuid preserved as SMAC `id` so no `legacy_id` |
| 22 | — | — | `audit_info` → `archived_by`, `submitted_by`, `approved_at`, `approved_by`, `approval_notes`, `rejected_by`, `notes` | various | `NULL` | Not available in SAC source |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated (join table):** `seafarer_doc_id`, `contract_id`, `vessel_id`, `doc_sub_category_id`, `status`, `created_by_name`, `updated_by_name` — selected in dblink but not mapped to SMAC columns (names not used in `audit_info`).

**SAC columns not migrated (document table):** `seafarer_id` on document row (seafarer resolved from join table).

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

## Validation

- Run `05-validation/crewing/seafarer_form_submissions_validation.sql` if available
- Run `06-rollback/crewing/seafarer_form_submissions_rollback.sql` if rollback is required

---

# 2. seafarer_other_details (Important Declaration) → seafarer_form_submissions

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_other_details
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_form_submissions
- **Source Script**: `04-migration-scripts/crewing/seafarer_important_declaration_details_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_other_details` (filter: `section_identifier = 'other_details'`)
- **New Path**: `smac_crewing_migration.public.seafarer_form_submissions`

## Business Key

- **Business Key**: `seafarer_other_details.id` (bigint)
- **Source (orchestration)**: Seafarer Important Declaration Details (`seafarer_other_details` → `seafarer_form_submissions`)

## Migration Notes

- Filter: `section_identifier = 'other_details'`
- Source `id` is bigint — uses `migration.resolve_target_id()` with `p_target_id = NULL` (idempotent UUID per SAC id)
- `form_type_id` and `form_definitions_id` resolved at runtime from `smac_master_migration.template.form_types` / `form_definitions` where `code = 'IDF'`
- Deletes existing SMAC rows for this IDF form type before insert (shared table; does not truncate entire table)
- `submission_data` built by parsing `detail_response` JSON array — extracts field items by id (46, 73–80) into Important Declaration form structure
- Rank labels for drydocking/new construction resolved via `rank_id_mapping` + `rank_name_lookup` from `smac_master_migration`
- `is_verified` hardcoded `true`; `verified_at` = `created_at`
- `Status`: `deleted_at IS NOT NULL` → Deleted (3), else Active (0) — Case 1
- SAC has no `created_by_id` / `updated_by_id` in dblink SELECT for audit — `audit_info` user fields default to system user
- Requires `seafarers` migrated first

## Special Considerations

- Shared target table with other form migrations; only IDF rows cleared before this insert
- `updated_by_id`, `updated_by_name` in dblink SELECT but not used in INSERT
- Orchestration dependencies: `seafarers`, `ranks` (via master DB lookup)

## ID Mappings

**Total lookup tables:** 4

| Lookup Table | Purpose | Output Columns | table_mappings / dblink |
|--------------|---------|----------------|-------------------------|
| `seafarer_id_mapping` | FK lookup by numeric seafarer id | `legacy_id`, `new_id` | `seafarers` |
| `seafarer_uuid_mapping` | FK lookup by seafarer uuid | `legacy_uuid`, `new_id` | `seafarers` |
| `rank_id_mapping` | Legacy rank id → SMAC rank uuid | `legacy_rank_id`, `new_rank_id` | `ranks` via `smac_master_migration` dblink |
| `rank_name_lookup` | Rank uuid → rank name | `rank_id`, `rank_name` | `public.ranks` via `smac_master_migration` dblink |

### `rank_id_mapping`

```sql
CREATE TEMP TABLE rank_id_mapping AS
SELECT source_id::bigint AS legacy_rank_id, target_id AS new_rank_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table = ''ranks'' AND LENGTH(source_id) <= 20 AND source_id !~ ''[^0-9]'''
) AS tm(source_id text, target_id uuid);
```

### `rank_name_lookup`

```sql
CREATE TEMP TABLE rank_name_lookup AS
SELECT id AS rank_id, name AS rank_name
FROM dblink('smac_master_migration',
    'SELECT id, name FROM public.ranks WHERE id IS NOT NULL AND name IS NOT NULL'
) AS r(id uuid, name text);
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_table = `seafarer_other_details`; source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID; SAC has bigint `id` only |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping`; nil UUID if unmapped | Lookup: `migration.table_mappings` where `target_table = 'seafarers'` |
| 3 | — (resolved from master) | uuid | `form_type_id` | uuid | Resolved from `template.form_types` where `code = 'IDF'` | Looked up via dblink to `smac_master_migration` at migration start |
| 4 | — (resolved from master) | uuid | `form_definitions_id` | uuid | Resolved from `template.form_definitions` where `code = 'IDF'` | Looked up via dblink to `smac_master_migration` at migration start |
| 5 | `detail_response` | text | `submission_data` | jsonb |- | detail_response mapped to submission_data|
| 6 | — | — | `form_version` | integer | Hardcoded `1` | Initial version |
| 7 | — | — | `workflow_status_id` | uuid | Hardcoded nil UUID | Not resolved from source |
| 8 | — | — | `is_verified` | boolean | Hardcoded `true` | All migrated IDF records marked verified |
| 9 | `created_at` | timestamp without time zone | `verified_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Verification timestamp set to record creation time |
| 10 | — | — | `verified_by_id` | uuid | `NULL` | Not in SAC source |
| 11 | — | — | `verification_notes` | text | `NULL` | Not in SAC source |
| 12 | `deleted_at` | timestamp without time zone | `Status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Case 1 — `deleted_at` only |
| 13 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 14 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Direct copy with fallback |
| 15 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` when `updated_at` is NULL |
| 16 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 17 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 18 | — | — | `audit_info` → `created_by`, `updated_by` | text (jsonb) | Default system user (`01966284-af97-72c7-ac98-3a1b858e9509`) | SAC has no creator/updater user id for this section |
| 19 | — | — | `audit_info` → `deleted_by`, `archived_by`, `submitted_by`, `approved_at`, `approved_by`, `approval_notes`, `rejected_by`, `notes` | various | `NULL` | Not available in SAC source |

### submission_data field summary (from `detail_response` items)

| SAC item id | SMAC `submission_data.data` field(s) | Transformation |
|-------------|--------------------------------------|----------------|
| 46 | `breakInSeaService` | `Yes` → `'yes'`; else `'no'` |
| 73 | `drydocking`, `drydockingRank`, `newConstruction`, `newConstructionRank` | Yes/No booleans; rank id from nested `detail.id` mapped via `rank_id_mapping`; rank name in `metadata.selectData` |
| 74 | `incidentTypes`, `incidentDetails` | Multi-select options → boolean object; free-text detail |
| 75 | `courtEnquiry`, `courtEnquiryDetailsText` | Yes/No radio + detail text |
| 76 | `criminalCaseRadio`, `criminalCaseDetails` | Yes/No radio + detail text |
| 77 | `certificateSuspended`, `certificateDetails` | Yes/No radio + detail text |
| 78 | `medicalType`, `medicalDetails` | Multi-select conditions → boolean object; detail text |
| 79 | `habitualUser`, `habitualUserDetails` | Yes/No radio + detail text |
| 80 | `multinationalWorkforce`, `multinationalWorkforceDetails` | Yes/No radio + detail text |

**SMAC columns not migrated:** None beyond defaults above.

**SAC columns not migrated:** `stage`, `section_identifier` (filter only), `updated_by_id`, `updated_by_name`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`
- `ranks` (master DB — for rank name resolution in `submission_data`)

## Validation

- Run `05-validation/crewing/seafarer_important_declaration_details_validation.sql` if available
- Run `06-rollback/crewing/seafarer_important_declaration_details_rollback.sql` if rollback is required

---

# 3. seafarer_other_details (Self Declaration) → seafarer_form_submissions

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_other_details
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_form_submissions
- **Source Script**: `04-migration-scripts/crewing/seafarer_self_declaration_details_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.seafarer_other_details` (filter: `section_identifier = 'self_declaration_details'`)
- **New Path**: `smac_crewing_migration.public.seafarer_form_submissions`

## Business Key

- **Business Key**: `seafarer_other_details.id` (bigint)
- **Source (orchestration)**: Seafarer Self Declaration Details (`seafarer_other_details` → `seafarer_form_submissions`)

## Migration Notes

- Filter: `section_identifier = 'self_declaration_details'`
- Source `id` is bigint — uses `migration.resolve_target_id()` with `p_target_id = NULL`
- Hardcoded `form_type_id` = `019b07ae-1b1e-7eea-9da7-e6fde212c5a6`; `form_definitions_id` = `119a535b-4d32-7225-8d46-734798256f91`
- `detail_response` (text/JSON) parsed into `onboarding_self_declaration_form` structure in `submission_data`
- `is_verified` hardcoded `false`; verification fields not populated
- `Status`: `deleted_at IS NOT NULL` → Deleted (3), else Active (0) — Case 1
- Does not truncate entire `seafarer_form_submissions` table (shared with other form migrations)
- Requires `seafarers` migrated first

## Special Considerations

- Orchestration dependencies: `seafarers`
- `updated_by_id`, `updated_by_name` in dblink SELECT but not used in INSERT

## ID Mappings

**Total lookup tables:** 2

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) |
|--------------|---------|----------------|----------------------------------|
| `seafarer_id_mapping` | FK lookup by numeric seafarer id | `legacy_id`, `new_id` | `seafarers` |
| `seafarer_uuid_mapping` | FK lookup by seafarer uuid | `legacy_uuid`, `new_id` | `seafarers` |

### `seafarer_id_mapping`

```sql
CREATE TEMP TABLE seafarer_id_mapping AS
SELECT source_id::bigint AS legacy_id, target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database()
  AND source_id ~ '^[0-9]+$';
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | `id` | bigint | `id` | uuid | `migration.resolve_target_id()` — source_table = `seafarer_other_details`; source_id = `id::text`; `p_target_id = NULL` | Idempotent UUID generation |
| 2 | `seafarer_id` | bigint | `seafarer_id` | uuid | Map via `seafarer_id_mapping`; nil UUID if unmapped | Lookup: `migration.table_mappings` where `target_table = 'seafarers'` |
| 3 | — | — | `form_type_id` | uuid | Hardcoded `019b07ae-1b1e-7eea-9da7-e6fde212c5a6` | Self-declaration form type |
| 4 | — | — | `form_definitions_id` | uuid | Hardcoded `119a535b-4d32-7225-8d46-734798256f91` | Self-declaration form definition |
| 5 | `detail_response` | text | `submission_data` | jsonb | Parse text/JSON into `onboarding_self_declaration_form` structure (`_id`, `_form`, `data`, `_submission`) — see field summary below | Empty/missing response → default empty form structure |
| 6 | — | — | `form_version` | integer | Hardcoded `1` | Initial migration version |
| 7 | — | — | `workflow_status_id` | uuid | Hardcoded nil UUID | Not populated |
| 8 | — | — | `is_verified` | boolean | Hardcoded `false` | Not verified in source |
| 9 | — | — | `verified_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 10 | — | — | `verified_by_id` | uuid | `NULL` | Not in SAC source |
| 11 | — | — | `verification_notes` | text | `NULL` | Not in SAC source |
| 12 | `deleted_at` | timestamp without time zone | `Status` | integer | `deleted_at IS NOT NULL` → Deleted (3); else Active (0) | Case 1 — `deleted_at` only |
| 13 | — | — | `tenant_id` | uuid | `:'DEFAULT_TENANT_ID'::uuid` from `constants.sql` | Standard tenant default |
| 14 | `created_at` | timestamp without time zone | `created_at` | timestamp without time zone | `COALESCE(created_at, NOW())` | Also embedded in `submission_data._submission` |
| 15 | `updated_at`, `created_at` | timestamp without time zone | `updated_at` | timestamp without time zone | `COALESCE(updated_at, created_at, NOW())` | Falls back to `created_at` |
| 16 | — | — | `archived_at` | timestamp without time zone | `NULL` | Not in SAC source |
| 17 | `deleted_at` | timestamp without time zone | `deleted_at` | timestamp without time zone | Direct copy | Soft-delete timestamp preserved |
| 18 | — | — | `audit_info` → `created_by`, `updated_by` | text (jsonb) | Default system user (`01966284-af97-72c7-ac98-3a1b858e9509`) | SAC has no creator/updater user id for this section |
| 19 | — | — | `audit_info` → `deleted_by`, `archived_by`, `submitted_by`, `approved_at`, `approved_by`, `approval_notes`, `rejected_by`, `notes` | various | `NULL` | Not available in SAC source |

### submission_data field summary (from `detail_response` JSON)

| SAC JSON path | SMAC `submission_data.data` field | Transformation |
|---------------|-----------------------------------|----------------|
| `seafarer_declaration.pp_no` | `pp_no` | Direct text copy |
| `seafarer_declaration.seafarer_name` | `seafarer_name` | Direct text copy |
| `seafarer_declaration.declaration_date` | `declaration_date` | Direct copy when non-empty |
| `break_in_service_panel.from_date` | `from_date` | Direct copy when non-empty |
| `break_in_service_panel.to_date` | `to_date` | Direct copy when non-empty |
| `break_in_service_panel.break_in_service` | `break_in_service` | `true` when array non-empty |
| `break_in_service_panel.declaration_1` | `declaration_1` | Array items `item1`/`item2`/`other` → `courses_attended` / `worked_ashore` / `other` booleans |
| `break_in_service_panel.declaration_1_Comment` | `declaration_1_other_details` | Populated only when `other` is true |
| `declaration_2` | `declaration_2` | Array or object → `item1`, `item2`, `item3` booleans |
| `reference_panel.no_reference` | `no_reference` | `true` when non-empty array |
| `reference_panel.reference` | `reference` | Array copied when present |
| `created_at` | `_submission` | Formatted as ISO timestamp string on root JSON |

**SMAC columns not migrated:** None — all target columns populated or defaulted.

**SAC columns not migrated:** `stage`, `section_identifier` (filter only), `updated_by_id`, `updated_by_name`.

## Foreign Key Dependencies

### Prerequisites (from source script)

- `seafarers`

## Validation

- Run `05-validation/crewing/seafarer_self_declaration_details_validation.sql` if available
- Run `06-rollback/crewing/seafarer_self_declaration_details_rollback.sql` if rollback is required

---

## Document Status

Combined mapping document for all three `seafarer_form_submissions` migration paths. Reviewed against migration scripts. Individual legacy mapping files (`seafarer_important_declaration_details_mapping.md`, `seafarer_self_declaration_details_mapping.md`) may be kept for orchestration references or consolidated here.
