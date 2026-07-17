"""Contract-focused SAC vs SMAC revised_base_view validation (post join v2 fix)."""
import json
import subprocess
import time
from pathlib import Path

DB = r"C:\Users\niranjan.r\AppData\Local\Microsoft\WinGet\Packages\Databricks.DatabricksCLI_Microsoft.Winget.Source_8wekyb3d8bbwe\databricks.exe"
WH = "265c1d0e2d7c1541"
ROOT = Path(__file__).parent
CREWS = ("ID-000379", "IN-277727")

CONTRACT_COLS = [
    "CONTRACT_ID",
    "CONTRACT_START_DATE",
    "CONTRACT_END_DATE",
    "CONTRACT_STATUS",
    "ACTIVE_CONTRACT",
    "SAC_CONTRACT",
    "TENTITIVE_SIGN_OFF_DATE",
    "Overdue by / Days left",
    "LATEST_CONTRACT_END_DATE",
    "LATEST_SIGN_ON_DATE",
    "LATEST_SIGN_OFF_DATE",
    "FROM_DATE",
    "TO_DATE",
    "STATUS",
    "NEED_OF_APPRAISAL",
    "APPRAISAL_STATUS",
]

SAC_COL_MAP = {"Overdue by / Days left": "Overdue by / Days left"}


def q(name: str) -> str:
    return f"`{name}`" if (" " in name or "/" in name) else name


JOIN_ON = """
    ON s.CREW_CODE = m.CREW_CODE
   AND CAST(s.SIGN_ON_DATE AS DATE) = CAST(m.SIGN_ON_DATE AS DATE)
   AND CAST(s.SIGN_OFF_DATE AS DATE) <=> CAST(m.SIGN_OFF_DATE AS DATE)
   AND s.VESSEL_NAME <=> m.VESSEL_NAME
   AND s.rn = m.rn
"""

BASE_CTES = f"""
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
"""


def run_sql(sql: str) -> list[list]:
    payload = {"statement": sql, "warehouse_id": WH, "wait_timeout": "50s"}
    tmp = ROOT / "_contract_cmp_payload.json"
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


def build_stats_sql() -> str:
    unions = []
    for col in CONTRACT_COLS:
        sac_col = SAC_COL_MAP.get(col, col)
        esc = col.replace("'", "''")
        unions.append(
            f"SELECT '{esc}' AS column_name, "
            f"SUM(CASE WHEN COALESCE(CAST(s.{q(sac_col)} AS STRING),'')="
            f"COALESCE(CAST(m.{q(col)} AS STRING),'') THEN 1 ELSE 0 END) AS matches, "
            f"SUM(CASE WHEN COALESCE(CAST(s.{q(sac_col)} AS STRING),'')<>"
            f"COALESCE(CAST(m.{q(col)} AS STRING),'') THEN 1 ELSE 0 END) AS mismatches, "
            f"COUNT(*) AS total "
            f"FROM sac_dedup s INNER JOIN smac_dedup m {JOIN_ON}"
        )
    return (
        BASE_CTES
        + f"""
SELECT column_name, matches, mismatches, total,
  ROUND(100.0 * matches / total, 2) AS match_pct
FROM (
  {" UNION ALL ".join(unions)}
)
ORDER BY match_pct ASC, column_name
"""
    )


def build_mismatch_sql() -> str:
    unions = []
    for col in CONTRACT_COLS:
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
    return (
        BASE_CTES
        + " "
        + " UNION ALL ".join(unions)
        + " ORDER BY CREW_CODE, sign_on, record_num, column_name"
    )


def build_sac_populated_sql() -> str:
    """Match rate where SAC had non-null contract dates (success criterion from plan)."""
    return (
        BASE_CTES
        + """
SELECT
  'CONTRACT_START_DATE (SAC non-null)' AS check_name,
  SUM(CASE WHEN s.CONTRACT_START_DATE IS NOT NULL
    AND CAST(s.CONTRACT_START_DATE AS DATE) = CAST(m.CONTRACT_START_DATE AS DATE) THEN 1 ELSE 0 END) AS matches,
  SUM(CASE WHEN s.CONTRACT_START_DATE IS NOT NULL
    AND COALESCE(CAST(s.CONTRACT_START_DATE AS DATE), DATE'1900-01-01')
      <> COALESCE(CAST(m.CONTRACT_START_DATE AS DATE), DATE'1900-01-01') THEN 1 ELSE 0 END) AS mismatches,
  SUM(CASE WHEN s.CONTRACT_START_DATE IS NOT NULL THEN 1 ELSE 0 END) AS sac_populated
FROM sac_dedup s INNER JOIN smac_dedup m """
        + JOIN_ON
        + """
UNION ALL
SELECT
  'CONTRACT_END_DATE (SAC non-null)',
  SUM(CASE WHEN s.CONTRACT_END_DATE IS NOT NULL
    AND CAST(s.CONTRACT_END_DATE AS DATE) = CAST(m.CONTRACT_END_DATE AS DATE) THEN 1 ELSE 0 END),
  SUM(CASE WHEN s.CONTRACT_END_DATE IS NOT NULL
    AND COALESCE(CAST(s.CONTRACT_END_DATE AS DATE), DATE'1900-01-01')
      <> COALESCE(CAST(m.CONTRACT_END_DATE AS DATE), DATE'1900-01-01') THEN 1 ELSE 0 END),
  SUM(CASE WHEN s.CONTRACT_END_DATE IS NOT NULL THEN 1 ELSE 0 END)
FROM sac_dedup s INNER JOIN smac_dedup m """
        + JOIN_ON
    )


def main():
    print("=== Contract column match rates (crews: %s) ===" % ", ".join(CREWS))
    stats = run_sql(build_stats_sql())
    out_stats = ROOT / "contract_col_compare_results.json"
    out_stats.write_text(json.dumps(stats, indent=2), encoding="utf-8")
    print(f"Wrote {out_stats.name}\n")
    print(f"{'Column':<32} {'Match%':>8} {'Matches':>8} {'Mismatch':>8} {'Total':>6}")
    print("-" * 70)
    for r in stats:
        print(f"{r[0]:<32} {float(r[4]):>7.2f}% {r[1]:>8} {r[2]:>8} {r[3]:>6}")

    print("\n=== Where SAC had contract dates (plan success criterion) ===")
    pop = run_sql(build_sac_populated_sql())
    for r in pop:
        sac_n = int(r[3])
        if sac_n == 0:
            pct = 0.0
        else:
            pct = 100.0 * int(r[1]) / sac_n
        print(f"  {r[0]}: {pct:.2f}% date match ({r[1]}/{sac_n} SAC-populated rows)")

    print("\n=== Contract mismatches (side-by-side) ===")
    mismatches = run_sql(build_mismatch_sql())
    out_mis = ROOT / "contract_col_mismatches.json"
    out_mis.write_text(json.dumps(mismatches, indent=2), encoding="utf-8")
    print(f"Wrote {out_mis.name} ({len(mismatches)} mismatch rows)")
    if not mismatches:
        print("  No mismatches on contract columns.")
    else:
        by_col: dict[str, int] = {}
        for row in mismatches:
            by_col[row[5]] = by_col.get(row[5], 0) + 1
        print("  Mismatch counts by column:")
        for col, n in sorted(by_col.items(), key=lambda x: -x[1]):
            print(f"    {col}: {n}")
        print("\n  Sample (first 15):")
        for row in mismatches[:15]:
            print(
                f"    {row[0]} | {row[1]} | {row[5]} | "
                f"SAC={row[6]!r} | SMAC={row[7]!r}"
            )


if __name__ == "__main__":
    main()
