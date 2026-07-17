"""Export all SAC vs SMAC column mismatches side-by-side for sample crew codes."""
import json
import subprocess
import time
from pathlib import Path

import pandas as pd

from gen_full_col_compare_sql import COLS, JOIN_ON, SAC_COL_MAP, q

DB = r"C:\Users\niranjan.r\AppData\Local\Microsoft\WinGet\Packages\Databricks.DatabricksCLI_Microsoft.Winget.Source_8wekyb3d8bbwe\databricks.exe"
WH = "265c1d0e2d7c1541"
OUT_DIR = Path(__file__).parent
CREWS = ("ID-000379", "IN-277727")


def build_mismatch_sql(cols: list[str]) -> str:
    unions = []
    for col in cols:
        sac_col = SAC_COL_MAP.get(col, col)
        esc = col.replace("'", "''")
        unions.append(
            f"SELECT s.CREW_CODE, CAST(s.SIGN_ON_DATE AS DATE) AS sign_on, "
            f"CAST(s.SIGN_OFF_DATE AS DATE) AS sign_off, s.VESSEL_NAME, s.rn AS record_num, "
            f"'{esc}' AS column_name, "
            f"CAST(s.{q(sac_col)} AS STRING) AS sac_value, "
            f"CAST(m.{q(col)} AS STRING) AS smac_value "
            f"FROM sac_dedup s INNER JOIN smac_dedup m {JOIN_ON} "
            f"WHERE COALESCE(CAST(s.{q(sac_col)} AS STRING), '') <> "
            f"COALESCE(CAST(m.{q(col)} AS STRING), '')"
        )
    return f"""
WITH params AS (SELECT array('{CREWS[0]}','{CREWS[1]}') AS crews),
sac_dedup AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY CREW_CODE, CAST(SIGN_ON_DATE AS DATE), CAST(SIGN_OFF_DATE AS DATE), VESSEL_NAME
    ORDER BY CAST(CONTRACT_START_DATE AS TIMESTAMP), POSITION_NAME, CAST(FROM_DATE AS TIMESTAMP)
  ) rn
  FROM reporting_layer.sac_prod_seafarer_public.revised_base_view
  WHERE CREW_CODE IN (SELECT explode(crews) FROM params)
),
smac_dedup AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY CREW_CODE, CAST(SIGN_ON_DATE AS DATE), CAST(SIGN_OFF_DATE AS DATE), VESSEL_NAME
    ORDER BY CAST(CONTRACT_START_DATE AS TIMESTAMP), POSITION_NAME, CAST(FROM_DATE AS TIMESTAMP)
  ) rn
  FROM reporting_layer.smac_prod.revised_base_view
  WHERE CREW_CODE IN (SELECT explode(crews) FROM params)
)
{" UNION ALL ".join(unions)}
ORDER BY CREW_CODE, sign_on, record_num, column_name
"""


def run_sql(sql: str) -> list[list]:
    payload = {"statement": sql, "warehouse_id": WH, "wait_timeout": "50s"}
    tmp = OUT_DIR / "_mismatch_payload.json"
    tmp.write_text(json.dumps(payload), encoding="utf-8")
    r = subprocess.run(
        [DB, "api", "post", "/api/2.0/sql/statements", f"--json=@{tmp}", "-o", "json"],
        capture_output=True,
        text=True,
        check=True,
    )
    d = json.loads(r.stdout)
    st = d.get("status", {}).get("state")
    sid = d["statement_id"]
    for _ in range(120):
        if st in ("SUCCEEDED", "FAILED", "CANCELED"):
            break
        time.sleep(3)
        r2 = subprocess.run(
            [DB, "api", "get", f"/api/2.0/sql/statements/{sid}", "-o", "json"],
            capture_output=True,
            text=True,
            check=True,
        )
        d = json.loads(r2.stdout)
        st = d.get("status", {}).get("state")
    if st != "SUCCEEDED":
        raise RuntimeError(json.dumps(d.get("status", {}), indent=2))
    rows = d.get("result", {}).get("data_array", [])
    while d.get("manifest", {}).get("total_chunk_count", 1) > 1:
        chunk = d["manifest"]["total_chunk_count"]
        # fetch remaining chunks if truncated
        break
    return rows


def main():
    batch_size = 40
    all_rows: list[list] = []
    for i in range(0, len(COLS), batch_size):
        batch = COLS[i : i + batch_size]
        print(f"Batch {i // batch_size + 1}: columns {i + 1}-{i + len(batch)}")
        all_rows.extend(run_sql(build_mismatch_sql(batch)))

    df = pd.DataFrame(
        all_rows,
        columns=[
            "CREW_CODE",
            "SIGN_ON_DATE",
            "SIGN_OFF_DATE",
            "VESSEL_NAME",
            "RECORD_NUM",
            "COLUMN_NAME",
            "SAC_VALUE",
            "SMAC_VALUE",
        ],
    )
    xlsx = OUT_DIR / "revised_base_view_mismatch_side_by_side.xlsx"
    csv = OUT_DIR / "revised_base_view_mismatch_side_by_side.csv"
    df.to_excel(xlsx, index=False, sheet_name="Mismatches")
    df.to_csv(csv, index=False, encoding="utf-8-sig")
    print(f"Rows: {len(df)}")
    print(f"Wrote {xlsx}")
    print(f"Wrote {csv}")
    summary = (
        df.groupby("COLUMN_NAME")
        .size()
        .reset_index(name="mismatch_rows")
        .sort_values("mismatch_rows", ascending=False)
    )
    summary_xlsx = OUT_DIR / "revised_base_view_mismatch_summary.xlsx"
    with pd.ExcelWriter(summary_xlsx, engine="openpyxl") as w:
        df.to_excel(w, sheet_name="All Mismatches", index=False)
        summary.to_excel(w, sheet_name="By Column", index=False)
    print(f"Wrote {summary_xlsx}")
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
