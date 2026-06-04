# Staged Refactor Acceptance

## Stage 1: Configuration Foundation

- Committed templates and ignored local configuration added.
- Configurable non-default schema validated.
- Missing and inconsistent settings rejected.

## Stage 2: Application Schema Provisioning

- Standalone schema provisioning added.
- Common component privilege superset granted.
- Existing schema causes provisioning failure.

## Stage 3: AGENT Independence

- AGENT objects use `AGENT` and `PKG_AGENT_*` naming.
- Standalone AGENT installation and health smoke passed.
- No dependency on ARCHIVER or REPLICA.

## Stage 4: ARCHIVER Independence

- ARCHIVER owns utilities, logging, metadata, sequences, and targets.
- Standalone installation passed through a real AGENT link.
- Discovery, archive, quality, and truncate preview passed.

## Stage 5: REPLICA Independence

- REPLICA owns utilities, logging, metadata, sequences, and targets.
- Standalone installation passed through a real ARCHIVER link.
- Discovery, replication, quality, and purge preview passed.
- All REPLICA source links are real and non-null.

## Stage 6: Combined Installation

- AGENT, ARCHIVER, and REPLICA coexist in one configurable schema.
- Distinct loopback links preserve logical boundaries.
- Full combined smoke passed with no invalid objects or naming collisions.

## Stage 7: Distributed Installation

- Master topology provisioning and installation added.
- Multiple AGENT instances can feed one ARCHIVER.
- REPLICA reads the configured ARCHIVER database.
- Partial component installers and onboarding templates added.
- Distributed local simulation passed.

## Stage 8: Legacy Cleanup

- Legacy schemas, object names, installers, grants, seeds, and smokes removed.
- Root drop, reinstall, and smoke scripts use current configurable topology.
- Repository and database audits found no legacy dependencies.

## Stage 9: Documentation and Final Validation

- Documentation rewritten in English.
- Configuration, provisioning, standalone, combined, distributed, onboarding,
  and operations documented.
- Final fresh-install validation executed with non-default schema `PMGR_FINAL9`.
- Combined smoke completed with `COMBINED_SMOKE_OK`.
- Final state: 399 ARCHIVER rows, 149 REPLICA rows, zero invalid objects, and
  zero invalid REPLICA source links.
- Repository audits found no legacy references, missing SQL script references,
  or non-English documentation fragments.
