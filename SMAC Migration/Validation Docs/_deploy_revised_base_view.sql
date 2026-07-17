CREATE OR REPLACE TABLE reporting_layer.smac_prod.revised_base_view
TBLPROPERTIES (
  'delta.columnMapping.mode' = 'name',
  'delta.minReaderVersion' = '2',
  'delta.minWriterVersion' = '5'
)
AS

SELECT DISTINCT
  SEAFARER_ID, FIRST_NAME, MIDDLE_NAME, LAST_NAME, SEAFARER_NAME, USER_ID,
  AHOY_STATUS, CREW_CODE, OLD_CREW_CODE, CURRENT_STATUS, SEAFARER_TYPE,
  ANNIVERSARY_DATE, RANK_ID, GENDER_NAME, DATE_OF_BIRTH, AGE, AGE_CATEGORY,
  CREATED_AT, PROFILE_STATUS, ONBOARD_SAILING_STATUS, AVAILABILITY_DATE,
  AVAILABILITY_MONTH, CDC_NUMBER, APPRAISAL_LINK, DOCUMENTS_LINK,
  SEA_EXPERIENCE_LINK, SEAFARER_PROFILE_LINK, CURRENT_RANK_NAME,
  NATIONALITY_NAME, `Last DOC/Contract Company`, CONTACT_NUMBER,
  EMERGENCY_CONTACT_NUMBER, EMAIL_ID, ADDRESS_TYPE, NEW_CONTACT_TYPE,
  PRIMARY_ADDRESS, CITY, PIN_CODE, NEAREST_AIRPORT, STATE, COUNTRY,
  SEA_EXPERIENCE_ID, SIGN_ON_DATE, SIGN_OFF_DATE, CONTRACT_ID,
  ACTIVE_CONTRACT, SAC_CONTRACT, VERIFIED_BY_ID, IS_VERIFIED,
  VERIFIED_BY_NAME, VERIFIED_ON, SIGN_OFF_REASON, RANK_NAME_SE,
  IMO_NUMBER, VESSEL_NAME, VESSEL_ID, SHIP_MANAGEMENT_COMPANY_NAME,
  PORT_OF_REGISTRY_NAME, SHIP_MANAGEMENT_COMPANY_ID, VESSEL_CATEGORY_NAME,
  CAPACITY, DWT, DUAL_FUEL, MAKE_NAME, MODEL_NAME, OUTPUT_POWER, GRT,
  EXPERIENCE_IN_DAYS, EXPERIENCE_IN_MONTHS, EXPERIENCE_IN_MONTHS_ROUNDOFF,
  EXPERIENCE_IN_YEAR, IS_SYNERGY_EXPERIANCE, POD_NAME, FROM_DATE, TO_DATE,
  STATUS, NEED_OF_APPRAISAL, APPRAISALS_RANK_NAME, APPRAISALS_VESSEL_NAME,
  APPRAISALS_VESSEL_CATEGORY_NAME, APPRAISAL_DATE, IS_MANUAL,
  CONTRACT_END_DATE, CONTRACT_START_DATE, TO_PORT_NAME, FROM_PORT_NAME,
  APPRAISAL_STATUS, SYNERGY_COMPANY, RECRUITMENT_COMPANY,
  TENTITIVE_SIGN_OFF_DATE, CONTRACT_STATUS, AGENT_NAME, POSITION_NAME,
  POSITION_RANK_ID, DATE_OF_TERMINATION, REMARK, REMARK_TYPE, INACTIVE_TYPE,
  UPDATED_AT, AVAILABILITY_REMARKS, `Overdue by / Days left`,
  LATEST_CONTRACT_END_DATE, LATEST_SIGN_OFF_DATE, LATEST_SIGN_ON_DATE,
  MONTHS, LATEST_DATE_1, DATE, COMPANY_STATUS, SYNERGY_JOINING_DATE,
  SECOND_LATEST_RANK, FIRST_RANK, FIRST_COMPANY, LATEST_COMPANY,
  VESSEL_FLEET_TYPE, RANK_LEVEL, `Rank Category`, POD_VESSEL_NAME,
  VESSEL_CODE, VESSEL_SUB_CATEGORY
FROM (
  WITH CTE AS (
    SELECT DISTINCT *, 
      ROW_NUMBER() OVER (
        PARTITION BY
          SEAFARER_ID, SEA_EXPERIENCE_ID, MONTHS,
          CREW_CODE, SIGN_ON_DATE, SIGN_OFF_DATE,
          FROM_DATE, TO_DATE, STATUS, NEED_OF_APPRAISAL,
          CONTRACT_STATUS, CONTRACT_END_DATE, CONTRACT_START_DATE,
          VESSEL_NAME, RANK_NAME_SE, SHIP_MANAGEMENT_COMPANY_NAME,
          REMARK, REMARK_TYPE, INACTIVE_TYPE, DATE_OF_TERMINATION,
          EXPERIENCE_IN_DAYS, ONBOARD_SAILING_STATUS, PROFILE_STATUS
        ORDER BY SEAFARER_ID
      ) AS RANK_
    FROM (
      SELECT
        C1.SEAFARER_ID, C1.FIRST_NAME, C1.MIDDLE_NAME, C1.LAST_NAME,
        C1.SEAFARER_NAME, C1.USER_ID, C1.AHOY_STATUS, C1.CREW_CODE,
        C1.OLD_CREW_CODE, C1.CURRENT_STATUS, C1.SEAFARER_TYPE,
        C1.ANNIVERSARY_DATE, C1.RANK_ID, C1.GENDER_NAME, C1.DATE_OF_BIRTH,
        C1.AGE, C1.AGE_CATEGORY, C1.CREATED_AT, C1.PROFILE_STATUS,
        C1.ONBOARD_SAILING_STATUS, C1.AVAILABILITY_DATE, C1.AVAILABILITY_MONTH,
        C1.CDC_NUMBER, C1.APPRAISAL_LINK, C1.DOCUMENTS_LINK,
        C1.SEA_EXPERIENCE_LINK, C1.SEAFARER_PROFILE_LINK, C1.CURRENT_RANK_NAME,
        C1.NATIONALITY_NAME, C1.`Last DOC/Contract Company`, C1.CONTACT_NUMBER,
        C1.EMERGENCY_CONTACT_NUMBER, C1.EMAIL_ID, C1.ADDRESS_TYPE,
        C1.NEW_CONTACT_TYPE, C1.PRIMARY_ADDRESS, C1.CITY, C1.PIN_CODE,
        C1.NEAREST_AIRPORT, C1.STATE, C1.COUNTRY, C1.SEA_EXPERIENCE_ID,
        C1.SIGN_ON_DATE, C1.SIGN_OFF_DATE, C1.CONTRACT_ID, C1.ACTIVE_CONTRACT,
        C1.SAC_CONTRACT, C1.VERIFIED_BY_ID, C1.IS_VERIFIED, C1.VERIFIED_BY_NAME,
        C1.VERIFIED_ON, C1.SIGN_OFF_REASON, C1.RANK_NAME_SE, C1.IMO_NUMBER,
        C1.VESSEL_NAME, C1.VESSEL_ID, C1.SHIP_MANAGEMENT_COMPANY_NAME,
        C1.PORT_OF_REGISTRY_NAME, C1.SHIP_MANAGEMENT_COMPANY_ID,
        C1.VESSEL_CATEGORY_NAME, C1.CAPACITY, C1.DWT, C1.DUAL_FUEL,
        C1.MAKE_NAME, C1.MODEL_NAME, C1.OUTPUT_POWER, C1.GRT,
        C1.EXPERIENCE_IN_DAYS, C1.EXPERIENCE_IN_MONTHS,
        C1.EXPERIENCE_IN_MONTHS_ROUNDOFF, C1.EXPERIENCE_IN_YEAR,
        C1.IS_SYNERGY_EXPERIANCE, C1.POD_NAME, C1.FROM_DATE, C1.TO_DATE,
        C1.STATUS, C1.NEED_OF_APPRAISAL, C1.APPRAISALS_RANK_NAME,
        C1.APPRAISALS_VESSEL_NAME, C1.APPRAISALS_VESSEL_CATEGORY_NAME,
        C1.APPRAISAL_DATE, C1.IS_MANUAL, C1.CONTRACT_END_DATE,
        C1.CONTRACT_START_DATE, C1.TO_PORT_NAME, C1.FROM_PORT_NAME,
        C1.APPRAISAL_STATUS, C1.SYNERGY_COMPANY, C1.RECRUITMENT_COMPANY,
        C1.TENTITIVE_SIGN_OFF_DATE, C1.CONTRACT_STATUS, C1.AGENT_NAME,
        C1.POSITION_NAME, C1.POSITION_RANK_ID, C1.DATE_OF_TERMINATION,
        C1.REMARK, C1.REMARK_TYPE, C1.INACTIVE_TYPE, C1.UPDATED_AT,
        C1.AVAILABILITY_REMARKS,
        C1.POD_VESSEL_NAME,
        C1.VESSEL_CODE,
        C1.VESSEL_SUB_CATEGORY,
        C1.`Overdue by / Days left`,
        C1.LATEST_CONTRACT_END_DATE, C1.LATEST_SIGN_OFF_DATE,
        C1.LATEST_SIGN_ON_DATE, C1.MONTHS,
        -- LATEST_DATE_1 & DATE
        CASE
          WHEN C1.LATEST_DATE IS NULL AND C1.LATEST_SIGN_ON_DATE = C1.SIGN_ON_DATE
          THEN C1.LATEST_SIGN_OFF_DATE
        END AS LATEST_DATE_1,
        COALESCE(C1.LATEST_DATE, LATEST_DATE_1) AS DATE,
        -- C2 derived columns
        C2.COMPANY_STATUS,
        C2.SYNERGY_JOINING_DATE,
        C2.SECOND_LATEST_RANK,
        C2.FIRST_RANK,
        C2.FIRST_COMPANY,
        C2.LATEST_COMPANY,
        -- VESSEL_FLEET_TYPE classification
        CASE
          WHEN UPPER(C1.VESSEL_CATEGORY_NAME) IN (
            'BULK CARRIER','CONTAINER','GEN CARGO / MULTI-PURPOSE VESSEL',
            'CAR CARRIER / RO-RO','CEMENT CARRIER','LOG CARRIER',
            'REEFER CARGO','HEAVY LIFT/PROJECT CARGO','WOODCHIP CARRIER','OBO CARRIER'
          ) THEN 'DRY'
          WHEN UPPER(C1.VESSEL_CATEGORY_NAME) IN (
            'OIL TANKER','CHEM/OIL PROD TANKER','ASPHALT / BITUMEN TANKER',
            'LPG CARRIER (REFRI)','CHEMICAL TANKER','LNG CARRIER',
            'LPG CARRIER (PRESS)','SUPPLY /OFFSHORE / TUG BOAT / AHTS',
            'GAS TANKER','OIL/PROD BUNKER BARGE','CHEM/PROD TANKER'
          ) THEN 'WET'
          ELSE NULL
        END AS VESSEL_FLEET_TYPE,
        -- RANK_LEVEL classification
        CASE
          WHEN C1.CURRENT_RANK_NAME IN ('Deck Cadet','Engine Cadet','Electrical Cadet') THEN 'Cadet'
          WHEN C1.CURRENT_RANK_NAME IN ('Master','Chief Officer','Chief Engineer','Second Engineer') THEN 'Management'
          WHEN C1.CURRENT_RANK_NAME IN ('Third Engineer','Third Officer','Second Officer','Fourth Engineer','Electro Technical Officer','Electrical Officer','Junior Fourth Engineer','Gas Engineer','Junior Third Officer') THEN 'Operational'
          WHEN C1.CURRENT_RANK_NAME IN ('Fitter','Pumpman','Able Bodied Seaman','Oiler','Ordinary Seaman','Chief Cook','Bosun','General Steward','Wiper','Crew') THEN 'Support'
          WHEN C1.CURRENT_RANK_NAME IN ('Trainee Electrical Officer','Trainee Wiper','Trainee Seaman','Trainee Fitter','Trainee General Steward') THEN 'Trainee'
        END AS RANK_LEVEL,
        -- Rank Category classification
        CASE
          WHEN C1.CURRENT_RANK_NAME IN ('Master','Chief Officer','Chief Engineer','Second Engineer') THEN 'Top 4 Rank'
          WHEN C1.CURRENT_RANK_NAME IN ('Additional 3rd Officer','Additional Master','Additional Officer','Deck Cadet','Deck Fitter','Junior Third Officer','Second Officer','Sr Deck cadet','Third Officer','Trainee Master','DNS EXAM','Junior Watchkeeping Officer','Anchor Handler','Additional Second Engineer','Assistant Engineer','Electrical Cadet','Electrical Officer','Electrician','Electro Technical Officer','Engine Cadet','Fourth Engineer','Gas Engineer','Junior Electrical Officer','Junior Engineer','Junior Fourth Engineer','Junior Gas Engineer','SENIOR ELECTRICAL OFFICER','Third Engineer','Trainee Electrical Officer','Trainee Gas Engineer','Trainee Marine Engineer','Trainee Radio Officer','GME EXAM','Electrical Engineer','Deck Girl') THEN 'Officer'
          WHEN C1.CURRENT_RANK_NAME IN ('Able Bodied Seaman','Bosun','Chief Cook','General Steward','Messboy','Messman','Ordinary Seaman','Trainee General Steward','Trainee Ordinary seaman','Trainee Wiper','Wiper','Wiper 1','Crew','Deck Fitter','Fitter','Motorman','Oiler','Oiler 1','Pumpman','Trainee Pumpman','Trainee Seaman','RPFW(Repair Fitter Welder)','Traine Fitter','Trainee Fitter','Electro Technical Rating','Second Cook') THEN 'Rating'
          ELSE NULL
        END AS `Rank Category`
      FROM (
        -- ============================
        -- SOURCE_TABLE + GEN_MONTH
        -- ============================
        WITH SOURCE_TABLE AS (
          SELECT * FROM (
            SELECT
              X.*,
              -- LATEST_DATE logic
              CASE
                WHEN X.SEAFARER_TYPE = 'Internal Seafarers' AND X.ONBOARD_SAILING_STATUS = 'Onboard' AND X.SIGN_ON_DATE = Y.SIGN_ON_DATE THEN Y.CONTRACT_END_DATE
                WHEN X.SEAFARER_TYPE = 'Internal Seafarers' AND X.ONBOARD_SAILING_STATUS = 'Onboard' AND X.SIGN_ON_DATE = Y.SIGN_ON_DATE AND X.CONTRACT_END_DATE IS NULL THEN Y.SIGN_OFF_DATE
                WHEN X.SEAFARER_TYPE IN ('Internal Seafarers','External Seafarers') AND X.ONBOARD_SAILING_STATUS = 'Onleave' AND X.SIGN_ON_DATE = Y.SIGN_ON_DATE THEN (CASE WHEN Y.SIGN_OFF_DATE IS NULL THEN Y.CONTRACT_END_DATE ELSE Y.SIGN_OFF_DATE END)
                WHEN X.SEAFARER_TYPE IN ('Internal Seafarers','External Seafarers') AND X.ONBOARD_SAILING_STATUS = 'No Past Records' THEN to_timestamp('1999-12-31 00:00:00.000')
                WHEN X.SEAFARER_TYPE IN ('Internal Seafarers','External Seafarers') AND Y.SIGN_OFF_DATE IS NULL AND Y.CONTRACT_END_DATE IS NULL THEN to_timestamp('1999-12-31 00:00:00.000')
                WHEN X.SEAFARER_TYPE IN ('Internal Seafarers','External Seafarers') AND X.CONTRACT_END_DATE = Y.CONTRACT_END_DATE AND Y.SIGN_OFF_DATE IS NULL AND Y.CONTRACT_END_DATE IS NOT NULL THEN Y.CONTRACT_END_DATE
                WHEN X.SEAFARER_TYPE IN ('Internal Seafarers','External Seafarers') AND X.SIGN_OFF_DATE = Y.SIGN_OFF_DATE AND Y.SIGN_OFF_DATE IS NOT NULL AND Y.CONTRACT_END_DATE IS NULL THEN Y.SIGN_OFF_DATE
              END AS LATEST_DATE,
              CONCAT(CAST(datediff(CAST(X.CONTRACT_END_DATE AS DATE), current_date()) AS STRING), ' ', 'DAYS') AS `Overdue by / Days left`,
              Y.CONTRACT_END_DATE AS LATEST_CONTRACT_END_DATE,
              Y.SIGN_OFF_DATE AS LATEST_SIGN_OFF_DATE,
              Y.SIGN_ON_DATE AS LATEST_SIGN_ON_DATE
            FROM (
              -- ============================
              -- MAIN INNER QUERY (X)
              -- All seafarers × All sea experiences
              -- ============================
              SELECT
                B.id AS SEAFARER_ID,
                B.first_name AS FIRST_NAME,
                B.middle_name AS MIDDLE_NAME,
                B.last_name AS LAST_NAME,
                CONCAT(COALESCE(B.first_name,' '),' ',COALESCE(B.middle_name,' '),' ',COALESCE(B.last_name,' ')) AS SEAFARER_NAME,
                B.id AS USER_ID,
                CASE WHEN B.identity_profile_id IS NOT NULL THEN 'Ahoy Installed' ELSE 'Ahoy Not Installed' END AS AHOY_STATUS,
                B.crew_code AS CREW_CODE,
                B.old_crew_code AS OLD_CREW_CODE,
                -- CURRENT_STATUS from profile_states
                PS.name AS CURRENT_STATUS,
                -- SEAFARER_TYPE
                CASE
                  WHEN UPPER(PS.code) IN ('REGISTERED','APPLIED','SELECTED') THEN 'External Seafarers'
                  ELSE 'Internal Seafarers'
                END AS SEAFARER_TYPE,
                SP.anniversary_date AS ANNIVERSARY_DATE,
                B.rank_id AS RANK_ID,
                -- GENDER from genders lookup
                COALESCE(GEN.name, 'Unknown') AS GENDER_NAME,
                B.date_of_birth AS DATE_OF_BIRTH,
                CAST(datediff(YEAR, CAST(B.date_of_birth AS DATE), CAST(current_date() AS DATE)) AS INT) AS AGE,
                CASE
                  WHEN AGE < 30 THEN '<30'
                  WHEN AGE BETWEEN 30 AND 49 THEN '30 - 49'
                  WHEN AGE > 50 THEN '50+'
                END AS AGE_CATEGORY,
                B.created_at AS CREATED_AT,
                -- PROFILE_STATUS from seafarer_profile_statuses
                CASE WHEN PST.code = 'ACTIVE' THEN 'Active Seafarer' ELSE 'Inactive Seafarer' END AS PROFILE_STATUS,
                -- ONBOARD_SAILING_STATUS
                CASE
                  WHEN PST.code = 'ACTIVE' AND PS.code = 'SIGNON' THEN 'Onboard'
                  WHEN J.sign_on_date IS NULL AND J.sign_off_date IS NULL THEN 'No Past Records'
                  ELSE 'Onleave'
                END AS ONBOARD_SAILING_STATUS,
                B.availability_date AS AVAILABILITY_DATE,
                month(CAST(B.availability_date AS DATE)) AS AVAILABILITY_MONTH,
                B.cdc_number AS CDC_NUMBER,
                -- Links (using SMAC URLs)
                CONCAT('https://crewing.synergymarine.in/crewing/seafarer/details/', B.id, '/appraisals') AS APPRAISAL_LINK,
                CONCAT('https://crewing.synergymarine.in/crewing/seafarer/details/', B.id, '/documents') AS DOCUMENTS_LINK,
                CONCAT('https://crewing.synergymarine.in/crewing/seafarer/details/', B.id, '/sea-experience') AS SEA_EXPERIENCE_LINK,
                CONCAT('https://crewing.synergymarine.in/crewing/seafarer/details/', B.id, '/personal') AS SEAFARER_PROFILE_LINK,
                -- Rank & Nationality names
                A.name AS CURRENT_RANK_NAME,
                C.name AS NATIONALITY_NAME,
                D.name AS `Last DOC/Contract Company`,
                -- Contact (absorbed into seafarers in SMAC)
                B.phone AS CONTACT_NUMBER,
                CAST(NULL AS STRING) AS EMERGENCY_CONTACT_NUMBER,  -- Not available in SMAC
                B.email AS EMAIL_ID,
                'PERMANENT ADDRESS' AS ADDRESS_TYPE,
                '1' AS NEW_CONTACT_TYPE,
                -- Address from seafarer_profile.primary_address (JSON)
                get_json_object(SP.primary_address, '$.address') AS PRIMARY_ADDRESS,
                get_json_object(SP.primary_address, '$.city') AS CITY,
                get_json_object(SP.primary_address, '$.pinCode') AS PIN_CODE,
                APT.name AS NEAREST_AIRPORT,
                COALESCE(ST.name, ST_ADDR.name) AS STATE,
                CTR.name AS COUNTRY,
                -- Sea Experience columns (ALL experiences, not just latest)
                J.id AS SEA_EXPERIENCE_ID,
                J.sign_on_date AS SIGN_ON_DATE,
                J.sign_off_date AS SIGN_OFF_DATE,
                COALESCE(J.contract_agreement_id, M_FB.id) AS CONTRACT_ID,
                J.active_contract AS ACTIVE_CONTRACT,
                CAST(NULL AS BOOLEAN) AS SAC_CONTRACT,  -- SAC-specific, no SMAC equivalent
                J.verified_by_id AS VERIFIED_BY_ID,
                J.is_verified AS IS_VERIFIED,
                CASE
                  WHEN J.verified_by_id IS NULL THEN NULL
                  WHEN VERIFIER.first_name IS NULL AND VERIFIER.last_name IS NULL THEN 'System'
                  ELSE TRIM(CONCAT(COALESCE(VERIFIER.first_name, ''), ' ', COALESCE(VERIFIER.last_name, '')))
                END AS VERIFIED_BY_NAME,
                J.verified_at AS VERIFIED_ON,
                K.name AS SIGN_OFF_REASON,
                L.name AS RANK_NAME_SE,
                J.imo_number AS IMO_NUMBER,
                COALESCE(J.vessel_name, 'Others') AS VESSEL_NAME,
                J.vessel_id AS VESSEL_ID,
                -- Ship Management Company
                COALESCE(
                  CASE
                    WHEN J.doc_holder_company_id IS NULL THEN J.external_company_name
                    ELSE UPPER(COMP_J.name)
                  END,
                  'Other'
                ) AS SHIP_MANAGEMENT_COMPANY_NAME,
                POR.name AS PORT_OF_REGISTRY_NAME,
                J.doc_holder_company_id AS SHIP_MANAGEMENT_COMPANY_ID,
                VCAT.name AS VESSEL_CATEGORY_NAME,
                -- Capacity & Engine (flattened from JSON in SMAC)
                CONCAT(COALESCE(get_json_object(J.cargo_capacity_info, '$.capacity'), ''), ' ', COALESCE(get_json_object(J.cargo_capacity_info, '$.capacity_unit'), '')) AS CAPACITY,
                CAST(J.dwt AS INT) AS DWT,
                CASE
                  WHEN get_json_object(J.engine_specifications, '$.DualFuel') = 'true' THEN 'YES'
                  ELSE 'NO'
                END AS DUAL_FUEL,
                get_json_object(J.engine_specifications, '$.EngineMakeName') AS MAKE_NAME,
                get_json_object(J.engine_specifications, '$.EngineModelName') AS MODEL_NAME,
                CONCAT(
                  COALESCE(get_json_object(J.engine_specifications, '$.OutputPower'), ''),
                  ' ',
                  COALESCE(UPPER(get_json_object(J.engine_specifications, '$.OutputPowerUnit')), '')
                ) AS OUTPUT_POWER,
                CAST(J.grt AS STRING) AS GRT,
                -- Experience calculations
                CASE
                  WHEN ONBOARD_SAILING_STATUS = 'Onboard' THEN datediff(current_date(), CAST(J.sign_on_date AS DATE))
                  ELSE COALESCE(J.duration_days, 0)
                END AS EXPERIENCE_IN_DAYS,
                CAST(EXPERIENCE_IN_DAYS AS DOUBLE) / 30 AS EXPERIENCE_IN_MONTHS,
                ROUND(CAST(EXPERIENCE_IN_DAYS AS DOUBLE) / 30) AS EXPERIENCE_IN_MONTHS_ROUNDOFF,
                ROUND((CAST(EXPERIENCE_IN_DAYS AS DOUBLE) / 30) / 12, 1) AS EXPERIENCE_IN_YEAR,
                J.is_inhouse_experience AS IS_SYNERGY_EXPERIANCE,
                -- POD
                POD.POD AS POD_NAME,
                -- Appraisals (from existing view)
                N.FROM_DATE,
                N.TO_DATE,
                N.STATUS,
                N.NEED_OF_APPRAISAL,
                N.APPRAISALS_RANK_NAME,
                N.APPRAISALS_VESSEL_NAME,
                N.APPRAISALS_VESSEL_CATEGORY_NAME,
                N.APPRAISAL_DATE,
                N.IS_MANUAL,
                -- Contract (primary: contract_agreement_id; fallback: seafarer_contracts + agreement when FK null)
                COALESCE(M.end_date, M_FB.end_date, SC_FB.end_date) AS CONTRACT_END_DATE,
                COALESCE(M.start_date, M_FB.start_date, SC_FB.start_date) AS CONTRACT_START_DATE,
                COALESCE(O.name, 'Unknown') AS TO_PORT_NAME,
                COALESCE(P.name, 'Unknown') AS FROM_PORT_NAME,
                CASE WHEN N.FROM_DATE IS NOT NULL THEN 'Completed' ELSE 'Not Completed' END AS APPRAISAL_STATUS,
                -- Synergy Company flag
                CASE
                  WHEN J.doc_holder_company_id IS NULL THEN FALSE
                  ELSE COALESCE(COMP_J.is_inhouse_company, FALSE)
                END AS SYNERGY_COMPANY,
                REC.name AS RECRUITMENT_COMPANY,
                COALESCE(J.sign_off_date, M.end_date, M_FB.end_date, SC_FB.end_date) AS TENTITIVE_SIGN_OFF_DATE,
                CASE
                  WHEN COALESCE(M.id, M_FB.id, SC_FB.id) IS NULL THEN NULL
                  WHEN COALESCE(M.agreement_status, M_FB.agreement_status) IN ('Void', 'Cancelled', 'Terminated') THEN 'Void'
                  WHEN SC_FB.status = 'Inactive' THEN 'Closed'
                  WHEN COALESCE(M.agreement_status, M_FB.agreement_status) = 'Signed' AND J.sign_off_date IS NULL THEN 'InForce'
                  WHEN J.sign_off_date IS NULL AND COALESCE(M.end_date, M_FB.end_date, SC_FB.end_date) >= CURRENT_DATE THEN 'InForce'
                  WHEN J.sign_off_date IS NULL THEN 'Active'
                  WHEN COALESCE(M.end_date, M_FB.end_date, SC_FB.end_date) < CURRENT_DATE THEN 'Closed'
                  WHEN COALESCE(M.agreement_status, M_FB.agreement_status) = 'Signed' THEN 'Signed'
                  ELSE 'Closed'
                END AS CONTRACT_STATUS,
                AGT.name AS AGENT_NAME,
                Z.name AS POSITION_NAME,
                Z.rank_id AS POSITION_RANK_ID,
                -- Remarks
                R.date_of_termination AS DATE_OF_TERMINATION,
                R.remark AS REMARK,
                R.remark_type AS REMARK_TYPE,
                R.Inactive_Type AS INACTIVE_TYPE,
                R.UPDATED_AT,
                AR.name AS AVAILABILITY_REMARKS,
                POD.vessel_name AS POD_VESSEL_NAME,
                VR.code AS VESSEL_CODE,
                VSC.name AS VESSEL_SUB_CATEGORY
              FROM (
                SELECT * FROM curated_db.db_smac_prod_navitasai_crewing_public.seafarers
                WHERE deleted_at IS NULL
              ) B
              -- Profile State
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_crewing.profile_states PS
                ON B.profile_state_id = PS.id
              -- Profile Status
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_crewing.seafarer_profile_statuses PST
                ON B.profile_status_id = PST.id
              -- Gender
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.genders GEN
                ON B.gender_id = GEN.id
              -- Seafarer Profile (address, anniversary)
              LEFT JOIN curated_db.db_smac_prod_navitasai_crewing_public.seafarer_profile SP
                ON B.id = SP.seafarer_id AND SP.deleted_at IS NULL
              -- Rank
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.ranks A
                ON A.id = B.rank_id
              -- Nationality
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.nationalities C
                ON C.id = B.nationality_id
              -- Present DOC Company
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.companies D
                ON D.id = B.present_doc_company_id
              -- Recruitment Company
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.companies REC
                ON REC.id = B.recruitment_company_id
              -- State (from profile address - using B.state_id on seafarers)
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.states ST
                ON ST.id = B.state_id
              -- Country
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.countries CTR
                ON CTR.id = B.country_id
              -- Nearest Airport (from primary_address JSON airportId)
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.airports APT
                ON APT.id = get_json_object(SP.primary_address, '$.airportId')
              -- State from address JSON (fallback when B.state_id is NULL)
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.states ST_ADDR
                ON ST_ADDR.id = get_json_object(SP.primary_address, '$.stateId')
              -- ALL Sea Experiences (not just latest!)
              LEFT JOIN (
                SELECT * FROM curated_db.db_smac_prod_navitasai_crewing_public.seafarer_sea_experiences
                WHERE deleted_at IS NULL
              ) J ON J.seafarer_id = B.id
              -- Verified By (IDP users table)
              LEFT JOIN curated_db.db_smac_prod_navitasai_idp_public.users VERIFIER
                ON VERIFIER.id = J.verified_by_id
              -- Sign Off Reason
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_crewing.sign_off_reasons K
                ON K.id = J.sign_off_reason_id
              -- Rank (sea experience)
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.ranks L
                ON L.id = J.rank_id
              -- Contract agreement (primary FK on sea experience)
              LEFT JOIN curated_db.db_smac_prod_navitasai_crewing_public.contract_agreements M
                ON M.id = J.contract_agreement_id AND M.deleted_at IS NULL
              -- Fallback: seafarer_contracts matched by sign_on_date (SAC vessel_contracts equivalent)
              LEFT JOIN curated_db.db_smac_prod_navitasai_crewing_public.seafarer_contracts SC_FB
                ON SC_FB.seafarer_id = B.id
                AND CAST(SC_FB.start_date AS DATE) = CAST(J.sign_on_date AS DATE)
                AND SC_FB.deleted_at IS NULL
                AND J.contract_agreement_id IS NULL
              -- Fallback agreement from parent seafarer_contract (prefer Signed > Approved)
              LEFT JOIN (
                SELECT ca.*,
                  ROW_NUMBER() OVER (
                    PARTITION BY ca.contract_id
                    ORDER BY CASE ca.agreement_status WHEN 'Signed' THEN 1 WHEN 'Approved' THEN 2 ELSE 3 END,
                      ca.updated_at DESC
                  ) AS rn
                FROM curated_db.db_smac_prod_navitasai_crewing_public.contract_agreements ca
                WHERE ca.deleted_at IS NULL
              ) M_FB ON M_FB.contract_id = SC_FB.id AND M_FB.rn = 1 AND J.contract_agreement_id IS NULL
              -- Position
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.positions Z
                ON Z.id = J.position_id
              -- Appraisals (SMAC view - direct UUID join)
              LEFT JOIN reporting_layer.smac_prod.appraisals_data N
                ON N.SEAFARER_ID = B.id
                AND to_date(N.FROM_DATE) BETWEEN to_date(J.sign_on_date) AND to_date(COALESCE(J.sign_off_date, M.end_date, M_FB.end_date, SC_FB.end_date))
                AND J.vessel_name = N.APPRAISALS_VESSEL_NAME
              -- Sign-off Port
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.ports O
                ON O.id = J.sign_off_port_id
              -- Sign-on Port
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.ports P
                ON P.id = J.sign_on_port_id
              -- Company for Synergy check (via doc_holder on sea exp)
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.companies COMP_J
                ON COMP_J.id = J.doc_holder_company_id
              -- Agent
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.agents AGT
                ON AGT.id = B.manning_agent_id
              -- Availability Remarks
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_crewing.availability_remarks AR
                ON AR.id = B.availability_remark_id
              -- Vessel Revisions (for vessel_code) - latest revision per vessel (any status)
              LEFT JOIN (
                SELECT vessel_id, code
                FROM curated_db.db_smac_prod_navitasai_masters_vessel.vessel_revisions
                WHERE deleted_at IS NULL
                QUALIFY ROW_NUMBER() OVER (PARTITION BY vessel_id ORDER BY status ASC, effective_date DESC, created_at DESC) = 1
              ) VR ON VR.vessel_id = J.vessel_id
              -- Vessel Sub Category
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_vessel.sub_categories VSC
                ON VSC.id = J.vessel_sub_category_id
              -- Vessel Category
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_vessel.categories VCAT
                ON VCAT.id = J.vessel_category_id
              -- Port of Registry
              LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.ports POR
                ON POR.id = J.port_of_registry_id
              -- POD (Place of Delivery) via fleet/vessel mapping
              LEFT JOIN (
                SELECT DISTINCT f.name AS POD, V.imo_number, V.name AS vessel_name
                FROM curated_db.db_smac_prod_navitasai_masters_vessel.fleets f
                LEFT JOIN (
                  SELECT * FROM curated_db.db_smac_prod_navitasai_masters_vessel.fld_fleet_vessels
                  WHERE deleted_at IS NULL
                ) fv ON f.id = fv.fleet_id
                LEFT JOIN curated_db.db_smac_prod_navitasai_masters_vessel.vessels V
                  ON V.id = fv.vessel_id
                WHERE f.deleted_at IS NULL
              ) POD ON POD.imo_number = J.imo_number
              -- Remarks (latest per seafarer)
              LEFT JOIN (
                SELECT seafarer_id, UPDATED_AT, date_of_termination, remark, remark_type, Inactive_Type
                FROM (
                  SELECT
                    R.seafarer_id,
                    R.updated_at AS UPDATED_AT,
                    R.date_of_action AS date_of_termination,
                    R.remark_text AS remark,
                    PRT.name AS remark_type,
                    PRR.name AS Inactive_Type,
                    ROW_NUMBER() OVER (PARTITION BY R.seafarer_id ORDER BY R.updated_at DESC) AS RNUM
                  FROM curated_db.db_smac_prod_navitasai_crewing_shore.seafarer_remarks R
                  LEFT JOIN curated_db.db_smac_prod_navitasai_masters_crewing.profile_remark_types PRT
                    ON PRT.id = R.profile_remark_type_id
                  LEFT JOIN curated_db.db_smac_prod_navitasai_masters_crewing.profile_remark_reasons PRR
                    ON PRR.id = R.profile_remark_reason_id
                  WHERE R.deleted_at IS NULL
                ) T WHERE RNUM = 1
              ) R ON R.seafarer_id = B.id
            ) X
            -- Y subquery: Latest dates per seafarer
            LEFT JOIN (
              SELECT
                A.id AS SEAFARER_ID,
                MAX(B.sign_off_date) AS SIGN_OFF_DATE,
                MAX(COALESCE(CA.end_date, CA_FB.end_date, SC.end_date)) AS CONTRACT_END_DATE,
                MAX(B.sign_on_date) AS SIGN_ON_DATE
              FROM (
                SELECT * FROM curated_db.db_smac_prod_navitasai_crewing_public.seafarers
                WHERE deleted_at IS NULL
              ) A
              LEFT JOIN (
                SELECT * FROM curated_db.db_smac_prod_navitasai_crewing_public.seafarer_sea_experiences
                WHERE deleted_at IS NULL
              ) B ON B.seafarer_id = A.id
              LEFT JOIN curated_db.db_smac_prod_navitasai_crewing_public.contract_agreements CA
                ON CA.id = B.contract_agreement_id AND CA.deleted_at IS NULL
              LEFT JOIN curated_db.db_smac_prod_navitasai_crewing_public.seafarer_contracts SC
                ON SC.seafarer_id = A.id
                AND CAST(SC.start_date AS DATE) = CAST(B.sign_on_date AS DATE)
                AND SC.deleted_at IS NULL
                AND B.contract_agreement_id IS NULL
              LEFT JOIN (
                SELECT ca.*,
                  ROW_NUMBER() OVER (
                    PARTITION BY ca.contract_id
                    ORDER BY CASE ca.agreement_status WHEN 'Signed' THEN 1 WHEN 'Approved' THEN 2 ELSE 3 END,
                      ca.updated_at DESC
                  ) AS rn
                FROM curated_db.db_smac_prod_navitasai_crewing_public.contract_agreements ca
                WHERE ca.deleted_at IS NULL
              ) CA_FB ON CA_FB.contract_id = SC.id AND CA_FB.rn = 1 AND B.contract_agreement_id IS NULL
              GROUP BY A.id
            ) Y ON X.SEAFARER_ID = Y.SEAFARER_ID
          )
        ),
        -- GEN_MONTH: Calendar table for monthly grain
        GEN_MONTH AS (
          SELECT MONTHS FROM (
            SELECT add_months(to_date('2000-01-01'), month_offset) AS MONTHS
            FROM (SELECT explode(sequence(0, CAST(months_between(current_date(), to_date('2000-01-01')) AS INT))) AS month_offset)
          )
          ORDER BY MONTHS
        )
        SELECT ST.*, GM.MONTHS
        FROM SOURCE_TABLE AS ST
        LEFT JOIN GEN_MONTH AS GM
          ON GM.MONTHS BETWEEN
            make_date(year(ST.SIGN_ON_DATE), month(ST.SIGN_ON_DATE), 1)
          AND
            make_date(
              year(CASE WHEN ST.SIGN_OFF_DATE IS NULL THEN current_date() ELSE ST.SIGN_OFF_DATE END),
              month(CASE WHEN ST.SIGN_OFF_DATE IS NULL THEN current_date() ELSE ST.SIGN_OFF_DATE END),
              1
            )
        ORDER BY CREW_CODE, VESSEL_ID, SEAFARER_ID
      ) C1
      -- ============================
      -- C2: COMPANY STATUS SUBQUERY
      -- ============================
      LEFT JOIN (
        SELECT
          T2.*,
          CASE
            WHEN COUNT(SIGN_ON_DATE) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE) = 1 THEN 'New Hand'
            WHEN UPPER(STATUS) = 'SIGNON' AND UPPER(LAG(DOC_COMPANY) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE)) = 'FALSE' AND UPPER(LAG(SYNERGY_COMPANY) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE)) = 'FALSE' AND FROM_DATE = SIGN_ON_DATE AND RANK = 1 THEN 'New Hand'
            WHEN UPPER(STATUS) = 'SIGNON' AND UPPER(LAG(SYNERGY_COMPANY) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE)) = 'FALSE' AND UPPER(LAG(DOC_COMPANY) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE)) = 'TRUE' AND FROM_DATE = SIGN_ON_DATE AND RANK = 1 THEN 'Ex Hand'
            WHEN UPPER(STATUS) = 'SIGNON' AND UPPER(LAG(SYNERGY_COMPANY) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE)) = 'TRUE' AND FROM_DATE = SIGN_ON_DATE AND RANK = 1 THEN 'Ex Hand'
            WHEN UPPER(STATUS) <> 'SIGNON' AND RANK = 1 AND UPPER(SYNERGY_COMPANY) = 'FALSE' THEN 'New Hand'
            WHEN UPPER(STATUS) <> 'SIGNON' AND RANK = 1 AND UPPER(SYNERGY_COMPANY) = 'TRUE' THEN 'Ex Hand'
            WHEN FROM_DATE IS NULL AND TO_DATE IS NULL THEN 'New Hand'
            WHEN UPPER(STATUS) = 'SIGNON' AND MAX(RANK) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE) = '1' THEN 'New Hand'
            ELSE ''
          END AS COMPANY_STATUS,
          CASE
            WHEN RANK = 1 AND COMPANY_STATUS IN ('New Hand','Ex Hand')
            THEN MIN(CASE WHEN UPPER(SYNERGY_COMPANY) = 'TRUE' THEN SIGN_ON_DATE ELSE NULL END) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE)
            ELSE NULL
          END AS SYNERGY_JOINING_DATE,
          CASE
            WHEN LAG(RANK) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE) = 2 AND RANK = 1
            THEN LAG(POSITION_NAME) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE)
          END AS SECOND_LATEST_RANK,
          CASE
            WHEN MIN(RANK_1) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE) = 1 AND RANK = 1
            THEN LAST_VALUE(POSITION_NAME) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
          END AS FIRST_RANK,
          CASE
            WHEN MIN(RANK_1) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE) = 1 AND RANK = 1
            THEN LAST_VALUE(SHIP_MANAGEMENT_COMPANY_NAME) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
          END AS FIRST_COMPANY,
          CASE
            WHEN ONBOARD_SAILING_STATUS = 'Onboard' THEN (
              CASE WHEN MIN(RANK_1) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE) = 1 AND RANK = 1
                THEN NTH_VALUE(SHIP_MANAGEMENT_COMPANY_NAME, 2) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
              END
            )
            WHEN ONBOARD_SAILING_STATUS = 'Onleave' THEN (
              CASE WHEN MIN(RANK_1) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE) = 1 AND RANK = 1
                THEN FIRST_VALUE(SHIP_MANAGEMENT_COMPANY_NAME) OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE DESC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
              END
            )
            ELSE NULL
          END AS LATEST_COMPANY
        FROM (
          SELECT
            T1.*,
            DENSE_RANK() OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE DESC) AS RANK,
            DENSE_RANK() OVER (PARTITION BY SEAFARER_ID ORDER BY SIGN_ON_DATE ASC) AS RANK_1
          FROM (
            SELECT
              B.id AS SEAFARER_ID,
              B.crew_code,
              MAX(J.sign_on_date) AS SIGN_ON_DATE,
              PS.code AS STATUS,
              J.duration_days AS EXPERIENCE_IN_DAYS,
              J.sign_on_date AS FROM_DATE,
              J.sign_off_date AS TO_DATE,
              J.id AS SEA_EXPERIENCE_ID,
              Z.name AS POSITION_NAME,
              J.external_company_name AS EXTERNAL_COMPANY_NAME,
              COALESCE(J.vessel_name, 'Others') AS VESSEL_NAME,
              COALESCE(
                CASE
                  WHEN J.doc_holder_company_id IS NULL THEN J.external_company_name
                  ELSE UPPER(COMP_Q.name)
                END, 'Other'
              ) AS SHIP_MANAGEMENT_COMPANY_NAME,
              J.doc_holder_company_id AS SHIP_MANAGEMENT_COMPANY_ID,
              CASE
                WHEN J.doc_holder_company_id IS NULL THEN 'FALSE'
                ELSE CAST(COALESCE(COMP_Q.is_inhouse_company, FALSE) AS STRING)
              END AS SYNERGY_COMPANY,
              COMP_Q.id AS SHIP_MANAGEMENT_COMPANY_ID_2,
              -- DOC_COMPANY: check if company has DOC service type
              CASE WHEN DOC_CS.company_id IS NOT NULL THEN 'TRUE' ELSE 'FALSE' END AS DOC_COMPANY,
              PS.name AS CURRENT_STATUS,
              CASE WHEN PST.code = 'ACTIVE' THEN 'Active Seafarer' ELSE 'Inactive Seafarer' END AS PROFILE_STATUS,
              CASE
                WHEN PST.code = 'ACTIVE' AND PS.code = 'SIGNON' THEN 'Onboard'
                WHEN J.sign_on_date IS NULL AND J.sign_off_date IS NULL THEN 'No Past Records'
                ELSE 'Onleave'
              END AS ONBOARD_SAILING_STATUS
            FROM (
              SELECT * FROM curated_db.db_smac_prod_navitasai_crewing_public.seafarers
              WHERE deleted_at IS NULL
            ) B
            LEFT JOIN curated_db.db_smac_prod_navitasai_masters_crewing.profile_states PS
              ON B.profile_state_id = PS.id
            LEFT JOIN curated_db.db_smac_prod_navitasai_masters_crewing.seafarer_profile_statuses PST
              ON B.profile_status_id = PST.id
            LEFT JOIN (
              SELECT * FROM curated_db.db_smac_prod_navitasai_crewing_public.seafarer_sea_experiences
              WHERE deleted_at IS NULL
            ) J ON B.id = J.seafarer_id
            LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.positions Z
              ON Z.id = J.position_id
            LEFT JOIN curated_db.db_smac_prod_navitasai_masters_public.companies COMP_Q
              ON COMP_Q.id = J.doc_holder_company_id
            -- DOC Company flag via company_services junction
            LEFT JOIN (
              SELECT DISTINCT company_id
              FROM curated_db.db_smac_prod_navitasai_masters_public.company_services
              WHERE service_type_id = '01963dd1-5f8d-7a3a-b099-11938b981183'
                AND deleted_at IS NULL
            ) DOC_CS ON DOC_CS.company_id = COMP_Q.id
            GROUP BY
              B.id, B.crew_code, PS.code, PS.name, PST.code,
              J.duration_days, J.sign_on_date, J.sign_off_date, J.id,
              Z.name, J.external_company_name, J.vessel_name,
              J.doc_holder_company_id, COMP_Q.name, COMP_Q.id, COMP_Q.is_inhouse_company,
              DOC_CS.company_id
          ) T1
        ) T2
      ) C2 ON C1.SEA_EXPERIENCE_ID = C2.SEA_EXPERIENCE_ID
    )
  )
  SELECT CTE.* EXCEPT (RANK_)
  FROM CTE
  WHERE RANK_ = 1
)