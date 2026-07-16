# Table Mapping: seafarer_profile

## Overview

Alias for `seafarer_profile`.

- **Canonical mapping**: [seafarer_profile_mapping.md](../crewing/seafarer_profile_mapping.md)
- **Migration Script**: `04-migration-scripts/crewing/seafarers_migration.sql`

## Migration Notes

- seafarer_profile is inserted in seafarers_migration.sql (combined migration).
- Post-migration update script: Migrates working_gear from SAC synergy_seafarer.public.working_gear (seafarer_attributes JSON) to SMAC seafarer_profile.working_gear. Expands seafarer_attributes array, matches name with smac_master_migration.crewing.working_gear, uses SMAC sizable (not legacy). WorkingGearUnitSize = 'Non-Sizable' if sizable=false, else measurement. Includes mismatch detection and validation. Must run AFTER seafarers and working_gear master migration.

See the canonical mapping document for full column-level detail (column mapping, ID mappings, transformation rules).
