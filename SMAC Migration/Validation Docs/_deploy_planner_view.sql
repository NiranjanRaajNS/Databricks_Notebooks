CREATE OR REPLACE TABLE reporting_layer.smac_prod.planner_view
TBLPROPERTIES (
  'delta.columnMapping.mode' = 'name',
  'delta.minReaderVersion' = '2',
  'delta.minWriterVersion' = '5'
)
AS
(
  SELECT
    * EXCEPT (ROW_NUM)
  FROM
    (
      SELECT
        A.*,
        B.* EXCEPT (ROW_NUM),
        COALESCE(B.VESSEL_NAME, A.REVISED_VESSEL_NAME) AS COMBINED_VESSEL_NAME,
        COALESCE(B.VESSEL_CATEGORY_NAME, A.REVISED_VESSEL_TYPE) AS COMBINED_VESSEL_CATEGORY_NAME,
        COALESCE(B.CDC_NUMBER, A.REVISED_CDC_NUMBER) AS COMBINED_CDC_NUMBER,
        CASE
          WHEN UPPER(TRIM(COALESCE(B.VESSEL_NAME, A.REVISED_VESSEL_NAME))) IN (
            'GENCO AQUITAINE','GENCO ARDENNES','GENCO AUVERGNE','GENCO BOURGOGNE','GENCO BRITTANY',
            'GENCO CONSTANTINE','GENCO DEFENDER','GENCO ENDEAVOUR','GENCO HUNTER','GENCO LANGUEDOC',
            'GENCO PICARDY','GENCO PREDATOR','GENCO PYRENEES','GENCO RESOLUTE','GENCO RHONE',
            'GENCO WARRIOR','GENCO TIBERIUS','GENCO TIGER','GENCO AUGUSTUS','GENCO TITUS',
            'GENCO COMMODUS','BALTIC WOLF','GENCO CLAUDIUS','GENCO HADRIAN','GENCO LONDON',
            'BALTIC MANTIS','BALTIC WASP','GENCO LION','BALTIC SCORPION','BALTIC HORNET',
            'GENCO MAXIMUS','BALTIC BEAR','GENCO ENTERPRISE','GENCO MADELEINE','GENCO MAYFLOWER',
            'GENCO CONSTELLATION','GENCO MARY','GENCO LADDEY','GENCO LIBERTY','GENCO COLUMBIA',
            'GENCO WEATHERLY','GENCO MAGIC','GENCO VIGILANT','GENCO FREEDOM','GENCO RANGER'
          ) THEN 'Bulk1'
          WHEN UPPER(TRIM(COALESCE(B.VESSEL_NAME, A.REVISED_VESSEL_NAME))) IN (
            'AMIS ACE','AMIS BRAVE','AMIS ELEGANCE','AMIS FORTUNE','AMIS INTEGRITY',
            'AMIS JUSTICE','AMIS KALON','AMIS LEADER','AMIS POWER','AMIS WISDOM I',
            'AMIS WISDOM II','AMIS WISDOM III','BLUE HORIZON','BUNUN KALON','BUNUN ORCHID',
            'BUNUN WISDOM','BUNUN XCEL','BUNUN YOUTH','BUNUN ZEST','CLEAR HORIZON',
            'COREFORTUNE OL','COREOCEAN OL','CORESKY OL','DAIWAN HERO','DAIWAN INFINITY',
            'DAIWAN KALON','DAIWAN WISDOM','ETERNITY SW','FRONTIER BONANZA','GLOBAL FAITH',
            'GOLDEN KIKU','KATAGALAN ACE','KATAGALAN BRAVE','MOONBRIGHT SW','NALUHU',
            'POAVOSA WISDOM','POAVOSA WISDOM III','SAKIZAYA ACE','SAKIZAYA CHAMPION',
            'SAKIZAYA RESPECT','SAKIZAYA XCEL','SCARLET EAGLE','TAOKAS WISDOM','TRANSFORMER OL'
          ) THEN 'Bulk2'
          WHEN UPPER(TRIM(COALESCE(B.VESSEL_NAME, A.REVISED_VESSEL_NAME))) IN (
            'OCEAN GLSR','IBERIAN BULKER','AFRICAN BULKER','BERGE NYANGANI','WORLD RUBY',
            'WORLD PRIZE','WORLD DIANA','WORLD VIRTUE','NORD ENERGY','NORD POWER','MESK',
            'ASIAN BULKER','AUSTRALIAN BULKER','ICELAND BULKER','NORD MAGNES','LAVENDER',
            'LOWLANDS BLUE','LOWLANDS DAWN','LOWLANDS FUTURE','LOWLANDS HORIZON','LOWLANDS RISE',
            'LOWLANDS SAGE','LOWLANDS OPAL','LOWLANDS YELLOW','ACE ETERNITY','AN LI','BENITAMOU',
            'GLOBAL HARMONY','MH ADAGIO','NEO','OCCITAN KEY','OCCITAN PAUILLAC','OCCITAN SKY',
            'SATIGNY','KEY JOURNEY','MH ARPEGGIO','NORD FERRUM','K. IRON MOUNTAIN','K RUBY',
            'K VICTORY','K PREMIUM ORE','K CONFIDENCE','IRON PHOENIX','IRON MIRACLE',
            'NORD STEEL','SERVETTE','MIRACLE'
          ) THEN 'Bulk3'
          WHEN UPPER(TRIM(COALESCE(B.VESSEL_NAME, A.REVISED_VESSEL_NAME))) IN (
            'CARL OLDENDORFF','CHARLOTTE OLDENDORFF','CHRISTINE OLDENDORFF','CONRAD OLDENDORFF',
            'CORA OLDENDORFF','KIM OLDENDORFF','KLARA OLDENDORFF','KNUT OLDENDORFF','EGE-M',
            'PATRICIA OLDENDORFF','PAUL OLDENDORFF','PENELOPE OLDENDORFF','PETER OLDENDORFF',
            'PHILIPP OLDENDORFF','PIA OLDENDORFF','EPICURUS','ETOILE','TRUE NEPTUNE',
            'TRUE CONRAD','TRUE CHAMPION','TAURUS','CL XUCHANG','CL CHANGSHA','CL LUZHOU',
            'CL YANGZHOU','CL GANJIANG','CL LIANYUNGANG','PACIFIC EAST','PACIFIC WEST',
            'PACIFIC NORTH','PACIFIC SOUTH','KM HAKATA','AM OCEAN SILVER','AM OCEAN STAR',
            'VINAYAK','LAMPARD','ZOLA','GH KAHLO','AM UMANG','AM KIRTI','AM TARANG',
            'GCL YAMUNA','GCL SABARMATI','GCL GANGA','GCL TAPI','GCL NARMADA','GCL MAHANADI'
          ) THEN 'Bulk4'
          ELSE 'Others'
        END AS COMBINED_BULK_TYPE,
        ROW_NUMBER() OVER (
            PARTITION BY A.REVISED_SEAFARER_ID
            ORDER BY
              A.REVISED_LATEST_DATE,
              A.REVISED_LATEST_CONTRACT_END_DATE,
              A.REVISED_LATEST_SIGN_OFF_DATE DESC
          ) AS ROW_NUM
      FROM
        (
          SELECT
            *
          FROM
            (
              SELECT
                T.*,
                ROW_NUMBER() OVER (
                    PARTITION BY REVISED_SEAFARER_ID
                    ORDER BY
                      REVISED_LATEST_DATE,
                      REVISED_LATEST_CONTRACT_END_DATE,
                      REVISED_LATEST_SIGN_OFF_DATE DESC
                  ) AS ROW_NUM1
              FROM
                (
                  SELECT
                    A.FIRST_NAME AS REVISED_FIRST_NAME,
                    A.MIDDLE_NAME AS REVISED_MIDDLE_NAME,
                    A.LAST_NAME AS REVISED_LAST_NAME,
                    A.DATE AS REVISED_LATEST_DATE,
                    A.CREW_CODE AS REVISED_CREW_CODE,
                    A.VESSEL_CATEGORY_NAME AS REVISED_VESSEL_TYPE,
                    A.VESSEL_NAME AS REVISED_VESSEL_NAME,
                    A.SEAFARER_ID AS REVISED_SEAFARER_ID,
                    A.CURRENT_STATUS AS REVISED_current_status,
                    A.CURRENT_RANK_NAME AS REVISED_RANK_NAME,
                    A.SIGN_OFF_REASON AS REVISED_SIGN_OFF_REASON,
                    A.AVAILABILITY_DATE AS REVISED_AVAILABILITY_DATE,
                    A.SHIP_MANAGEMENT_COMPANY_NAME AS REVISED_SHIP_MANAGEMENT_COMPANY_NAME,
                    A.GENDER_NAME AS REVISED_GENDER_NAME,
                    A.NATIONALITY_NAME AS REVISED_NATIONALITY_NAME,
                    A.SIGN_ON_DATE AS REVISED_SIGN_ON_DATE,
                    A.SIGN_OFF_DATE AS REVISED_SIGN_OFF_DATE,
                    A.CONTRACT_END_DATE AS REVISED_CONTRACT_END_DATE,
                    A.LATEST_CONTRACT_END_DATE AS REVISED_LATEST_CONTRACT_END_DATE,
                    A.LATEST_SIGN_OFF_DATE AS REVISED_LATEST_SIGN_OFF_DATE,
                    A.`Overdue by / Days left` AS `Revised Overdue by / Days left`,
                    A.PROFILE_STATUS AS REVISED_PROFILE_STATUS,
                    A.CDC_NUMBER AS REVISED_CDC_NUMBER,
                    -- REVISED_BULK_TYPE (same vessel name classification)
                    CASE
                      WHEN UPPER(TRIM(A.VESSEL_NAME)) IN (
                        'GENCO AQUITAINE','GENCO ARDENNES','GENCO AUVERGNE','GENCO BOURGOGNE','GENCO BRITTANY',
                        'GENCO CONSTANTINE','GENCO DEFENDER','GENCO ENDEAVOUR','GENCO HUNTER','GENCO LANGUEDOC',
                        'GENCO PICARDY','GENCO PREDATOR','GENCO PYRENEES','GENCO RESOLUTE','GENCO RHONE',
                        'GENCO WARRIOR','GENCO TIBERIUS','GENCO TIGER','GENCO AUGUSTUS','GENCO TITUS',
                        'GENCO COMMODUS','BALTIC WOLF','GENCO CLAUDIUS','GENCO HADRIAN','GENCO LONDON',
                        'BALTIC MANTIS','BALTIC WASP','GENCO LION','BALTIC SCORPION','BALTIC HORNET',
                        'GENCO MAXIMUS','BALTIC BEAR','GENCO ENTERPRISE','GENCO MADELEINE','GENCO MAYFLOWER',
                        'GENCO CONSTELLATION','GENCO MARY','GENCO LADDEY','GENCO LIBERTY','GENCO COLUMBIA',
                        'GENCO WEATHERLY','GENCO MAGIC','GENCO VIGILANT','GENCO FREEDOM','GENCO RANGER'
                      ) THEN 'Bulk1'
                      WHEN UPPER(TRIM(A.VESSEL_NAME)) IN (
                        'AMIS ACE','AMIS BRAVE','AMIS ELEGANCE','AMIS FORTUNE','AMIS INTEGRITY',
                        'AMIS JUSTICE','AMIS KALON','AMIS LEADER','AMIS POWER','AMIS WISDOM I',
                        'AMIS WISDOM II','AMIS WISDOM III','BLUE HORIZON','BUNUN KALON','BUNUN ORCHID',
                        'BUNUN WISDOM','BUNUN XCEL','BUNUN YOUTH','BUNUN ZEST','CLEAR HORIZON',
                        'COREFORTUNE OL','COREOCEAN OL','CORESKY OL','DAIWAN HERO','DAIWAN INFINITY',
                        'DAIWAN KALON','DAIWAN WISDOM','ETERNITY SW','FRONTIER BONANZA','GLOBAL FAITH',
                        'GOLDEN KIKU','KATAGALAN ACE','KATAGALAN BRAVE','MOONBRIGHT SW','NALUHU',
                        'POAVOSA WISDOM','POAVOSA WISDOM III','SAKIZAYA ACE','SAKIZAYA CHAMPION',
                        'SAKIZAYA RESPECT','SAKIZAYA XCEL','SCARLET EAGLE','TAOKAS WISDOM','TRANSFORMER OL'
                      ) THEN 'Bulk2'
                      WHEN UPPER(TRIM(A.VESSEL_NAME)) IN (
                        'OCEAN GLSR','IBERIAN BULKER','AFRICAN BULKER','BERGE NYANGANI','WORLD RUBY',
                        'WORLD PRIZE','WORLD DIANA','WORLD VIRTUE','NORD ENERGY','NORD POWER','MESK',
                        'ASIAN BULKER','AUSTRALIAN BULKER','ICELAND BULKER','NORD MAGNES','LAVENDER',
                        'LOWLANDS BLUE','LOWLANDS DAWN','LOWLANDS FUTURE','LOWLANDS HORIZON','LOWLANDS RISE',
                        'LOWLANDS SAGE','LOWLANDS OPAL','LOWLANDS YELLOW','ACE ETERNITY','AN LI','BENITAMOU',
                        'GLOBAL HARMONY','MH ADAGIO','NEO','OCCITAN KEY','OCCITAN PAUILLAC','OCCITAN SKY',
                        'SATIGNY','KEY JOURNEY','MH ARPEGGIO','NORD FERRUM','K. IRON MOUNTAIN','K RUBY',
                        'K VICTORY','K PREMIUM ORE','K CONFIDENCE','IRON PHOENIX','IRON MIRACLE',
                        'NORD STEEL','SERVETTE','MIRACLE'
                      ) THEN 'Bulk3'
                      WHEN UPPER(TRIM(A.VESSEL_NAME)) IN (
                        'CARL OLDENDORFF','CHARLOTTE OLDENDORFF','CHRISTINE OLDENDORFF','CONRAD OLDENDORFF',
                        'CORA OLDENDORFF','KIM OLDENDORFF','KLARA OLDENDORFF','KNUT OLDENDORFF','EGE-M',
                        'PATRICIA OLDENDORFF','PAUL OLDENDORFF','PENELOPE OLDENDORFF','PETER OLDENDORFF',
                        'PHILIPP OLDENDORFF','PIA OLDENDORFF','EPICURUS','ETOILE','TRUE NEPTUNE',
                        'TRUE CONRAD','TRUE CHAMPION','TAURUS','CL XUCHANG','CL CHANGSHA','CL LUZHOU',
                        'CL YANGZHOU','CL GANJIANG','CL LIANYUNGANG','PACIFIC EAST','PACIFIC WEST',
                        'PACIFIC NORTH','PACIFIC SOUTH','KM HAKATA','AM OCEAN SILVER','AM OCEAN STAR',
                        'VINAYAK','LAMPARD','ZOLA','GH KAHLO','AM UMANG','AM KIRTI','AM TARANG',
                        'GCL YAMUNA','GCL SABARMATI','GCL GANGA','GCL TAPI','GCL NARMADA','GCL MAHANADI'
                      ) THEN 'Bulk4'
                      ELSE 'Others'
                    END AS REVISED_BULK_TYPE,
                    -- Revised Rank Category
                    CASE
                      WHEN A.CURRENT_RANK_NAME IN ('Master','Chief Officer','Chief Engineer','Second Engineer')
                      THEN 'Top 4 Rank'
                      WHEN A.CURRENT_RANK_NAME IN (
                        'Additional 3rd Officer','Additional Master','Additional Officer','Deck Cadet',
                        'Deck Fitter','Junior Third Officer','Second Officer','Sr Deck cadet','Third Officer',
                        'Trainee Master','DNS EXAM','Junior Watchkeeping Officer','Anchor Handler',
                        'Additional Second Engineer','Assistant Engineer','Electrical Cadet','Electrical Officer',
                        'Electrician','Electro Technical Officer','Engine Cadet','Fourth Engineer','Gas Engineer',
                        'Junior Electrical Officer','Junior Engineer','Junior Fourth Engineer','Junior Gas Engineer',
                        'SENIOR ELECTRICAL OFFICER','Third Engineer','Trainee Electrical Officer',
                        'Trainee Gas Engineer','Trainee Marine Engineer','Trainee Radio Officer',
                        'GME EXAM','Electrical Engineer','Deck Girl'
                      ) THEN 'Officer'
                      WHEN A.CURRENT_RANK_NAME IN (
                        'Able Bodied Seaman','Bosun','Chief Cook','General Steward','Messboy','Messman',
                        'Ordinary Seaman','Trainee General Steward','Trainee Ordinary seaman','Trainee Wiper',
                        'Wiper','Wiper 1','Crew','Deck Fitter','Fitter','Motorman','Oiler','Oiler 1','Pumpman',
                        'Trainee Pumpman','RPFW(Repair Fitter Welder)','Traine Fitter','Trainee Fitter',
                        'Electro Technical Rating','Second Cook'
                      ) THEN 'Rating'
                      ELSE NULL
                    END AS `Revised Rank Category`
                  FROM
                    reporting_layer.smac_prod.revised_base_view A
                ) T
            )
          WHERE
            ROW_NUM1 = 1
        ) A
          LEFT JOIN reporting_layer.smac_prod.revised_relief_view B
            ON B.RELIEVE_SEAFARER_ID = A.REVISED_SEAFARER_ID
    )
  WHERE
    ROW_NUM1 = 1
)