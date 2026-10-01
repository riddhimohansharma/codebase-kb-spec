# Changelog

All notable changes to the CKB specification. Format: [Keep a Changelog](https://keepachangelog.com/). Versioning: see [VERSIONING.md](VERSIONING.md).

## [0.2] — 2026-09-30 — DRAFT

v0.1 stays published unchanged under `schema/v0.1/`.

### Added
- **Provider side**: new entity types `artifacts` (what a repo publishes, keyed by purl) and `services` (deployable runtime units, keyed by `service_key`), plus `config_keys` (names only, never values), `external_services` (third-party SaaS by domain) and `api_specs`.
- New relation kinds `imports`, `builds`, `deploys_as`, `exposes`, `configured_by`, `uses_external`, `specified_by`.
- `websocket` interface kind; `interface.service_key` for provided interfaces; more event transports (`kinesis`, `servicebus`, `pulsar`, `mqtt`) and datastore engines (`azure-blob`, `cassandra`, `bigquery`, `snowflake`, `clickhouse`, `neo4j`, `cosmosdb`, `firestore`); `datastore.instance_key`.
- Dependency fields `manifest_path`, `source` and `resolved_version`.
- Optional top-level `repo_profile` (languages, frameworks, build tools, SPDX license, owners) and `coverage` (fixed buckets with found/cited/uncited counts).
- **Executable ID derivation** `schema/v0.2/derive.jq` (`ckb_derive_id`, `ckb_relation_rules`), included by the semantic rules.
- Semantic rules **R8** (ID equals derived ID), **R10** (allowed relation triples, role and kind checks), **R11** (unique relations), **R12** (coverage consistency); R7 also covers `manifest_path` and `api_spec` paths. R9 is reserved.
- `x-` extension fields on every entity and relation.
- Lock schema `schema/v0.2/ckb-lock.schema.json` (`ckb_lock_version` `"0.2"`).
- `tests/validate.sh` runs the v0.1 and v0.2 suites; single-file mode picks the schema from `ckb_version`; v0.2 semantic fixtures named `rN-*.json` must fail rule RN only.

### Changed (breaking)
- **Dependency identity is a versionless Package URL** (`purl`, e.g. `pkg:npm/%40scope/name`), replacing `package_key`. Dependency IDs are `dependency:<purl>@<manifest_path>`.
- **Interface IDs include the target**: `interface:http:<role>:<service_key | host | _>:<METHOD>:<path>`; RPC IDs include the protocol.
- Datastore IDs include `instance_key` (or `_`): `datastore:<engine>:<instance_key|_>:<schema.table|table|schema|slug(name)>`.
- `repo.url` must be canonical: `https://<lowercase-host>/<path>` with no credentials and no `.git`, or `file://<abs>`.
- Entity and relation IDs and references may use the new prefixes `artifact:`, `service:`, `config:`, `external:`, `api_spec:`.

## [0.1] — 2026-09-30 — DRAFT

### Changed
- **Canonical location is now `<repo-root>/ckb/`** (was `.ckb/`), so the KB is visible in Finder, Explorer and `ls`. The freshness rule's pathspec, rule R7 and the lock file's `artifact_path` (`ckb/ckb.json`) follow. Draft 0.x permits this breaking change.
- Repository renamed from `ckb-spec` to **`codebase-kb-spec`** to match the codebase-kb-* family. Schema `$id`s now use the new URL. The format name (CKB), `ckb.json` and `ckb_version` are unchanged.


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
- Deterministic entity ID rules. Unnamed datastores use a slug of the name, and slug collisions are ordered by content, not by draft order.
- Semantic rules R1–R7 (`tests/semantic.jq`) and conformance suite (`tests/validate.sh`).
