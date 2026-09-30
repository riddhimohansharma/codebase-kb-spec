# Changelog

All notable changes to the CKB specification. Format: [Keep a Changelog](https://keepachangelog.com/). Versioning: see [VERSIONING.md](VERSIONING.md).

## [0.1] — 2026-09-30 — DRAFT

### Added
- Artifact schema `schema/v0.1/ckb.schema.json` (JSON Schema 2020-12).
- Repo identity: `url`, `branch`, `commit_sha`, `generated_at`.
- Entity types: `component`, `interface`, `dependency`, `datastore`, `business_rule`, `workflow`; typed `relations`.
- Normalized join keys for packages, HTTP, events, RPC, datastores, internal modules.
- Mandatory provenance (`path`, `line`) on every claim unless confidence is `unknown`.
- Per-claim confidence (`confirmed | inferred | unknown`) and artifact-level `confidence_summary`.
- Deterministic entity ID rules.
- Semantic rules R1–R6 (`tests/semantic.jq`) and conformance suite (`tests/validate.sh`).
