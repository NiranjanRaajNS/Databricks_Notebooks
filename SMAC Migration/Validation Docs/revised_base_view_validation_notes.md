# revised_base_view — SAC vs SMAC Validation Notes

**Purpose:** Document known acceptable mismatches when comparing `reporting_layer.sac_prod_seafarer_public.revised_base_view` to `reporting_layer.smac_prod.revised_base_view`. Use this when validating this table directly **or downstream tables that inherit base columns** (e.g. `planner_view` `REVISED_*` columns).

**Validated:** 2026-07-17 (contract join v2 deployed) · Spot-check crews `ID-000379`, `IN-277727` · Full column compare via `gen_full_col_compare_sql.py` / `run_full_col_compare.py` / `compare_filtered_record.py`

**Related docs:**
- Column mapping (all 119 columns): `revised_base_view_column_mapping.md` / `.xlsx`
- Mismatch export: `revised_base_view_mismatch_side_by_side.csv`
- Column-level stats: `full_col_compare_results.json`
- Contract diagnostics: `diagnose_contract_join.sql`

**Source notebooks:**
- SAC: `SMAC Migration/Notebooks/(Clone) SAC TABLES SET -1.ipynb`
- SMAC: `SMAC Migration/Notebooks/(Clone) SMAC Reporting Layer Migration SET 1.ipynb`

---

## Row count — the actual gap (expected, not a defect)

| System | Rows | Ratio |
|--------|------|-------|
| SAC | 6,838,743 | 100% |
| SMAC | 3,190,731 | **46.7%** |

**Why SMAC has ~53% fewer rows (documented, acceptable):**

1. **Monthly grain (`GEN_MONTH`)** — Both expand each sea experience into one row per calendar month between sign-on and sign-off. SMAC curated data has **less historical depth** than SAC landing zone, so older experiences produce fewer monthly slices.
2. **Dedup CTE difference** — SAC `ROW_NUMBER` partitions on ~70 columns; SMAC on ~22 key columns. SMAC may collapse duplicates SAC kept as separate rows.
3. **Contact filter in SAC** — SAC filters `WHERE NEW_CONTACT_TYPE = '1'` (permanent address only). SMAC hardcodes permanent address; equivalent intent but row multiplication from `contact_details` differs.

**Do not fail migration on row-count ratio alone for this table.** For overlapping crew/experience keys, compare column values — not total table counts.

---

## Correct join keys for validation

**Do not** compare on ID columns (`SEAFARER_ID`, `SEA_EXPERIENCE_ID`, `RANK_ID`, `CONTRACT_ID`, `VESSEL_ID`, `VERIFIED_BY_ID`, `POSITION_RANK_ID`, `USER_ID`).

**Use composite keys (same as validation scripts):**

```sql
ON s.CREW_CODE = m.CREW_CODE
AND s.SIGN_ON_DATE = m.SIGN_ON_DATE
AND s.MONTHS = m.MONTHS
AND COALESCE(CAST(s.SIGN_OFF_DATE AS DATE), DATE'1900-01-01')
  = COALESCE(CAST(m.SIGN_OFF_DATE AS DATE), DATE'1900-01-01')
AND COALESCE(s.VESSEL_NAME, '') = COALESCE(m.VESSEL_NAME, '')
```

**Note:** `MONTHS` may not align 1:1 for every SAC row (see row-count gap). When `MONTHS` mismatches on an otherwise matching experience, treat as **expected grain gap**, not SMAC logic error.

---

## SAC source issues (SMAC fixes — do NOT treat as SMAC defects)

### 1. Onboard experience days (datediff direction)

SAC (wrong for onboard):
```sql
datediff(CAST(J.FROM_DATE AS DATE), current_date())  -- negative values
```

SMAC (correct):
```sql
datediff(current_date(), CAST(J.sign_on_date AS DATE))  -- positive values
```

**Columns affected when `ONBOARD_SAILING_STATUS = 'Onboard'`:**
- `EXPERIENCE_IN_DAYS`
- `EXPERIENCE_IN_MONTHS`
- `EXPERIENCE_IN_MONTHS_ROUNDOFF`
- `EXPERIENCE_IN_YEAR`

**Action:** Ignore SAC parity for onboard experience columns — SMAC is correct.

### 2. Contract join v2 (resolved 2026-07-17)

**Root cause:** ~89.65% of `seafarer_sea_experiences` rows have **NULL `contract_agreement_id`**. SAC reporting joins `sea_experiences.CONTRACT_ID` → `vessel_contracts`; SMAC v1 only joined `contract_agreement_id` → `contract_agreements`, leaving dates NULL.

**SMAC v2 join strategy (notebook deployed):**

1. **Primary:** `contract_agreements M` ON `M.id = J.contract_agreement_id AND M.deleted_at IS NULL`
2. **Fallback (when FK null):** `seafarer_contracts SC_FB` ON `seafarer_id` + **same `sign_on_date`**
3. **Fallback agreement:** ranked `contract_agreements M_FB` ON `SC_FB.id` (prefer `Signed` > `Approved`)
4. **Output COALESCE:** dates from `M`, then `M_FB`, then `SC_FB`; `CONTRACT_ID` = `COALESCE(J.contract_agreement_id, M_FB.id)`
5. **Y subquery:** same fallback path for `LATEST_CONTRACT_END_DATE`
6. **Appraisal window:** uses resolved contract end in `COALESCE(J.sign_off_date, M.end_date, M_FB.end_date, SC_FB.end_date)`

**Post-fix match rates (87 joined rows, `ID-000379` + `IN-277727`):**

| Column | Match rate | Notes |
|--------|------------|-------|
| `CONTRACT_START_DATE`, `CONTRACT_END_DATE`, `CONTRACT_STATUS` | **100%** | Fixed |
| `LATEST_CONTRACT_END_DATE`, `TENTITIVE_SIGN_OFF_DATE`, `Overdue by / Days left` | **100%** | Fixed |
| `FROM_DATE`, `TO_DATE`, `STATUS` (appraisal) | **81.61%** | Improved from ~18% |
| `CONTRACT_ID` | **54%** | Expected — SAC int / `0` vs SMAC UUID; exclude from defect count |

**Curated migration flag (out of notebook scope):** systematic backfill of `contract_agreement_id` on `seafarer_sea_experiences` would reduce reliance on fallback joins.

### 3. `CONTRACT_STATUS` mapping (SAC label parity)

SMAC v2 maps to SAC-equivalent strings where possible:

- `Void` / `Cancelled` / `Terminated` → `Void`
- `seafarer_contracts.status = 'Inactive'` → `Closed`
- Signed + onboard → `InForce`; end date past → `Closed`
- `agreement_status = 'Signed'` → `Signed`

**Action:** After v2 deploy, `CONTRACT_STATUS` matches SAC on sample crews — **do not auto-fail**. Residual differences on other crews may need business review.

---

## Expected mismatches (not bugs — migration design)

| Column(s) | SAC | SMAC | Category | Action on validate |
|-----------|-----|------|----------|-------------------|
| `SEAFARER_ID`, `SEA_EXPERIENCE_ID`, `RANK_ID`, `CONTRACT_ID`, `VESSEL_ID`, `VERIFIED_BY_ID`, `POSITION_RANK_ID` | INTEGER | UUID | ID type change | **Ignore** — join on `CREW_CODE` + experience keys |
| `USER_ID` | `B.UUID` | `B.id` (UUID) | Same role, different column | **Ignore** if links work |
| `CDC_NUMBER` | prefix e.g. `IN-MUM102127R`, `ID-G137100` | raw e.g. `MUM102127R`, `G137100` | Format / prefix | **Ignore** (cosmetic) |
| `CONTACT_NUMBER` | `CONCAT(country_code, phone)` e.g. `+62821…` | `B.phone` e.g. `821…` | No country code in SMAC | **Ignore** (format) |
| `DATE_OF_BIRTH` | timestamp `1995-07-05 00:00:00` | date `1995-07-05` | Type/format | **Ignore** (same date) |
| `STATE` | e.g. `Daman and Diu` | e.g. `Daman And Diu` | Title case from master | **Ignore** (cosmetic) |
| `COUNTRY` | e.g. `INDIA` | e.g. `India` | Case / master naming | **Ignore** (cosmetic) |
| `NATIONALITY_NAME` | e.g. `Indonesia` | e.g. `Indonesian` | Master adjective vs noun | **Ignore** (master data convention) |
| `EMERGENCY_CONTACT_NUMBER` / `EMERGENCY_CONTACT_NUMBER_` | from `contact_details` LEAD window | always NULL | No SMAC source | **Ignore** |
| `SAC_CONTRACT` | boolean on sea experience | always NULL | SAC-specific flag | **Ignore** |
| `ADDRESS_TYPE`, `NEW_CONTACT_TYPE` | dynamic from contact type | hardcoded permanent / `'1'` | Contact model change | **Ignore** |
| `SYNERGY_COMPANY` | string `'TRUE'`/`'FALSE'` | boolean (cast in C2) | Type change | **Ignore** if semantics match |
| Profile links (`APPRAISAL_LINK`, etc.) | URL + UUID | URL + UUID | Same pattern | Should match when joined correctly |
| `MONTHS` | full historical monthly grid | fewer months for old experiences | Row-count / history gap | **Downgrade** — not auto-fail |

---

## Observed match rates (sample: `ID-000379`, `IN-277727`, 87 joined rows)

From `full_col_compare_results.json` — joined on composite keys above (**after contract join v2**):

| Match rate | Columns | Notes |
|------------|---------|-------|
| **100%** | **86 columns** | Includes all contract date/status cols, `CREW_CODE`, names, ranks, vessel name/IMO, C2/classification, `Overdue by / Days left` |
| **81–90%** | `FROM_DATE`/`TO_DATE`/`STATUS`, `POD_*`, some company fields | Appraisal window / master data — not contract FK gap |
| **45–72%** | `STATE`, `COUNTRY`, `CURRENT_STATUS`, `NEAREST_AIRPORT`, company IDs/names | Master data / contact model / profile_state naming |
| **54%** | `CONTRACT_ID` | UUID vs SAC int — expected; exclude from defect count |
| **0% (expected)** | `SEAFARER_ID`, `SEA_EXPERIENCE_ID`, `RANK_ID`, `VESSEL_ID`, `VERIFIED_BY_ID`, `POSITION_RANK_ID`, `CDC_NUMBER`, `CONTACT_NUMBER`, `DATE_OF_BIRTH` (format), `SAC_CONTRACT` | ID/type/format — exclude from defect count |
| **4.6%** | `MONTHS` | Grain gap — many SAC monthly rows have no SMAC counterpart |

---

## Review separately (may differ — not auto-fail)

| Column | Notes |
|--------|-------|
| `CURRENT_STATUS` | SAC maps `B.STATE` (`sign_off` → `Sign Off`). SMAC uses `profile_states.name` (`Available`, etc.). Verify enum mapping with business — not necessarily 1:1 string match. |
| `NEAREST_AIRPORT` | SAC: text on `contact_details`. SMAC: `airports.name` via `primary_address.airportId`. Different source → different airport when profile address updated. |
| `SHIP_MANAGEMENT_COMPANY_NAME` | SAC JSON/name match vs SMAC `doc_holder_company_id` FK. Watch `Other` vs `Others`, trailing spaces, master spelling (e.g. Pertamina). |
| `SHIP_MANAGEMENT_COMPANY_ID` | INT vs UUID + different company resolution path. |
| `VESSEL_CODE` | SAC: `vessel_details`. SMAC: latest `vessel_revisions`. May differ when revision history changed. |
| `VESSEL_SUB_CATEGORY` | SAC via `vessel_details`; SMAC direct on sea experience FK. |
| `CAPACITY`, `GRT`, `OUTPUT_POWER`, `DUAL_FUEL`, `MAKE_NAME`, `MODEL_NAME` | JSON path case change (`engine_specification` vs `EngineMakeName`). NULL in one system when legacy JSON empty. |
| `COMPANY_STATUS`, `SYNERGY_JOINING_DATE`, `FIRST_COMPANY`, `LATEST_COMPANY` | C2 windows — sensitive to `STATUS` code (`SIGN_ON` vs `SIGNON`) and `DOC_COMPANY` source (`ship_management_companies.DOC_COMPANY` vs `company_services`). |
| `Last DOC/Contract Company` | SAC `CURRENT_COMPANY_ID` → ship_management_companies; SMAC `present_doc_company_id` → companies. |

---

## Columns that should match (high confidence)

When joined on composite keys and `MONTHS` aligns, these should match (verified ~100% on sample crews):

- Identity: `CREW_CODE`, `FIRST_NAME`, `MIDDLE_NAME`, `LAST_NAME`, `SEAFARER_NAME`, `OLD_CREW_CODE`
- Status: `SEAFARER_TYPE`, `PROFILE_STATUS`, `ONBOARD_SAILING_STATUS`, `AHOY_STATUS`
- Rank/vessel: `CURRENT_RANK_NAME`, `RANK_NAME_SE`, `VESSEL_NAME`, `IMO_NUMBER`, `VESSEL_CATEGORY_NAME`
- Experience dates: `SIGN_ON_DATE`, `SIGN_OFF_DATE`, `IS_SYNERGY_EXPERIANCE`, `IS_VERIFIED`, `VERIFIED_ON`
- Contract (v2): `CONTRACT_START_DATE`, `CONTRACT_END_DATE`, `CONTRACT_STATUS`, `LATEST_CONTRACT_END_DATE`, `TENTITIVE_SIGN_OFF_DATE`, `Overdue by / Days left`
- Ports: `FROM_PORT_NAME`, `TO_PORT_NAME`
- Classifications: `VESSEL_FLEET_TYPE`, `RANK_LEVEL`, `Rank Category`
- C2 (when keys align): `COMPANY_STATUS`, `SYNERGY_JOINING_DATE`, `FIRST_RANK`, `SECOND_LATEST_RANK`, `LATEST_COMPANY`
- Remarks: `REMARK`, `REMARK_TYPE`, `INACTIVE_TYPE`, `DATE_OF_TERMINATION`
- Links: `APPRAISAL_LINK`, `DOCUMENTS_LINK`, `SEA_EXPERIENCE_LINK`, `SEAFARER_PROFILE_LINK`
- Address (when same profile): `PRIMARY_ADDRESS`, `CITY`, `PIN_CODE`, `EMAIL_ID`

---

## Downstream impact: `planner_view`

`planner_view` LEFT JOINs `revised_base_view` on:

```sql
B.RELIEVE_SEAFARER_ID = A.REVISED_SEAFARER_ID   -- planner uses seafarer id from relief side
```

Planner columns prefixed `REVISED_*` inherit **all rules in this document**. When running `compare_planner_view.py`:

1. **Exclude or downgrade** columns in the quick exclusion list below for `REVISED_*` fields.
2. **Do not** fail because `REVISED_SEAFARER_ID` or `REVISED_CONTRACT_ID` differ (INT vs UUID).
3. Relief-side columns (non-`REVISED_`) follow `revised_relief_view_validation_notes.md`.

---

## Validation scripts

| Script | Purpose |
|--------|---------|
| `gen_full_col_compare_sql.py` | Generate batch compare SQL (`full_col_compare.sql`) |
| `run_full_col_compare.py` | Execute compare SQL → `full_col_compare_results.json` |
| `compare_filtered_record.py` | Single-record column compare (`CREW_CODE` + `SIGN_ON_DATE` + `MONTHS`) |
| `export_mismatch_side_by_side.py` | Export mismatch detail CSV/XLSX |
| `compare_planner_view.py` | Planner compare — apply this doc for `REVISED_*` columns |

---

## Quick exclusion list for automated mismatch reports

Treat as **EXPECTED**, not SMAC defects:

```
SEAFARER_ID
SEA_EXPERIENCE_ID
RANK_ID
CONTRACT_ID
VESSEL_ID
VERIFIED_BY_ID
POSITION_RANK_ID
USER_ID
CDC_NUMBER
CONTACT_NUMBER
DATE_OF_BIRTH
EMERGENCY_CONTACT_NUMBER
EMERGENCY_CONTACT_NUMBER_
SAC_CONTRACT
STATE
COUNTRY
NATIONALITY_NAME
ADDRESS_TYPE
NEW_CONTACT_TYPE
SYNERGY_COMPANY
MONTHS
EXPERIENCE_IN_DAYS
EXPERIENCE_IN_MONTHS
EXPERIENCE_IN_MONTHS_ROUNDOFF
EXPERIENCE_IN_YEAR
```

Add `EXPERIENCE_*` exclusions **only when** `ONBOARD_SAILING_STATUS = 'Onboard'`.

**Removed from exclusion list (fixed by contract join v2):** `CONTRACT_START_DATE`, `CONTRACT_END_DATE`, `CONTRACT_STATUS`, `LATEST_CONTRACT_END_DATE`, `TENTITIVE_SIGN_OFF_DATE`, `Overdue by / Days left`.
