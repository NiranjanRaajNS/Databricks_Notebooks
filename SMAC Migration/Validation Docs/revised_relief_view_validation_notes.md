# revised_relief_view — SAC vs SMAC Validation Notes

**Purpose:** Document known acceptable mismatches when comparing `reporting_layer.sac_prod_seafarer_public.revised_relief_view` to `reporting_layer.smac_prod.revised_relief_view`. Use this when validating this table directly **or downstream tables that inherit relief columns** (e.g. `planner_view`).

**Validated:** 2026-07-17 · Spot-check crew `IN-001293` · Full column compare via `compare_relief_crew.py`

**Source notebooks:**
- SAC: `SMAC Migration/Notebooks/(Clone) SAC TABLES SET -1.ipynb` — `REVISED_RELIEF_VIEW`
- SMAC: `SMAC Migration/Notebooks/(Clone) SMAC Reporting Layer Migration SET 1.ipynb` — `revised_relief_view`

---

## Row count (expected)

| System | Rows | Notes |
|--------|------|-------|
| SAC | 20,724 | |
| SMAC | 20,769 | 100.2% — acceptable per migration playbook |

---

## Correct join keys for validation

**Do not** compare on ID columns (`SEAFARER_ID`, `RELIEVER_SEAFARER_ID`, `VESSEL_CONTRACT_ID`).

**Use composite keys:**
- `RELIEVE_CREW_CODE` (offsigner — person being relieved)
- `VESSEL_NAME`
- `RELIEF_CREATED_AT` (or `CONTRACT_START_DATE` + `CONTRACT_END_DATE`)

`CREW_CODE` = offsigner crew code in **both** systems (same semantic). Filtering `WHERE CREW_CODE = 'X'` is valid but relief-side `RELIEVER_*` columns will differ from SAC when SAC has the join bug below.

---

## SAC source bugs (SMAC is correct — do NOT treat as SMAC defects)

### 1. Reliever seafarer join (critical)

SAC joins **both** alias `D` (reliever) and `E` (offsigner) to `C.RELIEVING_SEAFARER_ID`:

```sql
-- SAC (WRONG)
LEFT JOIN SEAFARERS D ON D.ID = C.RELIEVING_SEAFARER_ID   -- should be RELIEVER_SEAFARER_ID
LEFT JOIN SEAFARERS E ON E.ID = C.RELIEVING_SEAFARER_ID   -- correct
```

SMAC (correct):

```sql
LEFT JOIN seafarers D ON D.id = C.onsigner_id    -- reliever
LEFT JOIN seafarers E ON E.id = C.offsigner_id   -- offsigner
```

**Effect:** SAC duplicates offsigner data into all `RELIEVER_*` columns. SMAC shows the actual onsigner from `seafarer_reliefs.onsigner_id`.

**Columns affected (exclude from SAC parity checks or expect mismatch):**
- `RELIEVER_SEAFARER_ID`
- `RELIEVER_CREW_CODE`
- `RELIEVER_FIRST_NAME`
- `RELIEVER_MIDDLE_NAME`
- `RELIEVER_LAST_NAME`
- `RELIEVER_GENDER_NAME`
- `RELIVER_AVAILABILITY_DATE` (SAC reads offsigner availability via wrong D join)

**Example (`IN-001293`):** Source `RELIEFS` has reliever `IN-010592` / KARTHIKEYAN; SAC view shows `IN-001293` / IRUTHAYARAJ; SMAC correctly shows `IN-010592` / KARTHIKEYAN.

### 2. Reliever sea experience L join (non-deterministic)

SAC: `L` joins `L.SEAFARER_ID = C.RELIEVER_SEAFARER_ID` with **no** `ORDER BY` / dedup.

SMAC: `L` = latest sea experience per onsigner (`ROW_NUMBER() ... ORDER BY sign_on_date DESC`).

**Effect:** SAC can pick an arbitrary historical vessel for `PROPOSED_VESSEL_NAME` and `RELIEVER_SIGN_OFF_DATE`.

**Columns affected:**
- `PROPOSED_VESSEL_NAME` — SMAC uses latest reliever experience (correct)
- `RELIEVER_SIGN_OFF_DATE` — SMAC NULL when latest experience has no sign-off (correct)

**Example (`IN-001293`):** Latest reliever experience = `DEIRA GHAIR` (both systems in source). SAC view shows `HAFNIA LUPUS`; SMAC shows `DEIRA GHAIR`.

---

## Expected mismatches (not bugs — migration design)

| Column(s) | SAC | SMAC | Category | Action on validate |
|-----------|-----|------|----------|-------------------|
| `SEAFARER_ID`, `RELIEVER_SEAFARER_ID`, `RELIEVE_SEAFARER_ID`, `VESSEL_CONTRACT_ID`, `ONSIGNER_RANK_ID`, `SIGN_ON_PORT_ID` | INTEGER | UUID | ID type change | **Ignore** — join on `crew_code` |
| `Relief Profile Link` | `manning.synergymarine.in/relief/detail/{int}` | `crewing.synergymarine.in/crewing/manning/relief/detail/{uuid}` | URL + domain change | **Ignore** |
| `RELIEF_STATE` | e.g. `travel_planning` | e.g. `travelling` | Playbook rule: `TRAVEL_PLANNING` + signed departure → `TRAVELLING` in `seafarer_reliefs` migration | **Ignore** if SMAC state follows playbook |
| `RELIEVER_SF_STATUS_CODE`, `RELIEVING_SF_STATUS_CODE`, `TRAVEL_REPLAN_STATE` | sparse values | always NULL | No SMAC equivalent (documented) | **Ignore** |
| `CDC_NUMBER` | may include prefix e.g. `IN-MUM273949` | raw e.g. `MUM273949` | Format / prefix | **Ignore** (cosmetic) |
| `SHORTLISTED_SEAFARER_*` | often NULL (no dedup on K join) | populated from `relief_candidates` | SMAC improvement | **Ignore** if SMAC has candidate data |
| `REASON` | from `RELIEFS.REASON` | `COALESCE(seafarer_reliefs.remarks, '')` | Source column rename | Compare semantics, not exact legacy column |

---

## Review separately (may differ — not auto-fail)

| Column | Notes |
|--------|-------|
| `DOC/CONTRACT_COMPANY` | SAC: `E.CURRENT_COMPANY_ID` (ship mgmt). SMAC: `A.doc_holder_company_id` (DOC holder from sea experience). Intentional source change — confirm with business if values differ. |
| `POD_NAME` | Same fleet/IMO join pattern; fleet assignment may differ in master data. |
| `SIGN_ON_PORT_ID` | SMAC `joining_place_id` may be NULL if joining-place lookup failed during `seafarer_reliefs` migration. |

---

## Columns that should match (high confidence)

When joined on `RELIEVE_CREW_CODE` + `VESSEL_NAME` + relief timestamp, these should align:

- `CREW_CODE`, `RELIEVE_*` (offsigner identity)
- `CONTRACT_START_DATE`, `CONTRACT_END_DATE`
- `SIGN_ON_DATE`, `SIGN_OFF_DATE`, `VESSEL_NAME`, `VESSEL_CATEGORY_NAME`, `VESSEL_IMO_NUMBER`
- `RANK_NAME`, `BULK_TYPE`, `NATIONALITY_NAME`
- `RELIEVER_TRAVEL_STATE`, `RELIEVING_TRAVEL_STATE`
- `FLAG_DOCUMENTATION_STATE`, `DOCUMENTATION_STATE`, `GENERAL_DOCUMENTATION_STATE`
- `CATEGORY_STATUS_BY_DAYS`, `CONTRACT_TENURE`, `MONTHS`, `EXPIRY_DATE+1`, `EXPIRY_DATE-1`
- `Rank Category`, `VESSEL_FLEET_TYPE`, `POD_VESSEL_NAME`
- `RELIEVE_GENDER_NAME`

---

## Downstream impact: `planner_view`

`planner_view` LEFT JOINs `revised_relief_view` on:

```sql
B.RELIEVE_SEAFARER_ID = A.REVISED_SEAFARER_ID
```

Relief columns prefixed without `REVISED_` in planner output inherit the same mismatch rules above. When running `compare_planner_view.py` or similar:

1. **Exclude or downgrade** relief-side columns listed under SAC bugs and expected mismatches.
2. **Do not** fail validation because `RELIEVER_CREW_CODE` / `RELIEVER_FIRST_NAME` differ from SAC — SMAC is correct.
3. Planner `REVISED_*` columns come from `revised_base_view`; use `revised_base_view_validation_notes.md` (exclusion list) and `revised_base_view_column_mapping.md` (column sources).

---

## Entity mapping reference (SMAC migration)

| Role | SAC `RELIEFS` column | SMAC `seafarer_reliefs` | View alias |
|------|----------------------|-------------------------|------------|
| Offsigner (relieved) | `RELIEVING_SEAFARER_ID` | `offsigner_id` | E → `CREW_CODE`, `RELIEVE_*` |
| Onsigner (reliever) | `RELIEVER_SEAFARER_ID` | `onsigner_id` | D → `RELIEVER_*` |
| Contract | `VESSEL_CONTRACTS` | `seafarer_vessel_assignments` (offsigner) | SVA |
| Shortlist | `SHORTLISTED_SEAFARERS` | `relief_candidates` | K → Z |

---

## Validation scripts

| Script | Purpose |
|--------|---------|
| `compare_relief_crew.py` | Full column compare for one `CREW_CODE` |
| `compare_planner_view.py` | Planner compare — apply exclusion rules from this doc for relief columns |

---

## Quick exclusion list for automated mismatch reports

Use when flagging columns — treat as **EXPECTED**, not defects:

```
RELIEVER_SEAFARER_ID
RELIEVER_CREW_CODE
RELIEVER_FIRST_NAME
RELIEVER_MIDDLE_NAME
RELIEVER_LAST_NAME
RELIEVER_GENDER_NAME
RELIVER_AVAILABILITY_DATE
PROPOSED_VESSEL_NAME
RELIEVER_SIGN_OFF_DATE
SEAFARER_ID
RELIEVE_SEAFARER_ID
VESSEL_CONTRACT_ID
ONSIGNER_RANK_ID
SIGN_ON_PORT_ID
Relief Profile Link
RELIEF_STATE
RELIEVER_SF_STATUS_CODE
RELIEVING_SF_STATUS_CODE
TRAVEL_REPLAN_STATE
CDC_NUMBER
SHORTLISTED_SEAFARER_FIRST_NAME
SHORTLISTED_SEAFARER_MIDDLE_NAME
SHORTLISTED_SEAFARER_LAST_NAME
```
