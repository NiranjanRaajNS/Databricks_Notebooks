# Table Mapping: owners

## Overview

Alias for `vessel_owners`.

- **Canonical mapping**: [vessel_owners_mapping.md](vessel_owners_mapping.md)
- **Migration Script**: `04-migration-scripts/master/vessel_owners_migration.sql`

## Business Key

- **Business Key**: `code`
- **Source (orchestration)**: Vessel Owners (`vessel_owners` → `owners`)

## Migration Notes

- Migrates vessel_owners preserving identifier/uuid UUID as id if available, otherwise generates new UUIDs. Master reference table referenced by vessels table via owner_id.

See the canonical mapping document for full column-level detail (column mapping, ID mappings, transformation rules).
