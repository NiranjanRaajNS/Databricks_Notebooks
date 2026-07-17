"""Compare all columns for revised_relief_view rows filtered by CREW_CODE.

See revised_relief_view_validation_notes.md for columns that are expected to
mismatch vs SAC (SAC join bugs, UUID IDs, relief state mapping, etc.).
"""
import json
import subprocess
import time
from pathlib import Path

DB = r"C:\Users\niranjan.r\AppData\Local\Microsoft\WinGet\Packages\Databricks.DatabricksCLI_Microsoft.Winget.Source_8wekyb3d8bbwe\databricks.exe"
WH = "265c1d0e2d7c1541"
CREW = "IN-001293"
OUT_DIR = Path(__file__).parent


def run_sql(sql: str) -> list[list]:
    payload = {"statement": sql, "warehouse_id": WH, "wait_timeout": "50s"}
    tmp = OUT_DIR / "_relief_cmp_payload.json"
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
    result = d.get("result") or {}
    if "data_array" in result:
        return result["data_array"]
    if result.get("result_set_format") == "JSON_ARRAY":
        rows = []
        for chunk in result.get("data", []):
            rows.extend(json.loads(chunk) if isinstance(chunk, str) else chunk)
        return rows
    raise RuntimeError(json.dumps(result, indent=2)[:2000])


def get_columns() -> list[str]:
    rows = run_sql("DESCRIBE TABLE reporting_layer.smac_prod.revised_relief_view")
    return [r[0] for r in rows if r[0] and not r[0].startswith("#")]


def qcol(name: str) -> str:
    return f"`{name}`"


def fetch_row(table: str) -> dict[str, str | None]:
    cols = get_columns()
    select_list = ", ".join(f"CAST({qcol(c)} AS STRING) AS {qcol(c)}" for c in cols)
    sql = f"SELECT {select_list} FROM {table} WHERE CREW_CODE = '{CREW}' LIMIT 1"
    rows = run_sql(sql)
    if not rows:
        raise RuntimeError(f"No rows in {table} for CREW_CODE={CREW}")
    schema = run_sql(f"DESCRIBE TABLE {table}")
    col_names = [r[0] for r in schema if r[0] and not r[0].startswith("#")]
    return dict(zip(col_names, rows[0]))


def norm(v: str | None) -> str:
    if v is None:
        return ""
    return str(v).strip()


def main():
    cols = get_columns()
    print(f"Columns in revised_relief_view: {len(cols)}")

    cnt_sql = f"""
    SELECT 'SAC' AS src, COUNT(*) AS cnt
    FROM reporting_layer.sac_prod_seafarer_public.revised_relief_view
    WHERE CREW_CODE = '{CREW}'
    UNION ALL
    SELECT 'SMAC', COUNT(*)
    FROM reporting_layer.smac_prod.revised_relief_view
    WHERE CREW_CODE = '{CREW}'
    """
    print("\nRow counts:")
    for r in run_sql(cnt_sql):
        print(f"  {r[0]}: {r[1]}")

    sac = fetch_row("reporting_layer.sac_prod_seafarer_public.revised_relief_view")
    smac = fetch_row("reporting_layer.smac_prod.revised_relief_view")

    match, mis = [], []
    for col in cols:
        s_val, m_val = norm(sac.get(col)), norm(smac.get(col))
        if s_val == m_val:
            match.append((col, s_val))
        else:
            mis.append((col, sac.get(col), smac.get(col)))

    print(f"\nFilter: CREW_CODE = {CREW}")
    print(f"Columns compared: {len(cols)} | MATCH: {len(match)} | MISMATCH: {len(mis)}")

    print("\n=== MISMATCHES ===")
    for col, s_val, m_val in mis:
        print(f"{col} | SAC: {s_val} | SMAC: {m_val}")

    print("\n=== MATCHES ===")
    for col, val in match:
        print(f"{col} | {val}")

    out = OUT_DIR / f"relief_compare_{CREW.replace('-', '_')}.json"
    out.write_text(
        json.dumps(
            {
                "crew_code": CREW,
                "columns_compared": len(cols),
                "matches": len(match),
                "mismatches": len(mis),
                "mismatch_details": [{"column": c, "sac": s, "smac": m} for c, s, m in mis],
                "match_details": [{"column": c, "value": v} for c, v in match],
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"\nWrote {out}")


if __name__ == "__main__":
    main()
