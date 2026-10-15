# Changelog

## 2026-10-15
- Relicensed from CC BY-ND 4.0 to Apache-2.0 so organisations can adopt the standard and publish internal profiles. The Marks ("CKB", "Codebase Knowledge Base", "CKB-compatible") stay governed by TRADEMARKS.md; Apache-2.0 grants no trademark rights. Revisions published earlier remain available under their original terms (NOTICE added).

## 2026-10-10
- Canonical KB directory is `.ckb/` (was `ckb/`), so the KB is hidden at the repo root. `ckb_version` stays `0.2` (0.x policy).
- Breaking for lock files and R7: lock `artifact_path` is `.ckb/ckb.json`, and `ckb/ckb.json` is now rejected. Freshness excludes `.ckb` (was `ckb`).
- v0.1 schemas, lock examples and R7 fixtures updated to match.

## 2026-10-01
- Licensed under CC BY-ND 4.0; added TRADEMARKS.md. Contributions are not accepted.

## [0.2] — 2026-10-01
- Artifacts, services, config keys, external services, API specs; purl dependency identity.
- Consumes target in interface IDs; normative `derive.jq`; rules R8, R10–R12; coverage and repo profile.

## [0.1] — 2026-09-30
- Initial draft: canonical `ckb/` location, freshness rule, rules R1–R7, consumer lock file.
