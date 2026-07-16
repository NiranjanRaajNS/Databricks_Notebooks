# Table Analysis: vessels_mainengine

## Source Table Schema

**Database**: synergy_vessel  
**Schema**: public  
**Table**: vessels_mainengine

### Source Table Structure

| Column Name | Data Type | Nullable | Notes |
|------------|-----------|----------|-------|
| id | bigint | NOT NULL | Primary key, auto-increment |
| vesselsid | bigint | NULL | Foreign key to `public.vessels.id` |
| make_model | bigint | NULL | Foreign key to `public.engine_model.id` |
| engine_name | varchar(256) | NULL | Engine name/description |
| mcr__kw | integer | NULL | Maximum Continuous Rating in kilowatts |
| mcr__hp | integer | NULL | Maximum Continuous Rating in horsepower |
| mcr__bhp | integer | NULL | Maximum Continuous Rating in brake horsepower |
| mcr_rpm | integer | NULL | Maximum Continuous Rating RPM |
| me_sump | integer | NULL | Main Engine Sump capacity |

### Constraints

- **Primary Key**: `vessels_mainengine_pkey` on `id`
- **Foreign Keys**:
  - `vesselsid` → `public.vessels.id` (bigint)
  - `make_model` → `public.engine_model.id` (bigint)

## Target Table Analysis

### Target Table Schema

**Database**: smac_master_migration  
**Schema**: vessel  
**Table**: vessel_engines

### Target Table Structure

| Column Name | Data Type | Nullable | Notes |
|------------|-----------|----------|-------|
| id | uuid | NOT NULL | Primary key |
| vessel_id | uuid | NOT NULL | Foreign key to `vessel.vessels.id` |
| engine_model_id | uuid | NULL | Foreign key to `vessel.engine_models.id` |
| engine_make_id | uuid | NULL | Foreign key to `vessel.engine_makes.id` |
| display_name | varchar(150) | NOT NULL | Engine display name (maps from `engine_name`) |
| engine_type | text | NULL | Engine type (not in source) |
| mcr_bhp | numeric | NULL | Maximum Continuous Rating in brake horsepower |
| mcr_kw | numeric | NULL | Maximum Continuous Rating in kilowatts |
| mcr_rpm | numeric | NULL | Maximum Continuous Rating RPM |
| ncr_kw | numeric | NULL | Normal Continuous Rating in kilowatts (not in source) |
| ncr_rpm | numeric | NULL | Normal Continuous Rating RPM (not in source) |
| electronic_engine | boolean | NULL | Electronic engine flag (not in source) |
| vessel_revision_id | uuid | NULL | Foreign key to vessel revisions (not in source) |
| tags | text[] | NULL | Tags array (not in source) |
| tenant_id | uuid | NOT NULL | Multi-tenancy support |
| parent_id | uuid | NULL | Parent relationship |
| version | integer | NOT NULL | Version number (default: 1) |
| defined_by | integer | NOT NULL | Global/Tenant/BU/Module (default: 0) |
| workflow_status | integer | NOT NULL | Workflow status (default: 0) |
| status | integer | NOT NULL | Status (default: 0) |
| created_at | timestamp | NOT NULL | Creation timestamp |
| updated_at | timestamp | NULL | Update timestamp |
| deleted_at | timestamp | NULL | Soft delete timestamp |
| archived_at | timestamp | NULL | Archive timestamp |
| audit_info | jsonb | NULL | Audit trail with legacy data |
| level | numeric | NULL | Level value |

### Constraints

- **Primary Key**: `PK_vessel_engines` on `id`
- **Indexes**:
  - `IX_vessel_engines_engine_make_id` on `engine_make_id`
  - `IX_vessel_engines_engine_model_id` on `engine_model_id`
  - `IX_vessel_engines_vessel_id` on `vessel_id`
  - `IX_vessel_engines_vessel_revision_id` on `vessel_revision_id`

### Key Differences from Source

1. **Table Name**: `vessel_engines` (not `vessel_main_engines`)
2. **Missing Fields in Target**:
   - `mcr_hp` - Source has `mcr__hp` but target doesn't have this field
   - `me_sump` - Source has `me_sump` but target doesn't have this field
3. **New Fields in Target**:
   - `engine_make_id` - Can be derived from `engine_model_id` relationship
   - `engine_type` - Not in source, set to NULL
   - `ncr_kw` - Normal Continuous Rating (not in source)
   - `ncr_rpm` - Normal Continuous Rating RPM (not in source)
   - `electronic_engine` - Boolean flag (not in source)
   - `vessel_revision_id` - Vessel revision reference (not in source)
   - `tags` - Tags array (not in source)
   - `display_name` - Maps from `engine_name` but is NOT NULL in target
4. **Data Type Changes**:
   - `mcr_kw`, `mcr_bhp`, `mcr_rpm` are `numeric` in target (not `integer`)
   - `created_at`, `updated_at` are `timestamp` (not `timestamptz`)

## Column Mapping Analysis

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|---------------|-------------|----------------|-------|
| 1 | id | bigint | id | uuid | gen_random_uuid() | **No identifier/uuid in source** - generate new UUIDs |
| 2 | vesselsid | bigint | vessel_id | uuid | Map via migration.table_mappings | Foreign key to vessels table |
| 3 | make_model | bigint | engine_model_id | uuid | Map via migration.table_mappings | Foreign key to engine_models table |
| 4 | engine_name | varchar(256) | engine_name | text | TRIM(engine_name) | Direct copy, trim whitespace |
| 5 | mcr__kw | integer | mcr_kw | integer | Direct copy | Note: double underscore in source becomes single underscore |
| 6 | mcr__hp | integer | mcr_hp | integer | Direct copy | Note: double underscore in source becomes single underscore |
| 7 | mcr__bhp | integer | mcr_bhp | integer | Direct copy | Note: double underscore in source becomes single underscore |
| 8 | mcr_rpm | integer | mcr_rpm | integer | Direct copy | Direct copy |
| 9 | me_sump | integer | me_sump | integer | Direct copy | Direct copy |
| 10 | - | - | tenant_id | uuid | '67c4470e-7812-4456-bc1b-c71e6df60d1d' | New column (see constants.sql) |
| 11 | - | - | version | integer | 1 | New column |
| 12 | - | - | defined_by | integer | 0 | New column - Global (0) |
| 13 | - | - | workflow_status | integer | 0 | New column - Draft (0) |
| 14 | - | - | status | integer | 0 | New column - Active (0) |
| 15 | - | - | created_at | timestamptz | NOW() | Source has no created_at column |
| 16 | - | - | updated_at | timestamptz | NOW() | Source has no updated_at column |
| 17 | - | - | audit_info | jsonb | Build JSON with legacy data | Store source id and foreign keys |

## Foreign Key Dependencies

### Prerequisites (must migrate first)

1. **vessel.vessels** (REQUIRED)
   - Source: `vesselsid` (bigint) → Target: `vessel_id` (uuid)
   - Mapping: Use `migration.table_mappings` where `target_table = 'vessels'`
   - Lookup: `source_id::bigint = vessels_mainengine.vesselsid`

2. **vessel.engine_models** (REQUIRED)
   - Source: `make_model` (bigint) → Target: `engine_model_id` (uuid)
   - Mapping: Use `migration.table_mappings` where `target_table = 'engine_models'`
   - Lookup: `source_id::bigint = vessels_mainengine.make_model`
   - Note: `engine_models` depends on `engine_makes`, so both must be migrated first

### Dependents (migrate after this table)

- None identified (this is a detail table for vessels)

## ID Field Handling

**CRITICAL**: The source table has:
- `id` (bigint) - Primary key, auto-increment
- **NO `identifier` column**
- **NO `uuid` column**

**Migration Strategy**:
- Generate new UUIDs using `gen_random_uuid()` for all records
- Store legacy `id` (bigint) in `audit_info->>'legacy_id'`
- Store legacy foreign keys (`vesselsid`, `make_model`) in `audit_info` for reference

## Data Transformation Rules

### 1. Vessel ID Mapping
```sql
-- Create lookup table for vessel_id foreign key resolution
CREATE TEMP TABLE vessel_id_mapping AS
SELECT 
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'vessels'
  AND target_db = current_database();
```

### 2. Engine Model ID Mapping
```sql
-- Create lookup table for engine_model_id foreign key resolution
CREATE TEMP TABLE engine_model_id_mapping AS
SELECT 
    source_id::bigint AS legacy_id,
    target_id AS new_id
FROM migration.table_mappings
WHERE target_table = 'engine_models'
  AND target_db = current_database();
```

### 3. Column Name Transformation
- Source uses double underscores (`mcr__kw`, `mcr__hp`, `mcr__bhp`)
- Target should use single underscores (`mcr_kw`, `mcr_hp`, `mcr_bhp`)
- This is a naming convention change, not a data transformation

### 4. Required Field Defaults
```sql
:'DEFAULT_TENANT_ID'::uuid AS tenant_id,  -- Use psql variable from constants.sql
1 AS version,
0 AS defined_by,  -- Global (0) - integer, not enum
0 AS workflow_status,  -- Draft (0) - integer, not enum
0 AS status,  -- Active (0) - integer, not enum
NOW() AS created_at,  -- Source has no created_at column
NOW() AS updated_at   -- Source has no updated_at column
```

### 5. Audit Information Structure
```sql
jsonb_build_object(
    'created_by', NULL,
    'deleted_by', NULL,
    'updated_by', NULL,
    'archived_by', NULL,
    'submitted_by', NULL,
    'approved_at', NULL,
    'approved_by', NULL,
    'approval_notes', NULL,
    'rejected_by', NULL,
    'notes', NULL,
    'legacy_id', id::text,
    'legacy_vesselsid', vesselsid::text,
    'legacy_make_model', make_model::text,
    'migrated_at', NOW(),
    'migration_source', 'synergy_vessel.public.vessels_mainengine'
) AS audit_info
```

## Data Quality Considerations

### 1. NULL Handling
- All source columns except `id` are nullable
- Foreign keys (`vesselsid`, `make_model`) may be NULL - handle with LEFT JOIN
- Only migrate rows where `vesselsid` IS NOT NULL (required for vessel relationship)

### 2. Data Validation
- Verify `vesselsid` exists in `vessel.vessels` (via mapping table)
- Verify `make_model` exists in `vessel.engine_models` (via mapping table)
- Validate integer ranges for MCR values (kw, hp, bhp, rpm)
- Validate `me_sump` is non-negative if not NULL

### 3. Duplicate Prevention
- No unique constraint on source table except primary key
- Multiple main engines per vessel are possible (one row per engine)
- Consider business rules: one main engine per vessel vs. multiple engines

## Migration Order

1. **engine_makes** (no dependencies)
2. **engine_models** (depends on engine_makes)
3. **vessels** (no dependencies on engine tables)
4. **vessels_mainengine** (depends on vessels and engine_models)

## Business Rules

1. **One-to-Many Relationship**: One vessel can have multiple main engines
2. **Optional Engine Model**: `make_model` is nullable - engine may not have a model reference
3. **Optional Vessel**: `vesselsid` is nullable - but should be filtered out (orphaned records)
4. **Engine Specifications**: MCR values (kw, hp, bhp, rpm) are optional but important for vessel operations

## Validation Checklist

- [ ] Verify target table structure exists in `vessel` schema
- [ ] Verify `vessel.vessels` table has been migrated
- [ ] Verify `vessel.engine_models` table has been migrated
- [ ] Verify `vessel.engine_makes` table has been migrated (prerequisite for engine_models)
- [ ] Row count matches legacy count (excluding NULL vesselsid)
- [ ] All `vessel_id` references are valid (no orphaned records)
- [ ] All `engine_model_id` references are valid (or NULL if make_model is NULL)
- [ ] All required fields are populated (id, tenant_id, version, status)
- [ ] Column name transformations correct (double underscore → single underscore)
- [ ] Mapping records created correctly in `migration.table_mappings`
- [ ] Sample records spot-checked for correctness

## Notes

1. **Source Table Naming**: Source uses `vessels_mainengine` (no underscore between vessels and mainengine)
2. **Target Table Naming**: Target likely uses `vessel_main_engines` (plural, with underscores)
3. **No Timestamps**: Source table has no `created_at` or `updated_at` columns - use `NOW()` for both
4. **No Identifier/UUID**: Source table has no `identifier` or `uuid` column - must generate new UUIDs
5. **Column Naming**: Source uses double underscores (`mcr__kw`) - target likely uses single underscores (`mcr_kw`)
6. **Foreign Key Nullability**: Both foreign keys are nullable - handle NULL cases appropriately
7. **Multiple Engines**: One vessel can have multiple main engines (one row per engine)

## Next Steps

1. **Verify Target Schema**: Run schema discovery on target database to confirm table name and structure
2. **Create Migration Script**: Follow the pattern from `vessel_capacity_migration.sql` or `vessel_ecdis_types_migration.sql`
3. **Create Mapping Document**: Document complete column mapping once target schema is confirmed
4. **Create Validation Script**: Validate row counts, foreign keys, and data quality
5. **Create Rollback Script**: Provide rollback capability for this table
6. **Update Migration Config**: Add entry to `migration_config_smac_master.json` with proper dependencies

