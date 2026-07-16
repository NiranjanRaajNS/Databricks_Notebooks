# Table Mapping: training_type

## Overview

Alias for `training_types`.

- **Canonical mapping**: [training_types_mapping.md](training_types_mapping.md)
- **Migration Script**: `04-migration-scripts/master/training_types_migration.sql`

## Business Key

- **Business Key**: `name`
- **Source (orchestration)**: Training Types (`training_types` → `training_type`)

## Migration Notes

- Migrates training_types from synergy_training.public.training_types to smac_crewing_migration.crewing.training_type. Preserves legacy UUID (id) as target id using migration.resolve_target_id(). Generates code using generate_meaningful_code() from name. Maps status based on deleted_at (NULL=0 Active, NOT NULL=3 Deleted). Converts timestamps from timestamp with time zone to timestamp without time zone. Stores created_by_id, updated_by_id, deleted_by_id, created_by_name, updated_by_name, deleted_by_name in audit_info JSONB. Uses standardized SMAC audit_info structure. This is a master/reference table that must be migrated before training_master.

See the canonical mapping document for full column-level detail (column mapping, ID mappings, transformation rules).
