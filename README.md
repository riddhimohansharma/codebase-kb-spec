# CKB: Codebase Knowledge Base Specification

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
- Lock schema (for consumers): [`schema/v0.1/ckb-lock.schema.json`](schema/v0.1/ckb-lock.schema.json)
- Examples: [`minimal.json`](schema/v0.1/examples/minimal.json), [`full.json`](schema/v0.1/examples/full.json)

## Location: the KB lives in the repo

A CKB is **committed inside the repository it describes**, at a fixed, well-known path, so the knowledge base is versioned with the code and any consumer can find it in any repo without running a producer. The folder is deliberately **not** a dot-folder: it is documentation meant to be read, so it must show up in Finder, Explorer and `ls`, as well as on GitHub and in IDEs.

```
<repo-root>/ckb/
├── ckb.json          # the artifact (this spec)  ← canonical, REQUIRED
├── manifest.json     # producer job record (optional, producer-defined)
├── README.md         # human index (optional)
└── *.md              # human-readable docs (optional)
```

- Producers MUST write only inside `ckb/`, and MUST NOT analyse or cite `ckb/` itself (see R7).
- Producers SHOULD NOT commit. A person or CI commits `ckb/`, which keeps generation read-only.
- A repo analysed without write access (for example a third-party clone) produces the same layout elsewhere. It is simply not committed.

## Freshness: `commit_sha` and the committed KB

`repo.commit_sha` is the **source commit that was analysed**. Committing `ckb/` creates a new commit, which is expected. The artifact is still accurate because only the KB changed.

> **Freshness rule.** An artifact is **fresh at commit `Y`** if and only if
> `git diff --quiet <commit_sha> Y -- . ':(exclude)ckb'` succeeds, meaning no file outside `ckb/` changed between the analysed commit and `Y`. Otherwise it is **stale**. If `commit_sha` is not an ancestor of `Y` or not present, it is **unknown**.

Producers use this rule to skip regeneration when nothing changed. Consumers use it to decide whether to trust or re-request an artifact. Because the rule excludes `ckb/`, committing the KB never makes it stale.

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
| `datastore` | `datastore:<engine>:<schema>.<table>`, omitting absent segments. If both are absent, use `datastore:<engine>:<kebab-slug(name)>` so unnamed stores don't collide |
| `business_rule`, `workflow` | `<type>:<kebab-slug>` from the name. Collisions get `-2`, `-3`, … in **(slug, name, first provenance path, line, statement)** order, independent of draft order. A name with no ASCII slug uses `u-<codepoints>` |

Never derive IDs from array position, timestamps, or randomness.

## Conformance

An artifact conforms to CKB v0.1 when it:
1. validates against `schema/v0.1/ckb.schema.json`, **and**
2. passes semantic rules R1–R7 in [`tests/semantic.jq`](tests/semantic.jq):
   - **R1**: entity IDs are unique.
   - **R2**: each ID prefix matches its collection.
   - **R3**: every reference (`relations`, `applies_to`, `steps[].entity_id`) resolves to an entity in the same artifact.
   - **R4**: `confidence_summary` counts equal the actual claim counts.
   - **R5**: workflow step `order` values run 1..n with no gaps.
   - **R6**: `end_line` is not less than `line`.
   - **R7**: no provenance path, and no component `module_id`, points into `ckb/`. The KB never describes itself.

Cross-repo references are **never** written as IDs. A consumer resolves them through join keys.

### Validate

Requires `jq` and [`uv`](https://docs.astral.sh/uv/).

```bash
tests/validate.sh                 # run the spec's own suite
tests/validate.sh path/to/ckb.json   # validate one artifact
```

## Consuming at scale: `ckb.lock.json`

A consumer that builds a view across many repositories MUST pin exactly what it ingested so the result is reproducible. For each repo it records one lock entry ([schema](schema/v0.1/ckb-lock.schema.json), [example](schema/v0.1/lock-examples/two-repos.json)):

| Field | Meaning |
|---|---|
| `repo_url`, `ref` | Where the artifact was read (credentials stripped) |
| `kb_commit` | The commit the consumer read `ckb/ckb.json` from |
| `analysed_commit_sha` | The artifact's `repo.commit_sha` |
| `artifact_sha256` | Hash of the exact bytes ingested |
| `freshness` | The freshness rule evaluated at `kb_commit` |

Lock rules: **L1**, one entry per `(repo_url, ref)`; **L2**, entries sorted by `(repo_url, ref)` so lock diffs stay minimal. To upgrade, a consumer re-reads each repo's `ckb/ckb.json` and rewrites only the entries that changed. The same lock file therefore reproduces the same cross-repo result, the way a package lockfile does.

Producers never read or write lock files.

## Extensions
Top-level keys starting with `x-` are allowed for vendor data and are ignored for conformance. Entity objects are closed in v0.1. Propose new fields by opening an issue.

## Contributing
Expressiveness gaps (things a real repo has that CKB cannot express) are the most valuable input during the draft phase. File them as issues with a minimal example. See the promotion criteria in [VERSIONING.md](VERSIONING.md).

## License
[MIT](LICENSE) © 2026 Riddhi Mohan Sharma
