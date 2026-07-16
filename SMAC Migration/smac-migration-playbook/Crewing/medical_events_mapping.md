# Table Mapping: medical_events → medical_events

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: medical_events
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: medical_events
- **Source Script**: `04-migration-scripts/crewing/medical_events_migration.sql`

- **Legacy Path**: `synergy_seafarer.public.medical_events`
- **New Path**: `smac_crewing_migration.public.medical_events`

## Business Key

- **Business Key**: `id`
- **Source (orchestration)**: Medical Events (`medical_events` → `medical_events`)

## Migration Notes

- Uses integer values for status, workflow_status, and defined_by (see constants.sql)
- Migrates medical_events table. Preserves legacy UUID id directly. Maps seafarer_id, vessel_id, vessel_category_id, event_nature_id, event_classification_id via migration.table_mappings. Maps workflow_status_id (required) - may need default UUID. Uses standardized audit_info format.

## Special Considerations

- Script performs `TRUNCATE TABLE public.medical_events` before insert (full table reload).
- Orchestration dependencies: `seafarers`, `vessels`, `categories`, `medical_event_natures`, `medical_event_classifications`

## ID Mappings

All FK / UUID resolution lookup tables from the migration script (e.g. Owner ID Mapping, Vessel ID Mapping, rank lookups, company lookups, etc.).

**Total lookup tables:** 5

| Lookup Table | Purpose | Output Columns | table_mappings (source → target) | dblink |
|--------------|---------|----------------|-----------------------------------|--------|
| `seafarers_id_mapping` | Check for duplicate UUIDs in source table | `seafarer_uuid`, `new_id` | `migration.table_mappings` (see SQL) | - |
| `vessels_id_mapping` | Clear existing data from ta | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `vessel_categories_id_mapping` | FK lookup | `legacy_id`, `new_id` | `migration.table_mappings` (see SQL) | `smac_master_migration` |
| `medical_event_natures_id_mapping` | FK lookup | `legacy_id`, `new_id` | - | `synergy_seafarer` |
| `medical_event_classifications_id_mapping` | Create lookup tables for foreign | `legacy_id`, `new_id` | - | `synergy_seafarer` |

### `seafarers_id_mapping`

- **Purpose**: Check for duplicate UUIDs in source table
- **Output columns**: seafarer_uuid, new_id
- **migration.table_mappings**: target_table=seafarers

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    target_id as seafarer_uuid,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### `vessels_id_mapping`

- **Purpose**: Clear existing data from ta
- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_db=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE source_table ILIKE ''vessels'' AND target_db = ''smac_master_migration'''
) AS tm(source_id text, target_id uuid);
```

### `vessel_categories_id_mapping`

- **Output columns**: legacy_id, new_id
- **migration.table_mappings**: target_db=
- **dblink connection**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_categories_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table ILIKE ''categories'' AND target_db = ''smac_master_migration'''
) AS tm(source_id text, target_id uuid);
```

### `medical_event_natures_id_mapping`

- **Output columns**: legacy_id, new_id
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE medical_event_natures_id_mapping AS
SELECT
    source_nature.id as legacy_id,
    target_nature.id as new_id
FROM dblink('synergy_seafarer',
    'SELECT id FROM public.medical_event_nature'
) AS source_nature(id uuid)
JOIN dblink('smac_master_migration',
    'SELECT id FROM crewing.medical_event_natures'
) AS target_nature(id uuid) ON source_nature.id = target_nature.id;
```

### `medical_event_classifications_id_mapping`

- **Purpose**: Create lookup tables for foreign
- **Output columns**: legacy_id, new_id
- **dblink connection**: `synergy_seafarer`

```sql
CREATE TEMP TABLE medical_event_classifications_id_mapping AS
SELECT
    source_class.id as legacy_id,
    target_class.id as new_id
FROM dblink('synergy_seafarer',
    'SELECT id FROM public.medical_event_classification'
) AS source_class(id uuid)
JOIN dblink('smac_master_migration',
    'SELECT id FROM crewing.medical_event_classifications'
) AS target_class(id uuid) ON source_class.id = target_class.id;
```

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | - | id | - | migration.resolve_target_id() | migration.resolve_target_id( 'synergy_seafarer'::VARCHAR(100), 'public'::VARCHAR(100), 'medical_events'::VARCHAR(100), legacy_data.id::text, current_database()::text::VARCHAR(10... |
| 2 | derived | - | seafarer_id | - | seafarer_map.new_id AS seafarer_id | seafarer_map.new_id |
| 3 | incident_reported_number | - | incident_number | - | legacy_data.incident_reported_number AS incident_number | legacy_data.incident_reported_number |
| 4 | medical_event_date | - | event_date | - | legacy_data.medical_event_date AS event_date | legacy_data.medical_event_date |
| 5 | derived | - | event_time | - | NULL AS event_time | NULL |
| 6 | derived | - | event_source | - | NULL AS event_source | NULL |
| 7 | derived | - | event_nature_id | - | nature_map.new_id AS event_nature_id | nature_map.new_id |
| 8 | derived | - | event_classification_id | - | class_map.new_id AS event_classification_id | class_map.new_id |
| 9 | derived | - | vessel_id | - | COALESCE(vessel_map.new_id, NULL) AS vessel_id | COALESCE(vessel_map.new_id, NULL) |
| 10 | derived | - | vessel_category_id | - | COALESCE(category_map.new_id, NULL) AS vessel_category_id | COALESCE(category_map.new_id, NULL) |
| 11 | vessel_info | - | vessel_info | - | legacy_data.vessel_info AS vessel_info | legacy_data.vessel_info |
| 12 | description | - | description | - | legacy_data.description AS description | legacy_data.description |
| 13 | personal_effects_disposition | - | personal_effects_disposition | - | legacy_data.personal_effects_disposition AS personal_effects_disposition | legacy_data.personal_effects_disposition |
| 14 | seafarer_fitness_status | - | seafarer_fit_for_work | - | legacy_data.seafarer_fitness_status AS seafarer_fit_for_work | legacy_data.seafarer_fitness_status |
| 15 | unfit_start_date | - | unfit_start_date | - | legacy_data.unfit_start_date AS unfit_start_date | legacy_data.unfit_start_date |
| 16 | unfit_end_date | - | unfit_end_date | - | legacy_data.unfit_end_date AS unfit_end_date | legacy_data.unfit_end_date |
| 17 | unfit_for_days | - | unfit_for_days | - | legacy_data.unfit_for_days AS unfit_for_days | legacy_data.unfit_for_days |
| 18 | recommended_for_sign_off | - | recommended_sign_off | - | legacy_data.recommended_for_sign_off AS recommended_sign_off | legacy_data.recommended_for_sign_off |
| 19 | repatriation_required | - | repatriation_required | - | legacy_data.repatriation_required AS repatriation_required | legacy_data.repatriation_required |
| 20 | hospitalization_required | - | hospitalization_required | - | legacy_data.hospitalization_required AS hospitalization_required | legacy_data.hospitalization_required |
| 21 | derived | - | workflow_status_id | - | '00000000-0000-0000-0000-000000000000'::uuid AS workflow_status_id | '00000000-0000-0000-0000-000000000000'::uuid |
| 22 | is_verified | - | is_verified | - | COALESCE(legacy_data.is_verified, false) AS is_verified | COALESCE(legacy_data.is_verified, false) |
| 23 | verified_at | - | verified_at | - | legacy_data.verified_at AS verified_at | legacy_data.verified_at |
| 24 | derived | - | verified_by_id | - | NULL AS verified_by_id | NULL |
| 25 | derived | - | verification_notes | - | NULL AS verification_notes | NULL |
| 26 | deleted_at | - | status | - | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END AS status | CASE WHEN legacy_data.deleted_at IS NOT NULL THEN 3 ELSE 0 END |
| 27 | - | - | tenant_id | - | DEFAULT_TENANT_ID | :'DEFAULT_TENANT_ID'::uuid |
| 28 | created_at | - | created_at | - | COALESCE(legacy_data.created_at, NOW()) AS created_at | COALESCE(legacy_data.created_at, NOW()) |
| 29 | updated_at | - | updated_at | - | COALESCE(legacy_data.updated_at, NOW()) AS updated_at | COALESCE(legacy_data.updated_at, NOW()) |
| 30 | derived | - | archived_at | - | NULL AS archived_at | NULL |
| 31 | deleted_at | - | deleted_at | - | legacy_data.deleted_at AS deleted_at | legacy_data.deleted_at |
| 32 | audit_info | - | audit_info | - | migration.build_audit_info() | migration.build_audit_info( CASE WHEN legacy_data.audit_info IS NOT NULL AND legacy_data.audit_info->>'created_by' IS NOT NULL AND legacy_data.audit_info->>'created_by' <> '' TH... |

## Foreign Key Dependencies

### Prerequisites (from source script)

- See source script pre-migration checks

## Data Transformation Rules

FK / UUID resolution patterns from migration lookup tables (formerly documented as sections like **Owner ID Mapping**, **Vessel ID Mapping**, etc.).

### 1. Seafarers ID Mapping
**Purpose**: Check for duplicate UUIDs in source table
**Output columns**: `seafarer_uuid, new_id`
**migration.table_mappings**: `target_table='seafarers'`

```sql
CREATE TEMP TABLE seafarers_id_mapping AS
SELECT
    target_id as seafarer_uuid,
    target_id as new_id
FROM migration.table_mappings
WHERE target_table = 'seafarers'
  AND target_db = current_database();
```

### 2. Vessels ID Mapping
**Purpose**: Clear existing data from ta
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessels_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE source_table ILIKE ''vessels'' AND target_db = ''smac_master_migration'''
) AS tm(source_id text, target_id uuid);
```

### 3. Vessel Categories ID Mapping
**Output columns**: `legacy_id, new_id`
**migration.table_mappings**: see SQL below
**dblink**: `smac_master_migration`

```sql
CREATE TEMP TABLE vessel_categories_id_mapping AS
SELECT
    source_id::text as legacy_id,
    target_id as new_id
FROM dblink('smac_master_migration',
    'SELECT source_id, target_id FROM migration.table_mappings WHERE target_table ILIKE ''categories'' AND target_db = ''smac_master_migration'''
) AS tm(source_id text, target_id uuid);
```

### 4. Medical Event Natures ID Mapping
**Output columns**: `legacy_id, new_id`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE medical_event_natures_id_mapping AS
SELECT
    source_nature.id as legacy_id,
    target_nature.id as new_id
FROM dblink('synergy_seafarer',
    'SELECT id FROM public.medical_event_nature'
) AS source_nature(id uuid)
JOIN dblink('smac_master_migration',
    'SELECT id FROM crewing.medical_event_natures'
) AS target_nature(id uuid) ON source_nature.id = target_nature.id;
```

### 5. Medical Event Classifications ID Mapping
**Purpose**: Create lookup tables for foreign
**Output columns**: `legacy_id, new_id`
**dblink**: `synergy_seafarer`

```sql
CREATE TEMP TABLE medical_event_classifications_id_mapping AS
SELECT
    source_class.id as legacy_id,
    target_class.id as new_id
FROM dblink('synergy_seafarer',
    'SELECT id FROM public.medical_event_classification'
) AS source_class(id uuid)
JOIN dblink('smac_master_migration',
    'SELECT id FROM crewing.medical_event_classifications'
) AS target_class(id uuid) ON source_class.id = target_class.id;
```

Full migration context: `04-migration-scripts/crewing/medical_events_migration.sql`

## Validation

- Run `05-validation/crewing/medical_events_validation.sql` if available
- Run `06-rollback/crewing/medical_events_rollback.sql` if rollback is required

## Document Status

Auto-generated from migration/seed script (includes ID mapping lookup tables). Review complex multi-INSERT or unpivot migrations manually.
