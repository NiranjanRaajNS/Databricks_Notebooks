# Table Mapping: UserAllocatedCompany → user_allocated_company

## Overview
- **Source Database**: synergy_identity_shore_prod
- **Source Schema**: public
- **Source Table**: UserAllocatedCompany
- **Target Database**: smac_idp_dev
- **Target Schema**: public
- **Target Table**: user_allocated_company
- **Migration Priority**: MEDIUM
- **Estimated Row Count**: To be determined via discovery script

## Column Mapping

| # | Legacy Column | Legacy Type | New Column | New Type | Transformation | Notes |
|---|---------------|-------------|--------------|-------------|----------------|-------|
| 1 | Id | integer | Id | integer IDENTITY | nextval(pg_get_serial_sequence(...)) | Auto-increment IDENTITY column |
| 2 | UserId | text | UserId | uuid | Map via migration.table_mappings (users) | Foreign key lookup |
| 3 | CompanyId | integer | CompanyId | uuid | Map via migration.table_mappings (companies) | Foreign key lookup |

## ID Field Handling

- **Source**: `Id` is integer (serial)
- **Target**: `Id` is integer IDENTITY (auto-increment)
- **Mapping**: Use `nextval(pg_get_serial_sequence('public.user_allocated_company', 'Id'))` for new IDs
- **Composite Key**: Use `UserId || '|' || CompanyId::text` as source_id in mapping table

## Foreign Key Dependencies

### Prerequisites (must migrate first)
- **users**: Required for UserId mapping
- **companies**: Required for CompanyId mapping

### Dependents (migrate after this table)
- None

## Data Transformation Rules

### 1. UserId Mapping
- Source has `UserId` as text
- Map via lookup table from `migration.table_mappings` where `target_table = 'users'`
- Use default UUID `'00000000-0000-0000-0000-000000000000'` if mapping not found

### 2. CompanyId Mapping
- Source has `CompanyId` as integer
- Map via lookup table from `migration.table_mappings` where `target_table = 'companies'`
- Use default UUID `'00000000-0000-0000-0000-000000000000'` if mapping not found

### 3. ID Generation
- Use `nextval(pg_get_serial_sequence('public.user_allocated_company', 'Id'))` for `Id` column
- This ensures auto-increment behavior

## Validation Checklist

- [ ] Row count matches legacy count
- [ ] All required fields (Id, UserId, CompanyId) are NOT NULL
- [ ] All UserId references are valid UUIDs (or default UUID)
- [ ] All CompanyId references are valid UUIDs (or default UUID)
- [ ] No duplicate UserId-CompanyId combinations
- [ ] Mapping records created correctly

## Notes

- **Source**: Reading from `synergy_identity_shore_prod.public.UserAllocatedCompany`
- **Migration Path**: synergy_identity_shore_prod.public.UserAllocatedCompany → smac_idp_dev.public.user_allocated_company
- **Foreign Key Mappings**: Read from `migration.table_mappings` for users and companies
- **Composite Key**: The combination of UserId and CompanyId should be unique
- **ID Generation**: Uses IDENTITY column, so new IDs are auto-generated

