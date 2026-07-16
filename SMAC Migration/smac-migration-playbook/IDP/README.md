# IDP Module - Mappings

## Overview
This folder contains mapping documentation for tables migrating to the **smac_idp_dev** database.

## Target Database
- **Database**: smac_idp_dev (local docs); **`07-orchestration/migration_config_smac_idp.json`** defines the real target (e.g. `navitasai_idp`) for runs.
- **Host**: localhost
- **Port**: 5432

## Module Purpose
The IDP (Identity Provider) module contains identity and access management data. These include:
- User accounts and authentication data
- Roles and permissions
- User-role assignments
- Company associations
- User-company relationships

## Table Count
The orchestration config lists **77** table entries for this module (**23** with `migration_enabled: true`). Sources include `identity_admin_prod` and related legacy DBs; see `07-orchestration/migration_config_smac_idp.json`.

**Mapping docs with migration scripts:** 32 (including `seafarer/` subfolder scripts). Regenerate from SQL via:

```powershell
python scripts/sync_mappings_from_migrations.py
```

**Pending mappings** (no migration script yet): OAuth/client tables (`clients`, `api_resources`, etc.), `user_tokens`, `persisted_grants`, and related IdentityServer configuration tables.

## Mapping Format
Each `{table}_mapping.md` is auto-generated from its corresponding script in `04-migration-scripts/idp/` and includes:
- Legacy → target path overview
- Business key (from orchestration config when available)
- Column mapping extracted from the main `INSERT` statement
- ID mapping lookup tables (`CREATE TEMP TABLE ...`) with SQL snippets
- Validation/rollback script references

## Migration Order
Run tables in **dependency order** as defined in the config (`dependencies` on each entry). Typical flows include identity clients, API resources/scopes, then user and role assignments, but the exact sequence is driven by the JSON—not a fixed five-table list.

## File Naming Convention
- Mapping files: `{table_name}_mapping.md`
- Example: `users_mapping.md`, `roles_mapping.md`

## Related Folders
- Migration scripts: `04-migration-scripts/idp/`
- Validation scripts: `05-validation/idp/`
- Rollback scripts: `06-rollback/idp/`

## Configuration
Table configuration is defined in `07-orchestration/migration_config_smac_idp.json`.

