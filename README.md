# CKB: Code Knowledge Base Specification

> ⚠️ **DRAFT v0.1 — UNSTABLE.** Breaking changes may happen in any `0.x` release without notice. Pin `"ckb_version": "0.1"` exactly. See [VERSIONING.md](VERSIONING.md).

CKB is an open, machine-readable format for describing **one repository at one commit**: its components, interfaces, dependencies, datastores, business rules, and workflows. Every claim cites its source line and states how confident the producer is.

A **producer** analyzes a codebase and writes a `ckb.json` artifact. A **consumer** reads many artifacts and joins them (for example into a cross-repo graph). Producers and consumers depend only on this spec, never on each other.

## Artifact at a glance

```json
{
  "ckb_version": "0.1",
  "repo": { "url": "...", "branch": "main", "commit_sha": "<40 hex>", "generated_at": "2026-09-30T12:00:00Z" },
  "generator": { "name": "...", "version": "..." },
  "confidence_summary": { "confirmed": 7, "inferred": 2, "unknown": 1, "overall": "inferred" },
  "entities": { "components": [], "interfaces": [], "dependencies": [], "datastores": [], "business_rules": [], "workflows": [] },
  "relations": []
}
```

- Schema: [`schema/v0.1/ckb.schema.json`](schema/v0.1/ckb.schema.json) (JSON Schema 2020-12)
- Examples: [`minimal.json`](schema/v0.1/examples/minimal.json), [`full.json`](schema/v0.1/examples/full.json)

## The five load-bearing guarantees

### 1. Repo identity
`repo.url` plus `repo.commit_sha` identify the artifact. `commit_sha` is the full lowercase SHA-1 (40 hex) or SHA-256 (64 hex); short SHAs are invalid. `generated_at` (RFC 3339) is the freshness signal.

### 2. Normalized join keys
Cross-repo intelligence is only possible if two repos describe the same thing identically. Producers MUST normalize as follows:

| Family | Field(s) | Normalization |
|---|---|---|
| Package | `dependency.package_key` | `npm:@scope/name`, `pypi:name`, `maven:group:artifact`, `go:module/path`, `cargo:name`, `nuget:Name`, `gem:name`, `other:<id>`. npm and pypi names are lowercase. pypi follows PEP 503 (runs of `-_.` collapse to `-`). |
| HTTP | `interface.http.{method, normalized_path}` | Method is uppercase. Path params become `{snake_case}` (`/users/:id` and `/users/123` both become `/users/{id}`). No trailing slash except `/`, and no query string. |
| Event | `interface.event.{transport, topic}` | Topic is written as it appears on the transport, without environment prefixes when they can be identified. |
| RPC | `interface.rpc.{protocol, service, method}` | For gRPC, `service` is the fully qualified proto service name. |
| Datastore | `datastore.{engine, schema, table}` | Lowercase identifiers unless the engine is case-sensitive. |
| Internal module | `component.module_id` | Repo-relative POSIX path. |

`interface.role` (`provides` or `consumes`) is what lets a consumer match a caller to a provider.

### 3. Provenance
Every entity and relation carries `provenance: [{path, line, end_line?}]`. Paths are repo-relative, with no leading `/` and no `..` segments. Provenance may be empty **only** when `confidence` is `unknown`.

### 4. Confidence
- `confirmed`: directly stated in code or config at the cited line.
- `inferred`: derived from structure or naming. It is plausible but not stated.
- `unknown`: the producer looked but could not determine the answer. It is recorded so consumers can see the gap.

`confidence_summary` counts every claim (entities plus relations) at each level. `overall` is the producer's roll-up judgement.

### 5. Stable entity IDs
IDs are `<type>:<key>` and MUST be deterministic: regenerating at the same commit yields the same IDs, so consumers can diff instead of re-keying.

| Type | ID key |
|---|---|
| `component` | `component:<module_id>` |
| `interface` (http) | `interface:http:<role>:<METHOD>:<normalized_path>` |
| `interface` (event) | `interface:event:<role>:<transport>:<topic>` |
| `interface` (rpc) | `interface:rpc:<role>:<service>/<method>` |
| `interface` (cli, library) | `interface:<kind>:<role>:<symbol>` |
| `dependency` | `dependency:<package_key>` |
| `datastore` | `datastore:<engine>:<schema>.<table>`, omitting any segments that are absent |
| `business_rule`, `workflow` | `<type>:<kebab-slug>`, where the slug comes from the rule or workflow name and collisions get `-2`, `-3`, … appended in order of first appearance |

Never derive IDs from array position, timestamps, or randomness.

## Conformance

An artifact conforms to CKB v0.1 when it:
1. validates against `schema/v0.1/ckb.schema.json`, **and**
2. passes semantic rules R1–R6 in [`tests/semantic.jq`](tests/semantic.jq):
   - **R1**: entity IDs are unique.
   - **R2**: each ID prefix matches its collection.
   - **R3**: every reference (`relations`, `applies_to`, `steps[].entity_id`) resolves to an entity in the same artifact.
   - **R4**: `confidence_summary` counts equal the actual claim counts.
   - **R5**: workflow step `order` values run 1..n with no gaps.
   - **R6**: `end_line` is not less than `line`.

Cross-repo references are **never** written as IDs. A consumer resolves them through join keys.

### Validate

Requires `jq` and [`uv`](https://docs.astral.sh/uv/).

```bash
tests/validate.sh                 # run the spec's own suite
tests/validate.sh path/to/ckb.json   # validate one artifact
```

## Extensions
Top-level keys starting with `x-` are allowed for vendor data and are ignored for conformance. Entity objects are closed in v0.1. Propose new fields by opening an issue.

## Contributing
Expressiveness gaps (things a real repo has that CKB cannot express) are the most valuable input during the draft phase. File them as issues with a minimal example. See the promotion criteria in [VERSIONING.md](VERSIONING.md).

## License
[MIT](LICENSE) © 2026 Riddhi Mohan Sharma
