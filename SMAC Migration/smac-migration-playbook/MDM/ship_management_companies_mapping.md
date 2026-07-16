# Table Mapping: ship_management_companies

## Overview

Alias for `companies`.

- **Canonical mapping**: [companies_mapping.md](companies_mapping.md)
- **Migration Script**: `04-migration-scripts/master/companies_migration.sql`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Ship Management Companies (`ship_management_companies` → `companies`)

## Migration Notes

- Legacy ship_management_companies rows are migrated in companies_migration.sql (with mlc_master).
- Main company information from ship_management_companies. Uses ship_management_companies_migration.sql script.

See the canonical mapping document for full column-level detail (column mapping, ID mappings, transformation rules).
