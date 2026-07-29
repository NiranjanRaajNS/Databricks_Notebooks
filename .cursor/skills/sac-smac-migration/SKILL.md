---
name: sac-smac-migration
description: Comprehensive reference for migrating reporting views from SAC (reporting_layer.sac_prod_seafarer_public.*) to SMAC (reporting_layer.smac_prod.*) for Synergy Marine's crewing system. Use when migrating SAC tables to SMAC, finding SMAC equivalents, writing SMAC queries, or validating migrated tables.
---

# SAC to SMAC Migration Skill

Comprehensive reference for migrating reporting views from SAC (`reporting_layer.sac_prod_seafarer_public.*`) to SMAC (`reporting_layer.smac_prod.*`) for Synergy Marine's crewing system.

**Use this when:**
- Migrating any SAC reporting table/view to SMAC
- Finding the SMAC equivalent of a SAC source table
- Writing queries against SMAC crewing data
- Validating migrated tables between systems

## Playbook & Mapping Files

This file lives in: `/Workspace/Shared/smac-migration-playbook/Latest/`

### SAC Source Notebook
The SAC views are defined in: `/Data_Hub/SAC_Views/SAC TABLES SET -1`
Run `SHOW CREATE TABLE reporting_layer.sac_prod_seafarer_public.<TABLE_NAME>` to get the source DDL.

### To use as an Assistant Skill
Copy this file to your own workspace at: `~/.assistant/skills/sac-smac-migration/SKILL.md`
The assistant will then automatically load it when working on SAC-to-SMAC migration tasks.

---

---

## Migration Process

### Step 1: Get the SAC Source
1. Run `SHOW CREATE TABLE reporting_layer.sac_prod_seafarer_public.<TABLE_NAME>`
2. If it's a TABLE (not VIEW), find the INSERT/CREATE statement in the SAC notebook
3. Extract all source tables, JOIN conditions, and column transformations

### Step 2: Map SAC Tables to SMAC
- Use the table mapping below to identify SMAC equivalents
- Check the playbook for column-level mappings
- Watch for JSON fields that are now flat columns (engine specs, capacity, addresses)

### Step 3: Write the SMAC Query
- Use `CREATE OR REPLACE TABLE` with column mapping TBLPROPERTIES
- Apply all gotchas (contract table, JSON paths, datediff direction, CAST NULL, etc.)
- Filter `WHERE deleted_at IS NULL` on all SMAC source tables

### Step 4: Validate
- Compare row counts (target: 90-110% ratio)
- Find overlapping crew codes and spot-check on composite keys
- Categorize mismatches: UUID/INT (expected), case/format (cosmetic), true differences
- **Before flagging mismatches:** read table-specific validation notes below — several SAC views have known bugs where SMAC is correct

---

## Validation Reference Docs

| Table | Doc | When to read |
|-------|-----|--------------|
| `revised_base_view` | `SMAC Migration/Validation Docs/revised_base_view_validation_notes.md` | **Read first** — expected mismatches, row-count gap, exclusion list |
| `revised_base_view` (columns) | `SMAC Migration/Validation Docs/revised_base_view_column_mapping.md` | Per-column SAC→SMAC source mapping |
| `revised_relief_view` | `SMAC Migration/Validation Docs/revised_relief_view_validation_notes.md` | Relief view or planner relief-side columns |

---

## revised_base_view — Known Acceptable Mismatches (2026-07-17)

**Full detail:** `SMAC Migration/Validation Docs/revised_base_view_validation_notes.md`

When validating `revised_base_view` or downstream `planner_view` (`REVISED_*` columns), **do not treat these as SMAC defects:**

### Row count gap (expected — not a bug)
- SAC **6,838,743** rows vs SMAC **3,190,731** (46.7%) — SMAC has less historical monthly grain + narrower dedup partition
- **Do not fail** on table row-count ratio alone

### SAC source issues (SMAC fixes them)
1. **`EXPERIENCE_IN_DAYS` (onboard):** SAC `datediff(sign_on, current_date)` → negative; SMAC uses correct direction
2. **Contract join v2 (2026-07-17):** Primary `contract_agreements` via `contract_agreement_id`; **fallback** when FK null → `seafarer_contracts` matched by `sign_on_date` + ranked `contract_agreements`. Resolves ~90% NULL FK gap without reverting to wrong table.
3. **`CONTRACT_STATUS`:** SAC passthrough `vessel_contracts.STATUS`; SMAC maps `agreement_status` + `seafarer_contracts.status` to SAC-equivalent labels (`Void`, `InForce`, `Signed`, `Closed`)

### Expected by design (exclude from defect reports)
- All `*_ID` columns: INT → UUID (`SEAFARER_ID`, `SEA_EXPERIENCE_ID`, `RANK_ID`, `CONTRACT_ID`, `VESSEL_ID`, etc.)
- `CDC_NUMBER`: prefix stripped (`IN-MUM…` → `MUM…`)
- `CONTACT_NUMBER`: no country-code prefix in SMAC
- `DATE_OF_BIRTH`: timestamp vs date string
- `STATE` / `COUNTRY` / `NATIONALITY_NAME`: case or master naming (`INDIA`/`India`, `Indonesia`/`Indonesian`)
- `EMERGENCY_CONTACT_NUMBER`: always NULL in SMAC
- `SAC_CONTRACT`: always NULL in SMAC
- `MONTHS`: many SAC monthly slices absent in SMAC (history gap) — downgrade, not auto-fail

### Correct validation join keys
`CREW_CODE` + `SIGN_ON_DATE` + `MONTHS` + `SIGN_OFF_DATE` + `VESSEL_NAME` — **never** compare on ID columns

### Downstream
`planner_view` `REVISED_*` columns inherit these rules. Relief columns (non-`REVISED_`) use `revised_relief_view_validation_notes.md`.

---

## revised_relief_view — Known Acceptable Mismatches (2026-07-17)

**Full detail:** `SMAC Migration/Validation Docs/revised_relief_view_validation_notes.md`

When validating `revised_relief_view` or downstream `planner_view` (relief columns), **do not treat these as SMAC defects:**

### SAC source bugs (SMAC fixes them)
1. **Reliever join bug in SAC:** alias `D` joins `RELIEVING_SEAFARER_ID` instead of `RELIEVER_SEAFARER_ID`. SAC duplicates offsigner into `RELIEVER_*`. SMAC correctly uses `onsigner_id` → D.
2. **L join non-deterministic in SAC:** `PROPOSED_VESSEL_NAME` / `RELIEVER_SIGN_OFF_DATE` may pick wrong historical sea experience. SMAC uses latest onsigner experience (`ROW_NUMBER`).

### Expected by design
- All `*_ID` columns: INT → UUID (validate on `crew_code`, not ID)
- `Relief Profile Link`: new domain + UUID
- `RELIEF_STATE`: playbook maps `travel_planning` → `travelling` when departure signed
- `RELIEVER_SF_STATUS_CODE`, `RELIEVING_SF_STATUS_CODE`, `TRAVEL_REPLAN_STATE`: always NULL in SMAC
- `CDC_NUMBER`: prefix may differ (`IN-MUM…` vs `MUM…`)
- `SHORTLISTED_SEAFARER_*`: SMAC populates from `relief_candidates`; SAC often NULL

### Correct validation join keys
`RELIEVE_CREW_CODE` + `VESSEL_NAME` + `RELIEF_CREATED_AT` (not ID columns)

---

## Schema & Table Mapping

### Crewing Tables
| SAC Table | SMAC Table | SMAC Schema |
|-----------|-----------|-------------|
| `db_sac_prod_seafarer_public.seafarers` | `seafarers` | `curated_db.db_smac_prod_navitasai_crewing_public` |
| `db_sac_prod_seafarer_public.sea_experiences` | `seafarer_sea_experiences` | `curated_db.db_smac_prod_navitasai_crewing_public` |
| `db_sac_prod_seafarer_public.appraisals` | `seafarer_appraisals` + `seafarer_appraisal_forms` | `curated_db.db_smac_prod_navitasai_crewing_public` |
| `db_sac_prod_manning_public.vessel_contracts` | `seafarer_vessel_assignments` | `curated_db.db_smac_prod_navitasai_crewing_public` |
| `db_sac_prod_manning_public.RELIEFS` | `seafarer_reliefs` | `curated_db.db_smac_prod_navitasai_crewing_public` |
| `db_sac_prod_manning_public.SHORTLISTED_SEAFARERS` | `relief_candidates` | `curated_db.db_smac_prod_navitasai_crewing_shore` |
| `db_sac_prod_seafarer_public.SEAFARER_REMARKS` | `seafarer_remarks` | `curated_db.db_smac_prod_navitasai_crewing_shore` |
| *(contract data)* | `contract_agreements` (**NOT** `seafarer_contracts`) | `curated_db.db_smac_prod_navitasai_crewing_public` |

### Master Tables
| SAC Table | SMAC Table | SMAC Schema |
|-----------|-----------|-------------|
| `db_sac_prod_master_public.ranks` | `ranks` | `curated_db.db_smac_prod_navitasai_masters_public` |
| `db_sac_prod_master_public.nationalities` | `nationalities` | `curated_db.db_smac_prod_navitasai_masters_public` |
| `db_sac_prod_master_public.ship_management_companies` | `companies` | `curated_db.db_smac_prod_navitasai_masters_public` |
| `db_sac_prod_seafarer_public.appraisal_types` | `appraisal_types` | `curated_db.db_smac_prod_navitasai_masters_crewing` |
| `db_sac_prod_seafarer_public.SEAFARER_PROFILE_REMARKS` | `profile_remark_reasons` | `curated_db.db_smac_prod_navitasai_masters_crewing` |

### Vessel Tables
| SAC Table | SMAC Table | SMAC Schema |
|-----------|-----------|-------------|
| `db_sac_prod_vessel_public.vessels` | `vessels` | `curated_db.db_smac_prod_navitasai_masters_vessel` |
| `db_sac_prod_vessel_public.vessel_sub_categories` | `sub_categories` | `curated_db.db_smac_prod_navitasai_masters_vessel` |
| `db_sac_prod_vessel_public.VESSEL_CATEGORIES` | `categories` | `curated_db.db_smac_prod_navitasai_masters_vessel` |
| `db_sac_prod_vessel_public.fleets` | `fleets` | `curated_db.db_smac_prod_navitasai_masters_vessel` |
| `db_sac_prod_vessel_public.fleets_vessels` | `fld_fleet_vessels` | `curated_db.db_smac_prod_navitasai_masters_vessel` |

### SMAC-Only Tables (no SAC equivalent)
| Table | Schema | Purpose |
|-------|--------|--------|
| `contract_agreements` | crewing_public | Contract details (448K rows) — CRITICAL: use this NOT seafarer_contracts |
| `appraisal_stages` | masters_crewing | Appraisal feedback stage names |
| `profile_remark_reasons` | masters_crewing | Specific inactive/deactivation reasons |
| `profile_remark_types` | masters_crewing | Remark type categories (DEACTIVATION, ACTIVATION, etc.) |
| `seafarer_profile_statuses` | masters_crewing | ACTIVE/INACTIVE status (2 rows) |
| `relief_states` | masters_crewing | Relief state codes |
| `genders` | masters_public | Gender lookup |

---

## Critical Rules & Gotchas

### 1. Soft Delete & Filtering
- **SMAC (curated_db)**: Pre-filtered by `_fivetran_active = true`
- **All SMAC tables**: Must also filter `WHERE deleted_at IS NULL`
- **SAC**: Used `_fivetran_deleted` pattern (different)

### 2. IDs: Integer → UUID
- SAC: integer IDs | SMAC: UUID strings
- Cross-system validation: JOIN on `crew_code`, never on ID

### 3. Contract Table (CRITICAL — MOST COMMON MISTAKE)
- **WRONG**: Joining only `seafarer_contracts` as primary contract source (109K rows)
- **WRONG**: Relying only on `contract_agreement_id` FK (~90% NULL in curated data)
- **CORRECT (v2 reporting join):**
  1. Primary: `contract_agreements M` ON `M.id = J.contract_agreement_id AND M.deleted_at IS NULL`
  2. Fallback: `seafarer_contracts SC_FB` ON `SC_FB.seafarer_id = B.id AND CAST(SC_FB.start_date AS DATE) = CAST(J.sign_on_date AS DATE) AND J.contract_agreement_id IS NULL`
  3. Fallback agreement: ranked `contract_agreements M_FB` ON `M_FB.contract_id = SC_FB.id` (prefer Signed > Approved)
  4. Dates: `COALESCE(M.*, M_FB.*, SC_FB.*)`; same logic in Y subquery for `LATEST_CONTRACT_END_DATE`
- FK when populated: `seafarer_sea_experiences.contract_agreement_id` → `contract_agreements.id`
- SAC parity: SAC joins `vessel_contracts` via `sea_experiences.CONTRACT_ID`; SMAC fallback via `seafarer_contracts` + agreement approximates that path

### 4. Engine Specifications JSON (PascalCase)
```json
{"DualFuel": false, "OutputPower": "8050", "EngineMakeName": "MAN B&W", "EngineModelName": "5S60ME-C8", "OutputPowerUnit": "kw"}
```
Use: `$.DualFuel`, `$.EngineMakeName`, `$.EngineModelName`, `$.OutputPower`, `$.OutputPowerUnit`

### 5. Cargo Capacity JSON
```sql
CONCAT(COALESCE(get_json_object(cargo_capacity_info, '$.capacity'), ''), ' ', COALESCE(get_json_object(cargo_capacity_info, '$.capacity_unit'), ''))
```

### 6. Experience Calculation
- CORRECT: `datediff(current_date(), CAST(sign_on_date AS DATE))` → positive
- WRONG: `datediff(sign_on_date, current_date())` → negative

### 7. Photon & Column Mapping
- Always `CAST(NULL AS STRING) AS col` (never bare `NULL AS col`)
- Avoid column names ending with underscore
- Always include: `TBLPROPERTIES ('delta.columnMapping.mode' = 'name', 'delta.minReaderVersion' = '2', 'delta.minWriterVersion' = '5')`

### 8. Rank Filtering
- SAC: `RANK_ID IN ('13', '18')` | SMAC: `ranks.name IN ('Master', 'Chief Engineer')`

### 9. Appraisal Feedback Structure
- SAC: JSON array on `appraisals.FEEDBACK`, exploded with LATERAL VIEW
- SMAC: separate rows in `seafarer_appraisal_forms` (joined via `appraisal_id`)
- SAC `templateName` → SMAC `appraisal_stages.name` (via `stage_id`)
- SAC `rating` → SMAC `seafarer_appraisal_forms.average_score`
- **Initiated By** (2026-07-29 fix): resolve via FK, not `audit_info.notes` regex —
  `seafarer_appraisals.initiated_by` → `curated_db.db_smac_prod_navitasai_idp_public.user_profiles.id`
  → `TRIM(CONCAT_WS(' ', first_name, last_name))`. ~79% FK coverage; keep the old regex as a
  `COALESCE` fallback for the unresolved remainder. The regex-only version can return a garbled
  value (SAC's own `CREATED_BY_NAME` for this same field has a similar bug — concatenated
  name+email), while the FK path returns the clean actual name.
- **Appraiser / reviewer name per stage** (2026-07-29 fix): resolve via
  `seafarer_appraisal_forms.assigned_to_user_id`, branching on `stage_type` / `assigned_to_user_type`
  — see the "Appraiser Name from Forms" pattern below. Do **not** join `assigned_to_user_id` directly
  for the Appraisee stage — it's an empty GUID (`00000000-...`) there by design/migration; resolve the
  appraisee's own name instead from the parent appraisal (`seafarer_appraisals.seafarer_id` + `rank_id`
  for a `"(Master)"` style suffix). Keep the old `audit_info.notes` regex as a fallback.
- **FEEDBACK_COMMENTS** (2026-07-29 fix): prefer `seafarer_appraisal_forms.confirmation_data` →
  `$.Remarks` — this is the appraiser's final sign-off comment and is the field SAC's report actually
  reflects (confirmed by an exact-text match against a known-good SAC value). The old approach (regex
  over `submission_data.$.data` for keys containing "remark(s)") only catches section-level remarks
  and covers ~14% of forms; `confirmation_data.Remarks` alone covers ~39%, ~43% combined via
  `COALESCE`. Keep the old regex as the fallback — it's still needed for stages without
  `confirmation_data` (e.g. Appraisee Acknowledgement, whose remark lives at
  `submission_data.$.data.appraiseeRemarks`). Note: SAC's own `FEEDBACK_COMMENTS` has a real bug for
  older/legacy-schema records — its extraction grabs whatever JSON key happens to be *last* in an
  unordered map (`element_at(map_keys(...), -1)`), which for grid/matrix-style form fields surfaces
  garbage like `{"Row 1":{"Column 1":"Item 3"},...}` instead of the actual remark. When SMAC's
  `confirmation_data.Remarks` produces a real sentence and SAC shows that JSON-blob pattern, SMAC is
  correct and SAC is the one with the defect — don't try to reproduce SAC's blob to force a match.
  **2026-07-29 backport:** this fix originally only landed in `add_digital_appraisal_view`;
  `digital_appraisal_view`'s 6 per-stage `*_Comment` columns were still on the old regex-only
  path (spot-checked via crew `UA-000576` — Crewing/Marine Superintendent comments were `NULL` in
  SMAC vs populated in SAC). Backported the same `COALESCE(confirmation_data.Remarks, regex
  fallback)` into all 6 stage comment columns and reran `CREATE OR REPLACE TABLE
  reporting_layer.smac_prod.digital_appraisal_view`. Non-null comment coverage went from ~14% to
  roughly SAC parity (SAC 2,770 rows: Crewing 64%/Marine 57%/Technical 61% non-null; SMAC 2,883 rows
  post-fix: Crewing 56%/Marine 49%/Technical 52% non-null — remaining gap is forms genuinely lacking
  both `confirmation_data` and a `submission_data` remark, not a defect). If re-validating
  `digital_appraisal_view` comment columns and still seeing near-zero non-null rates, the fix may not
  have been applied — check the table's actual `CREATE TABLE` logic, not just the notebook.

### 10. Inactive Seafarer Identification
- SAC: `SEAFARER_REMARKS.profile_remark[0].remark_type = 'INACTIVE'`
- SMAC: `seafarer_remarks` (crewing_shore) with `profile_remark_type_id` = `4bf24d17-381a-429b-83aa-849cbf5279d6`
- Filter currently inactive: `seafarers.profile_status_id = '01993624-9d27-7fa6-8387-ba5a60c6b128'`

### 11. Appraisal Stage Mapping
| SAC templateName | SMAC stage_name |
|---|---|
| Crewing Superintendent Feedback | Crewing Superintendent Feedback |
| Marine Superintendent Feedback | Marine Superintendent Feedback |
| Technical Superintendent Feedback | Technical Superintendent Feedback |
| Appraisee feedback | Appraisee Acknowledgement |
| Marine Manager Feedback | Marine Manager Feedback |
| Technical Manager Feedback | Technical Manager Feedback |

---

## Key Static UUIDs

| Entity | UUID |
|--------|------|
| INACTIVE profile_status | `01993624-9d27-7fa6-8387-ba5a60c6b128` |
| ACTIVE profile_status | `01993624-445a-7d2e-a9fe-1c2731b37803` |
| DEACTIVATION remark_type | `4bf24d17-381a-429b-83aa-849cbf5279d6` |
| ACTIVATION remark_type | `cbc7d23f-ab5d-4224-81e0-22cce334a5cc` |

---

## Common SQL Patterns

### CREATE TABLE Template
```sql
CREATE OR REPLACE TABLE reporting_layer.smac_prod.<table_name>
TBLPROPERTIES (
  'delta.columnMapping.mode' = 'name',
  'delta.minReaderVersion' = '2',
  'delta.minWriterVersion' = '5'
)
AS
SELECT ...
```

### Initiated By (FK resolution, with audit_info regex fallback)
```sql
COALESCE(
  NULLIF(TRIM(CONCAT_WS(' ', IB.first_name, IB.last_name)), ''),
  NULLIF(REGEXP_EXTRACT(get_json_object(ap.audit_info, '$.notes'), 'Created by:\\s*(?:AHOY-)?([^;-]+)', 1), '')
) AS Intiated_by
-- LEFT JOIN curated_db.db_smac_prod_navitasai_idp_public.user_profiles IB ON IB.id = ap.initiated_by
```

### Appraiser Name from Forms (FK resolution, with audit_info regex fallback)
```sql
COALESCE(
  NULLIF(
    CASE
      WHEN UPPER(TRIM(f.stage_type)) = 'APPRAISEE' THEN
        CONCAT(TRIM(CONCAT_WS(' ', SF.first_name, SF.middle_name, SF.last_name)),
               CASE WHEN R.name IS NOT NULL THEN CONCAT(' (', R.name, ')') ELSE '' END)
      WHEN UPPER(TRIM(f.assigned_to_user_type)) = 'SHORE' THEN
        TRIM(CONCAT_WS(' ', UP_ASG.first_name, UP_ASG.last_name))
      ELSE
        TRIM(CONCAT_WS(' ', S_ASG.first_name, S_ASG.middle_name, S_ASG.last_name))
    END,
    ''
  ),
  NULLIF(REGEXP_REPLACE(COALESCE(get_json_object(f.audit_info, '$.notes'), ''), '^Appraiser:\\s*', ''), '')
) AS appraiser_name
-- SF/R = the parent appraisal's seafarer (ap.seafarer_id) / rank (ap.rank_id), already joined for other columns
-- LEFT JOIN ...idp_public.user_profiles UP_ASG ON UP_ASG.id = f.assigned_to_user_id AND UPPER(TRIM(f.assigned_to_user_type))='SHORE' AND UPPER(TRIM(f.stage_type))<>'APPRAISEE'
-- LEFT JOIN ...crewing_public.seafarers S_ASG ON S_ASG.id = f.assigned_to_user_id AND UPPER(TRIM(f.assigned_to_user_type))='SEAFARER' AND UPPER(TRIM(f.stage_type))<>'APPRAISEE'
```

### Feedback Comments Extraction (confirmation_data.Remarks first, $.data regex fallback)
```sql
COALESCE(
  NULLIF(get_json_object(f.confirmation_data, '$.Remarks'), ''),
  NULLIF(array_join(regexp_extract_all(COALESCE(get_json_object(f.submission_data, '$.data'), ''), '"[^"]*[Rr]emarks?"\\s*:\\s*"([^"]+)"', 1), '; '), '')
) AS FEEDBACK_COMMENTS
```

### Performance Rating
```sql
ROUND(AVG(f.average_score), 2) AS performance_rating
-- Filter: f.average_score > 0 AND ap.appraisal_status = 'closed'
```

---

## Completed Migrations

| # | Table | SAC Rows | SMAC Rows | Ratio |
|---|-------|----------|-----------|-------|
| 1 | `revised_base_view` | 6,838,743 | 3,190,731 | 46.7% (SAC has deeper history) |
| 2 | `appraisals_data` | 144,848 | 142,300 | 98.2% |
| 3 | `revised_relief_view` | 20,724 | 20,769 | 100.2% |
| 4 | `planner_view` | 78,177 | 78,604 | 100.5% |
| 5 | `add_digital_appraisal_view` | 26,485 | 30,588 | 115.5% (grows with new appraisals; Initiated By / appraiser name switched to FK resolution 2026-07-29) |
| 6 | `appraisal_performance` | 576 | 547 | 95.0% |
| 7 | `digital_appraisal_view` | 2,637 | 2,788 | 105.7% |
| 8 | `inactive_seafarers` | 10,439 | 13,970 | 133.8% |
