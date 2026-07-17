import json, subprocess, time
from pathlib import Path

DB = r"C:\Users\niranjan.r\AppData\Local\Microsoft\WinGet\Packages\Databricks.DatabricksCLI_Microsoft.Winget.Source_8wekyb3d8bbwe\databricks.exe"
WH = "265c1d0e2d7c1541"
OUT = Path(__file__).parent / "_relief_src3.json"


def run(sql: str):
    OUT.write_text(json.dumps({"statement": sql, "warehouse_id": WH, "wait_timeout": "50s"}), encoding="utf-8")
    d = json.loads(subprocess.run([DB, "api", "post", "/api/2.0/sql/statements", f"--json=@{OUT}", "-o", "json"], capture_output=True, text=True, check=True).stdout)
    sid = d["statement_id"]
    st = d["status"]["state"]
    for _ in range(60):
        if st in ("SUCCEEDED", "FAILED", "CANCELED"):
            break
        time.sleep(2)
        d = json.loads(subprocess.run([DB, "api", "get", f"/api/2.0/sql/statements/{sid}", "-o", "json"], capture_output=True, text=True, check=True).stdout)
        st = d["status"]["state"]
    if st != "SUCCEEDED":
        raise RuntimeError(json.dumps(d.get("status", {}), indent=2))
    return d["result"]["data_array"]


queries = {
    "SAC reliever sea exp": """
        SELECT get_json_object(se.vessel_info, '$.vessel_name') vessel, se.from_date, se.to_date
        FROM landing_zone.db_sac_prod_manning_public.RELIEFS r
        JOIN landing_zone.db_sac_prod_seafarer_public.SEAFARERS off ON off.id = r.relieving_seafarer_id
        JOIN landing_zone.db_sac_prod_seafarer_public.SEA_EXPERIENCES se ON se.seafarer_id = r.reliever_seafarer_id AND se.deleted_at IS NULL
        WHERE off.crew_code = 'IN-001293'
        ORDER BY se.from_date DESC
    """,
    "SMAC reliever sea exp": """
        SELECT se.vessel_name, se.sign_on_date, se.sign_off_date
        FROM curated_db.db_smac_prod_navitasai_crewing_public.seafarer_reliefs c
        JOIN curated_db.db_smac_prod_navitasai_crewing_public.seafarers off ON off.id = c.offsigner_id
        JOIN curated_db.db_smac_prod_navitasai_crewing_public.seafarer_sea_experiences se ON se.seafarer_id = c.onsigner_id AND se.deleted_at IS NULL
        WHERE off.crew_code = 'IN-001293'
        ORDER BY se.sign_on_date DESC
    """,
    "SAC relief state": """
        SELECT r.relief_state, r.reliever_travel_state
        FROM landing_zone.db_sac_prod_manning_public.RELIEFS r
        JOIN landing_zone.db_sac_prod_seafarer_public.SEAFARERS off ON off.id = r.relieving_seafarer_id
        WHERE off.crew_code = 'IN-001293'
    """,
    "SMAC relief state + port": """
        SELECT rs.code, c.joining_place_id
        FROM curated_db.db_smac_prod_navitasai_crewing_public.seafarer_reliefs c
        JOIN curated_db.db_smac_prod_navitasai_crewing_public.seafarers off ON off.id = c.offsigner_id
        LEFT JOIN curated_db.db_smac_prod_navitasai_masters_crewing.relief_states rs ON rs.id = c.relief_state_id
        WHERE off.crew_code = 'IN-001293'
    """,
}

for label, sql in queries.items():
    print(f"\n=== {label} ===")
    for row in run(sql):
        print(row)
