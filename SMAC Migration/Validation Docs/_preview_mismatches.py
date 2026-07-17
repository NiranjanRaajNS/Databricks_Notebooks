import pandas as pd
from pathlib import Path

p = Path(__file__).parent / "revised_base_view_mismatch_side_by_side.csv"
df = pd.read_csv(p)
print("Total mismatch rows:", len(df))
print("Unique columns with mismatches:", df["COLUMN_NAME"].nunique())
for col in [
    "CONTACT_NUMBER", "CURRENT_STATUS", "NATIONALITY_NAME", "MONTHS", "SEAFARER_ID",
    "POD_NAME", "SHIP_MANAGEMENT_COMPANY_NAME", "CDC_NUMBER", "DATE_OF_BIRTH",
    "STATE", "COUNTRY", "VESSEL_ID", "CONTRACT_STATUS",
]:
    sub = df[df["COLUMN_NAME"] == col]
    if sub.empty:
        continue
    pairs = (
        sub.groupby(["SAC_VALUE", "SMAC_VALUE"])
        .size()
        .reset_index(name="cnt")
        .sort_values("cnt", ascending=False)
        .head(3)
    )
    print(f"\n=== {col} ({len(sub)} rows) ===")
    for _, r in pairs.iterrows():
        print(f"  SAC: {r['SAC_VALUE']!r} | SMAC: {r['SMAC_VALUE']!r} ({r['cnt']} rows)")

print("\n--- Sample rows (first 30) ---")
print(df.head(30).to_string(index=False))
