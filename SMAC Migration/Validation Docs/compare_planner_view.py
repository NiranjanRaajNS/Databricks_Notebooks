"""Compare all PLANNER_VIEW columns for one crew code (SAC vs SMAC).

Relief-side columns (no REVISED_ prefix): see revised_relief_view_validation_notes.md
REVISED_* columns: see revised_base_view_validation_notes.md (expected mismatches + exclusion list)
"""
import json
import subprocess
import time
from pathlib import Path

DB = r"C:\Users\niranjan.r\AppData\Local\Microsoft\WinGet\Packages\Databricks.DatabricksCLI_Microsoft.Winget.Source_8wekyb3d8bbwe\databricks.exe"
WH = "265c1d0e2d7c1541"
CREW = "IN-022861"

COLS = [
    "REVISED_FIRST_NAME", "REVISED_MIDDLE_NAME", "REVISED_LAST_NAME", "REVISED_LATEST_DATE",
    "REVISED_CREW_CODE", "REVISED_VESSEL_TYPE", "REVISED_VESSEL_NAME", "REVISED_SEAFARER_ID",
    "REVISED_current_status", "REVISED_RANK_NAME", "REVISED_SIGN_OFF_REASON",
    "REVISED_AVAILABILITY_DATE", "REVISED_SHIP_MANAGEMENT_COMPANY_NAME", "REVISED_GENDER_NAME",
    "REVISED_NATIONALITY_NAME", "REVISED_SIGN_ON_DATE", "REVISED_SIGN_OFF_DATE",
    "REVISED_CONTRACT_END_DATE", "REVISED_LATEST_CONTRACT_END_DATE", "REVISED_LATEST_SIGN_OFF_DATE",
    "Revised Overdue by / Days left", "REVISED_PROFILE_STATUS", "REVISED_CDC_NUMBER",
    "REVISED_BULK_TYPE", "Revised Rank Category", "ROW_NUM1", "CONTRACT_START_DATE",
    "CONTRACT_END_DATE", "CDC_NUMBER", "CREW_CODE", "SIGN_ON_DATE", "SIGN_OFF_DATE",
    "VESSEL_NAME", "VESSEL_CATEGORY_NAME", "PROPOSED_VESSEL_NAME", "RELIEVER_SIGN_OFF_DATE",
    "BULK_TYPE", "RANK_NAME", "DOC/CONTRACT_COMPANY", "Overdue by / Days left", "SEAFARER_ID",
    "NATIONALITY_NAME", "VESSEL_IMO_NUMBER", "VESSEL_CONTRACT_ID", "RELIEVER_SF_STATUS_CODE",
    "RELIEVING_SF_STATUS_CODE", "REASON", "RELIEF_STATE", "RELIEF_CREATED_AT",
    "RELIEVER_TRAVEL_STATE", "FLAG_DOCUMENTATION_STATE", "DOCUMENTATION_STATE",
    "GENERAL_DOCUMENTATION_STATE", "ONSIGNER_RANK_ID", "SIGN_ON_PORT_ID", "TRAVEL_REPLAN_STATE",
    "RELIEVING_TRAVEL_STATE", "RELIEVER_SEAFARER_ID", "RELIEVER_CREW_CODE", "RELIEVER_FIRST_NAME",
    "RELIEVER_MIDDLE_NAME", "RELIEVER_LAST_NAME", "RELIEVE_SEAFARER_ID", "RELIEVE_CREW_CODE",
    "RELIEVE_FIRST_NAME", "RELIEVE_MIDDLE_NAME", "RELIEVE_LAST_NAME", "Relief Profile Link",
    "CATEGORY_STATUS_BY_DAYS", "CONTRACT_TENURE", "MONTHS", "EXPIRY_DATE+1", "EXPIRY_DATE-1",
    "Rank Category", "VESSEL_FLEET_TYPE", "RELIVER_AVAILABILITY_DATE",
    "SHORTLISTED_SEAFARER_FIRST_NAME", "SHORTLISTED_SEAFARER_MIDDLE_NAME",
    "SHORTLISTED_SEAFARER_LAST_NAME", "POD_NAME", "POD_VESSEL_NAME", "RELIEVER_GENDER_NAME",
    "RELIEVE_GENDER_NAME", "DELAYED_MONTHS", "COMBINED_VESSEL_NAME",
    "COMBINED_VESSEL_CATEGORY_NAME", "COMBINED_CDC_NUMBER", "COMBINED_BULK_TYPE",
]


def q(name: str) -> str:
    return f"`{name}`" if any(ch in name for ch in (" ", "/", "+", "-")) else name


def run_sql(sql: str) -> list[list]:
    payload = {"statement": sql, "warehouse_id": WH, "wait_timeout": "50s"}
    tmp = Path(__file__).parent / "_planner_cmp_payload.json"
    tmp.write_text(json.dumps(payload), encoding="utf-8")
    r = subprocess.run(
        [DB, "api", "post", "/api/2.0/sql/statements", f"--json=@{tmp}", "-o", "json"],
        capture_output=True,
        text=True,
        check=True,
    )
    d = json.loads(r.stdout)
    st = d["status"]["state"]
    sid = d["statement_id"]
    for _ in range(120):
        if st in ("SUCCEEDED", "FAILED", "CANCELED"):
            break
        time.sleep(3)
        d = json.loads(
            subprocess.run(
                [DB, "api", "get", f"/api/2.0/sql/statements/{sid}", "-o", "json"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout
        )
        st = d["status"]["state"]
    if st != "SUCCEEDED":
        raise RuntimeError(json.dumps(d.get("status", {}), indent=2))
    return d["result"]["data_array"]


def main():
    unions = []
    for col in COLS:
        esc = col.replace("'", "''")
        c = q(col)
        unions.append(
            f"SELECT '{esc}' AS column_name, "
            f"CAST(s.{c} AS STRING) AS sac_value, "
            f"CAST(m.{c} AS STRING) AS smac_value, "
            f"CASE WHEN COALESCE(CAST(s.{c} AS STRING),'') = "
            f"COALESCE(CAST(m.{c} AS STRING),'') THEN 'MATCH' ELSE 'MISMATCH' END AS status "
            f"FROM reporting_layer.sac_prod_seafarer_public.PLANNER_VIEW s "
            f"INNER JOIN reporting_layer.smac_prod.planner_view m "
            f"ON s.REVISED_CREW_CODE = m.REVISED_CREW_CODE "
            f"WHERE s.REVISED_CREW_CODE = '{CREW}'"
        )
    sql = (
        "SELECT column_name, sac_value, smac_value, status FROM (\n"
        + "\nUNION ALL\n".join(unions)
        + "\n) ORDER BY status DESC, column_name"
    )
    rows = run_sql(sql)
    match = [r for r in rows if r[3] == "MATCH"]
    mis = [r for r in rows if r[3] == "MISMATCH"]
    print(f"Filter: REVISED_CREW_CODE={CREW}")
    print(f"Columns compared: {len(rows)} | MATCH: {len(match)} | MISMATCH: {len(mis)}")
    print("\n=== MISMATCHES ===")
    for r in mis:
        print(f"{r[0]} | SAC: {r[1]} | SMAC: {r[2]}")
    out = Path(__file__).parent / "planner_view_compare_IN_022861.json"
    out.write_text(
        json.dumps(
            {"crew": CREW, "match_count": len(match), "mismatch_count": len(mis),
             "matches": match, "mismatches": mis},
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"\nWrote {out}")


if __name__ == "__main__":
    main()
