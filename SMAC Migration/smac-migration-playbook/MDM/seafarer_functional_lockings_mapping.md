# Table Mapping: seafarer_functional_lockings

## Overview

Alias for `seafarer_functional_lockings`.

- **Canonical mapping**: [seafarer_functional_lockings_mapping.md](../crewing/seafarer_functional_lockings_mapping.md)
- **Migration Script**: `04-migration-scripts/crewing/seafarer_functional_lockings_migration.sql`

## Business Key

- **Composite Key**: (`seafarer_id`, `id`)
- **Source (orchestration)**: Seafarer Functional Lockings (`seafarer_functional_lockings` → `seafarer_functional_lockings`)

## Migration Notes

- Migrates seafarer_functional_lockings from synergy_seafarer.public.seafarer_functional_lockings to smac_master_migration.shore.seafarer_functional_lockings. Preserves legacy UUID (id) as target id (Pattern A). Maps seafarer_id from bigint to uuid via migration.table_mappings from smac_crewing_migration database (seafarers table). Parses created_by_id and updated_by_id as UUID if valid format, otherwise NULL. stage_code set to NULL (not in source). payload mapped directly with fallback to empty JSONB. Uses standardized SMAC audit_info structure via migration.build_audit_info(). Requires seafarers table to be migrated first in crewing database.

See the canonical mapping document for full column-level detail (column mapping, ID mappings, transformation rules).
