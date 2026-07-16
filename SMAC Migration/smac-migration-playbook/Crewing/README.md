# Crewing Module - Mappings

## Overview
This folder contains mapping documentation for tables migrating to the **smac_crewing_migration** database.

## Target Database
- **Database**: smac_crewing_migration (local docs); **`07-orchestration/migration_config_smac_crewing.json`** defines the real target (e.g. `navitasai_crewing`) for runs.
- **Host**: localhost
- **Port**: 5432

## Module Purpose
The Crewing module contains seafarer and crewing-related transactional and master data. These include:
- Seafarer profiles and data
- Seafarer competency tasks and activities
- Seafarer competency subtasks and activities
- And related crewing management tables

## Table Count
The orchestration config lists **118** table entries for this module (**104** with `migration_enabled: true`). See `07-orchestration/migration_config_smac_crewing.json`.

## Migration Order
Migrate in **dependency order** from the config. **Seafarers** and core profile tables usually come before assignments, documents, and downstream transactional tables; ensure required **master** data is loaded first (see `03-mappings/master/`).

## File Naming Convention
- Mapping files: `{table_name}_mapping.md`
- Example: `seafarers_mapping.md`, `seafarer_competency_tasks_mapping.md`

## Related Folders
- Migration scripts: `04-migration-scripts/crewing/`
- Validation scripts: `05-validation/crewing/`
- Rollback scripts: `06-rollback/crewing/`

## Configuration
Table configuration is defined in `07-orchestration/migration_config_smac_crewing.json`.

## Dependencies
This module depends on master tables from the Master module. Ensure master tables are migrated first before migrating crewing tables.

