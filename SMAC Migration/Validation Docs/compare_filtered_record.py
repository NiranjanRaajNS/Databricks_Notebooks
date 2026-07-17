"""Compare all columns for one filtered revised_base_view record.

See revised_base_view_validation_notes.md for columns expected to mismatch vs SAC
(ID columns, CDC prefix, contact format, CONTRACT_STATUS derivation, MONTHS grain gap, etc.).
"""
import json
import subprocess
import sys
import time
from pathlib import Path

from gen_full_col_compare_sql import COLS, SAC_COL_MAP, q

DB = r"C:\Users\niranjan.r\AppData\Local\Microsoft\WinGet\Packages\Databricks.DatabricksCLI_Microsoft.Winget.Source_8wekyb3d8bbwe\databricks.exe"
WH = "265c1d0e2d7c1541"
CREW = "IN-277727"
SIGN_ON = "TIMESTAMP '2024-04-18 00:00:00'"
MONTHS = "DATE '2024-07-01'"


def run_sql(sql: str) -> list[list]:
    payload = {"statement": sql, "warehouse_id": WH, "wait_timeout": "50s"}
    tmp = Path(__file__).parent / "_filter_cmp_payload.json"
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
        sac_col = SAC_COL_MAP.get(col, col)
        esc = col.replace("'", "''")
        unions.append(
            f"SELECT '{esc}' AS column_name, "
            f"CAST(s.{q(sac_col)} AS STRING) AS sac_value, "
            f"CAST(m.{q(col)} AS STRING) AS smac_value, "
            f"CASE WHEN COALESCE(CAST(s.{q(sac_col)} AS STRING),'') = "
            f"COALESCE(CAST(m.{q(col)} AS STRING),'') THEN 'MATCH' ELSE 'MISMATCH' END AS status "
            f"FROM reporting_layer.sac_prod_seafarer_public.revised_base_view s "
            f"INNER JOIN reporting_layer.smac_prod.revised_base_view m "
            f"ON s.CREW_CODE = m.CREW_CODE AND s.SIGN_ON_DATE = m.SIGN_ON_DATE AND s.MONTHS = m.MONTHS "
            f"AND COALESCE(CAST(s.SIGN_OFF_DATE AS DATE), DATE'1900-01-01') = "
            f"COALESCE(CAST(m.SIGN_OFF_DATE AS DATE), DATE'1900-01-01') "
            f"AND COALESCE(s.VESSEL_NAME,'') = COALESCE(m.VESSEL_NAME,'') "
            f"WHERE s.CREW_CODE = '{CREW}' AND s.SIGN_ON_DATE = {SIGN_ON} AND s.MONTHS = {MONTHS}"
        )
    sql = (
        "SELECT column_name, sac_value, smac_value, status FROM (\n"
        + "\nUNION ALL\n".join(unions)
        + "\n) ORDER BY status DESC, column_name"
    )
    rows = run_sql(sql)
    match = [r for r in rows if r[3] == "MATCH"]
    mis = [r for r in rows if r[3] == "MISMATCH"]
    print(f"Filter: CREW_CODE={CREW}, SIGN_ON_DATE=2024-04-18, MONTHS=2024-07-01")
    print(f"Columns compared: {len(rows)} | MATCH: {len(match)} | MISMATCH: {len(mis)}")
    print("\n=== MISMATCHES ===")
    for r in mis:
        print(f"{r[0]} | SAC: {r[1]} | SMAC: {r[2]}")
    print("\n=== MATCHES ===")
    for r in match:
        print(f"{r[0]} | {r[1]}")


if __name__ == "__main__":
    main()
