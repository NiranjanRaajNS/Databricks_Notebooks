# Table Mapping: Designation → designation_details

## Overview
- **Legacy Database**: synergy_identity_shore_prod
- **Legacy Schema**: public
- **Legacy Table**: Designation (case-sensitive)
- **New Database**: smac_idp_dev
- **New Schema**: public
- **New Table**: designation_details (lowercase)

## Column Mapping

| Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---------------|-------------|------------|----------|----------------|-------|
| Id | integer | Id | uuid | gen_random_uuid() | Generate new UUID |
| Name | text | Name | text | TRIM(Name) | Required |
| DepartmentId | integer | DepartmentId | uuid | Map via migration.table_mappings | FK to departments |
| - | - | DepartmentName | text | Join with Department table | From Department.Name |

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- **departments** - must be migrated before designation_details

### Dependents (migrate after this table)
- None

## Data Transformation Rules
- Generate new UUID for Id
- Map DepartmentId using migration.table_mappings lookup
- Join with Department table to get DepartmentName
- Use default UUID if department mapping not found
- Filter out records where Name is NULL or empty

