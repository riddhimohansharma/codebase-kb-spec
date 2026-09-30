# Changelog

All notable changes to the CKB specification. Format: [Keep a Changelog](https://keepachangelog.com/). Versioning: see [VERSIONING.md](VERSIONING.md).

## [0.1] — 2026-09-30 — DRAFT

### Added
- **Canonical location** `<repo-root>/.ckb/ckb.json`: the KB is committed in the repo it describes.
- **Freshness rule**: fresh at `Y` if and only if nothing outside `.ckb/` changed since `commit_sha`.
- Semantic rule **R7**: no citations of `.ckb/` (no self-contamination).
- **Lock file** `ckb.lock.json` (`schema/v0.1/ckb-lock.schema.json`, rules L1–L2) so consumers can pin results across many repos.
- Artifact schema `schema/v0.1/ckb.schema.json` (JSON Schema 2020-12).
- Repo identity: `url`, `branch`, `commit_sha`, `generated_at`.
- Entity types: `component`, `interface`, `dependency`, `datastore`, `business_rule`, `workflow`; typed `relations`.
- Normalized join keys for packages, HTTP, events, RPC, datastores, internal modules.
- Mandatory provenance (`path`, `line`) on every claim unless confidence is `unknown`.
- Per-claim confidence (`confirmed | inferred | unknown`) and artifact-level `confidence_summary`.
- Deterministic entity ID rules.
- Semantic rules R1–R7 (`tests/semantic.jq`) and conformance suite (`tests/validate.sh`).
