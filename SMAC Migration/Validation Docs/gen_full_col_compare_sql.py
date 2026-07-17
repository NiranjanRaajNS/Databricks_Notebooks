"""Generate full 119-column SAC vs SMAC comparison SQL for 2 crew codes."""
import json
from pathlib import Path

COLS = [
    "SEAFARER_ID", "FIRST_NAME", "MIDDLE_NAME", "LAST_NAME", "SEAFARER_NAME", "USER_ID",
    "AHOY_STATUS", "CREW_CODE", "OLD_CREW_CODE", "CURRENT_STATUS", "SEAFARER_TYPE",
    "ANNIVERSARY_DATE", "RANK_ID", "GENDER_NAME", "DATE_OF_BIRTH", "AGE", "AGE_CATEGORY",
    "CREATED_AT", "PROFILE_STATUS", "ONBOARD_SAILING_STATUS", "AVAILABILITY_DATE",
    "AVAILABILITY_MONTH", "CDC_NUMBER", "APPRAISAL_LINK", "DOCUMENTS_LINK",
    "SEA_EXPERIENCE_LINK", "SEAFARER_PROFILE_LINK", "CURRENT_RANK_NAME", "NATIONALITY_NAME",
    "Last DOC/Contract Company", "CONTACT_NUMBER", "EMERGENCY_CONTACT_NUMBER", "EMAIL_ID",
    "ADDRESS_TYPE", "NEW_CONTACT_TYPE", "PRIMARY_ADDRESS", "CITY", "PIN_CODE",
    "NEAREST_AIRPORT", "STATE", "COUNTRY", "SEA_EXPERIENCE_ID", "SIGN_ON_DATE",
    "SIGN_OFF_DATE", "CONTRACT_ID", "ACTIVE_CONTRACT", "SAC_CONTRACT", "VERIFIED_BY_ID",
    "IS_VERIFIED", "VERIFIED_BY_NAME", "VERIFIED_ON", "SIGN_OFF_REASON", "RANK_NAME_SE",
    "IMO_NUMBER", "VESSEL_NAME", "VESSEL_ID", "SHIP_MANAGEMENT_COMPANY_NAME",
    "PORT_OF_REGISTRY_NAME", "SHIP_MANAGEMENT_COMPANY_ID", "VESSEL_CATEGORY_NAME", "CAPACITY",
    "DWT", "DUAL_FUEL", "MAKE_NAME", "MODEL_NAME", "OUTPUT_POWER", "GRT",
    "EXPERIENCE_IN_DAYS", "EXPERIENCE_IN_MONTHS", "EXPERIENCE_IN_MONTHS_ROUNDOFF",
    "EXPERIENCE_IN_YEAR", "IS_SYNERGY_EXPERIANCE", "POD_NAME", "FROM_DATE", "TO_DATE",
    "STATUS", "NEED_OF_APPRAISAL", "APPRAISALS_RANK_NAME", "APPRAISALS_VESSEL_NAME",
    "APPRAISALS_VESSEL_CATEGORY_NAME", "APPRAISAL_DATE", "IS_MANUAL", "CONTRACT_END_DATE",
    "CONTRACT_START_DATE", "TO_PORT_NAME", "FROM_PORT_NAME", "APPRAISAL_STATUS",
    "SYNERGY_COMPANY", "RECRUITMENT_COMPANY", "TENTITIVE_SIGN_OFF_DATE", "CONTRACT_STATUS",
    "AGENT_NAME", "POSITION_NAME", "POSITION_RANK_ID", "DATE_OF_TERMINATION", "REMARK",
    "REMARK_TYPE", "INACTIVE_TYPE", "UPDATED_AT", "AVAILABILITY_REMARKS",
    "Overdue by / Days left", "LATEST_CONTRACT_END_DATE", "LATEST_SIGN_OFF_DATE",
    "LATEST_SIGN_ON_DATE", "MONTHS", "LATEST_DATE_1", "DATE", "COMPANY_STATUS",
    "SYNERGY_JOINING_DATE", "SECOND_LATEST_RANK", "FIRST_RANK", "FIRST_COMPANY",
    "LATEST_COMPANY", "VESSEL_FLEET_TYPE", "RANK_LEVEL", "Rank Category",
    "POD_VESSEL_NAME", "VESSEL_CODE", "VESSEL_SUB_CATEGORY",
]
SAC_COL_MAP = {"EMERGENCY_CONTACT_NUMBER": "EMERGENCY_CONTACT_NUMBER_"}


def q(name: str) -> str:
    return f"`{name}`" if (" " in name or "/" in name) else name


JOIN_ON = """
    ON s.CREW_CODE = m.CREW_CODE
   AND CAST(s.SIGN_ON_DATE AS DATE) = CAST(m.SIGN_ON_DATE AS DATE)
   AND CAST(s.SIGN_OFF_DATE AS DATE) <=> CAST(m.SIGN_OFF_DATE AS DATE)
   AND s.VESSEL_NAME <=> m.VESSEL_NAME
   AND s.rn = m.rn
"""


def build_query(batch: list[str]) -> str:
    unions = []
    for col in batch:
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
    return f"""
WITH params AS (SELECT array('ID-000379','IN-277727') AS crews),
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
SELECT column_name, matches, mismatches, total,
  ROUND(100.0 * matches / total, 2) AS match_pct
FROM (
  {" UNION ALL ".join(unions)}
)
ORDER BY match_pct ASC, column_name
"""


if __name__ == "__main__":
    assert len(COLS) == 119, len(COLS)
    out = Path(__file__).with_name("full_col_compare.sql")
    out.write_text(build_query(COLS), encoding="utf-8")
    print(f"Wrote {out} ({len(COLS)} columns)")
