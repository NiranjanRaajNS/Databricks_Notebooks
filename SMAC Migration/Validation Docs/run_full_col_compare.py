"""Execute full_col_compare.sql and write full_col_compare_results.json."""
import json
import subprocess
import time
from pathlib import Path

DB = r"C:\Users\niranjan.r\AppData\Local\Microsoft\WinGet\Packages\Databricks.DatabricksCLI_Microsoft.Winget.Source_8wekyb3d8bbwe\databricks.exe"
WH = "265c1d0e2d7c1541"
ROOT = Path(__file__).parent


def run_sql(sql: str) -> list[list]:
    payload = {"statement": sql, "warehouse_id": WH, "wait_timeout": "50s"}
    tmp = ROOT / "_full_cmp_payload.json"
    tmp.write_text(json.dumps(payload), encoding="utf-8")
    r = subprocess.run(
        [DB, "api", "post", "/api/2.0/sql/statements", f"--json=@{tmp}", "-o", "json"],
        capture_output=True,
        text=True,
        check=True,
    )
    d = json.loads(r.stdout)
    sid = d["statement_id"]
    st = d["status"]["state"]
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
    sql = (ROOT / "full_col_compare.sql").read_text(encoding="utf-8")
    rows = run_sql(sql)
    out = ROOT / "full_col_compare_results.json"
    out.write_text(json.dumps(rows, indent=2), encoding="utf-8")
    print(f"Wrote {out} ({len(rows)} columns)")

    contract_cols = {
        "CONTRACT_ID",
        "CONTRACT_START_DATE",
        "CONTRACT_END_DATE",
        "CONTRACT_STATUS",
        "LATEST_CONTRACT_END_DATE",
        "TENTITIVE_SIGN_OFF_DATE",
        "FROM_DATE",
        "TO_DATE",
        "STATUS",
        "Overdue by / Days left",
    }
    print("\nContract-related columns:")
    for r in rows:
        if r[0] in contract_cols:
            print(f"  {r[0]}: {r[4]}% match ({r[1]}/{r[3]})")


if __name__ == "__main__":
    main()
