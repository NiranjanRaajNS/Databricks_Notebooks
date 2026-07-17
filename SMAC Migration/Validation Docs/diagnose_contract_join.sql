-- Contract join diagnostics for revised_base_view (2026-07-17)
-- Finding: ~89.65% of seafarer_sea_experiences have NULL contract_agreement_id
-- SAC reporting joins sea_experiences.CONTRACT_ID -> vessel_contracts
-- SMAC curated FK often unpopulated; fallback via seafarer_contracts + contract_agreements on sign_on_date

-- Sample experience trace
WITH sample AS (
  SELECT 'ID-000379' AS crew_code, TIMESTAMP '2024-12-05 00:00:00' AS sign_on
  UNION ALL SELECT 'IN-277727', TIMESTAMP '2024-04-18 00:00:00'
)
SELECT
  s.crew_code,
  CAST(s.sign_on AS DATE) AS sign_on,
  sac_j.CONTRACT_ID AS sac_exp_contract_id,
  vc.START_DATE AS sac_vc_start,
  vc.END_DATE AS sac_vc_end,
  vc.STATUS AS sac_vc_status,
  smac_j.contract_agreement_id,
  sc.start_date AS sc_start,
  sc.end_date AS sc_end,
  sc.status AS sc_status,
  ca.id AS fallback_agreement_id,
  ca.start_date AS ca_start,
  ca.end_date AS ca_end,
  ca.agreement_status
FROM sample s
JOIN landing_zone.db_sac_prod_seafarer_public.seafarers sac_b
  ON sac_b.CREW_CODE = s.crew_code AND sac_b.DELETED_AT IS NULL
JOIN landing_zone.db_sac_prod_seafarer_public.sea_experiences sac_j
  ON sac_j.SEAFARER_ID = sac_b.ID AND CAST(sac_j.FROM_DATE AS DATE) = CAST(s.sign_on AS DATE)
LEFT JOIN landing_zone.db_sac_prod_manning_public.vessel_contracts vc ON vc.ID = sac_j.CONTRACT_ID
JOIN curated_db.db_smac_prod_navitasai_crewing_public.seafarers smac_b
  ON smac_b.crew_code = s.crew_code AND smac_b.deleted_at IS NULL
LEFT JOIN curated_db.db_smac_prod_navitasai_crewing_public.seafarer_sea_experiences smac_j
  ON smac_j.seafarer_id = smac_b.id AND CAST(smac_j.sign_on_date AS DATE) = CAST(s.sign_on AS DATE)
LEFT JOIN curated_db.db_smac_prod_navitasai_crewing_public.seafarer_contracts sc
  ON sc.seafarer_id = smac_b.id AND CAST(sc.start_date AS DATE) = CAST(smac_j.sign_on_date AS DATE) AND sc.deleted_at IS NULL
LEFT JOIN (
  SELECT ca.*, ROW_NUMBER() OVER (
    PARTITION BY ca.contract_id
    ORDER BY CASE ca.agreement_status WHEN 'Signed' THEN 1 WHEN 'Approved' THEN 2 ELSE 3 END, ca.updated_at DESC
  ) AS rn
  FROM curated_db.db_smac_prod_navitasai_crewing_public.contract_agreements ca
  WHERE ca.deleted_at IS NULL
) ca ON ca.contract_id = sc.id AND ca.rn = 1;

-- NULL rate on contract_agreement_id
-- SELECT COUNT(*), SUM(CASE WHEN contract_agreement_id IS NULL THEN 1 ELSE 0 END) FROM seafarer_sea_experiences WHERE deleted_at IS NULL;
