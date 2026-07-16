# Table Mapping: seafarer_attachments → seafarer_attachments

## Overview
- **Legacy Database**: synergy_seafarer
- **Legacy Schema**: public
- **Legacy Table**: seafarer_attachments
- **New Database**: smac_crewing_migration
- **New Schema**: public
- **New Table**: seafarer_attachments
- **Migration Priority**: MEDIUM
- **Estimated Row Count**: TBD

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|------------|----------|----------------|-------|
| 1 | id | bigint | id | uuid | COALESCE(uuid, gen_random_uuid()) | Preserve uuid UUID when available |
| 2 | uuid | uuid | id | uuid | COALESCE(uuid, gen_random_uuid()) | Use uuid as new id |
| 3 | seafarer_id | bigint | seafarer_id | uuid | Map via seafarers lookup | FK resolution needed |
| 4 | document_type | text | file_type | text | TRIM(document_type) | Map document_type to file_type |
| 5 | - | - | file_sub_type | text | NULL | Set to NULL as per mapping |
| 6 | url | text | file_url | text | TRIM(url) | Map url to file_url |
| 7 | file_name | text | file_name | text | TRIM(file_name) | Direct copy |
| 8 | file_content_type | text | file_content_type | text | TRIM(file_content_type) | Direct copy |
| 9 | file_size | bigint | file_size | bigint | Direct copy | Direct copy |
| 10 | - | - | version_number | integer | 1 | New column - required, set to 1 |
| 11 | - | - | status | integer | 0 | New column - Active (0). Integer, not enum. See constants.sql |
| 12 | - | - | tenant_id | uuid | '67c4470e-7812-4456-bc1b-c71e6df60d1d' | New column |
| 13 | created_at | timestamp | created_at | timestamp | COALESCE(created_at, NOW()) | Direct copy |
| 14 | updated_at | timestamp | updated_at | timestamp | COALESCE(updated_at, NOW()) | Direct copy |
| 15 | - | - | audit_info | jsonb | Build JSON with legacy data | New column |
| Note | - | - | version, defined_by, workflow_status | - | - | These standard columns don't exist in target table |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- seafarers

### Dependents (migrate after this table)
- None

## Data Transformation Rules

### 1. Primary Key Preservation
```sql
COALESCE(identifier, gen_random_uuid()) AS id  -- Preserve legacy identifier UUID when available
```

### 2. Foreign Key Resolution
```sql
-- Map seafarer_id via migration.table_mappings
LEFT JOIN migration.table_mappings seafarer_id_mapping ON 
    seafarer_id_mapping.table_name = 'seafarers' AND 
    seafarer_id_mapping.legacy_id = legacy_data.seafarer_id::text
```

## Validation Checklist

- [ ] Row count matches legacy table
- [ ] All required fields are populated
- [ ] All seafarer_id foreign keys are valid
- [ ] All status/workflow_status/defined_by values are valid integers (0-3)
- [ ] Mapping records created correctly
- [ ] UUID preservation verified when identifier exists

