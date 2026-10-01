# CKB: Codebase Knowledge Base Specification

> ⚠️ **DRAFT v0.2 — UNSTABLE.** Breaking changes may happen in any `0.x` release without notice. Pin `"ckb_version": "0.2"` exactly. See [VERSIONING.md](VERSIONING.md).

CKB is an open, machine-readable format for describing **one repository at one commit**: what it is made of (components), what it exposes and calls (interfaces), what it consumes (dependencies, datastores, config keys, external services) and what it publishes and runs as (artifacts, services). Every claim cites its source line and states how confident the producer is.

A **producer** analyzes a codebase and writes a `ckb.json` artifact. A **consumer** reads many artifacts and joins them (for example into a cross-repo graph). Producers and consumers depend only on this spec, never on each other.

## Artifact at a glance

```json
{
  "ckb_version": "0.2",
  "repo": { "url": "https://github.com/example/orders-service", "branch": "main", "commit_sha": "<40 hex>", "generated_at": "2026-09-30T12:00:00Z" },
  "generator": { "name": "...", "version": "..." },
  "repo_profile": { "languages": [], "frameworks": [], "build_tools": [], "license": "MIT", "owners": [] },
  "coverage": { "files_total": 142, "sampled": false, "buckets": {} },
  "confidence_summary": { "confirmed": 47, "inferred": 7, "unknown": 1, "overall": "inferred" },
  "entities": {
    "components": [], "interfaces": [], "dependencies": [], "datastores": [], "business_rules": [], "workflows": [],
    "artifacts": [], "services": [], "config_keys": [], "external_services": [], "api_specs": []
  },
  "relations": []
}
```

- Schema: [`schema/v0.2/ckb.schema.json`](schema/v0.2/ckb.schema.json) (JSON Schema 2020-12)
- ID derivation: [`schema/v0.2/derive.jq`](schema/v0.2/derive.jq) (normative, executable)
- Semantic rules: [`schema/v0.2/semantic.jq`](schema/v0.2/semantic.jq)
- Lock schema (for consumers): [`schema/v0.2/ckb-lock.schema.json`](schema/v0.2/ckb-lock.schema.json)
- Examples: [`minimal.json`](schema/v0.2/examples/minimal.json), [`full.json`](schema/v0.2/examples/full.json) (every collection and every relation kind)

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

## The load-bearing guarantees

### 1. Repo identity
`repo.url` plus `repo.commit_sha` identify the artifact. `repo.url` is **canonical** so two producers name the same repo identically:

- `https://<lowercase-host>/<path>`: no credentials, no trailing `/`, no `.git` suffix.
- SSH remotes are rewritten: `git@github.com:o/r.git` becomes `https://github.com/o/r`.
- Local-only repos use `file://<absolute-path>`.

`commit_sha` is the full lowercase SHA-1 (40 hex) or SHA-256 (64 hex); short SHAs are invalid. `generated_at` (RFC 3339) is the freshness signal.

### 2. Entities

Every entity has `id`, `name`, optional `description`, `confidence` and `provenance`, plus the type-specific fields below (`*` = required). Entity objects are closed: unknown fields are rejected, except `x-` extensions.

| Collection | Type-specific fields |
|---|---|
| `components` | `module_id*` (repo path), `kind*` (`service` `library` `module` `cli` `ui` `job` `other`), `language` |
| `interfaces` | `kind*` (`http` `event` `rpc` `cli` `library` `websocket`), `role*` (`provides` `consumes`), `service_key` (provides: the logical service serving it), and the block for its kind: `http{method*, normalized_path*, host}`, `websocket{normalized_path*, host}`, `event{transport*, topic*}`, `rpc{protocol*, service*, method*}`, or `symbol*` (cli, library) |
| `dependencies` | `purl*` (versionless), `manifest_path*`, `scope*` (`runtime` `dev` `build` `test` `peer` `optional`), `source*` (`registry` `workspace` `git` `path` `vendored` `unknown`), `version_constraint`, `resolved_version` |
| `datastores` | `engine*`, `access*` (`read` `write` `readwrite`), `instance_key`, `schema`, `table` |
| `business_rules` | `statement*`, `applies_to` (entity ids) |
| `workflows` | `steps*` (`[{order*, description*, entity_id}]`, at least one), `trigger` |
| `artifacts` | **what the repo publishes**: `kind*` (`package` `container_image` `helm_chart` `binary` `terraform_module` `function` `static_site` `other`), `purl*` (versionless), `manifest_path*`, `version` |
| `services` | **deployable runtime unit**: `service_key*` (lowercase kebab), `runtime*` (`k8s` `ecs` `lambda` `cloudrun` `vm` `container` `serverless` `other`), `ports`, `environments` |
| `config_keys` | `name*`, `source*` (`env` `file` `vault` `aws_ssm` `aws_secrets_manager` `k8s_secret` `k8s_configmap` `other`), `is_secret*`. **Names only, never values.** A `value` field is a schema error. |
| `external_services` | third-party SaaS/API: `domain*` (lowercase host), `category*`, `vendor` |
| `api_specs` | `path*` (repo path), `format*` (`openapi` `swagger` `proto` `graphql_sdl` `asyncapi` `avro` `jsonschema` `wsdl` `other`), `version` |

`datastore.instance_key` is the logical database or cluster name, or the **name** of the environment variable that holds the connection string. It is never the value: anything containing `:`, `/` or `@` is rejected, so a connection string cannot leak into a KB.

### 3. Normalized join keys
Cross-repo intelligence only works if two repos describe the same thing identically. Producers MUST normalize as follows:

| Family | Field(s) | Normalization |
|---|---|---|
| Package | `dependency.purl`, `artifact.purl` | [Package URL](https://github.com/package-url/purl-spec) **without** version, qualifiers or subpath: `pkg:npm/%40scope/name`, `pkg:maven/group/artifact`, `pkg:pypi/name`, `pkg:golang/github.com/x/y`, `pkg:cargo/x`, `pkg:nuget/x`, `pkg:gem/x`, `pkg:composer/vendor/name`, `pkg:docker/library/nginx`, `pkg:github/actions/checkout`, `pkg:terraform/hashicorp/aws`, `pkg:helm/repo/chart`, `pkg:generic/x`, and so on. A literal `@` is invalid (an npm scope is `%40`); the version lives in `version_constraint` / `resolved_version` / `artifact.version`. |
| HTTP | `interface.http.{method, normalized_path, host}` | Method is uppercase. Path params become `{snake_case}` (`/users/:id` and `/users/123` both become `/users/{id}`). No trailing slash except `/`, and no query string. `host` (consumes) is the target's `service_key` when known, otherwise its lowercase host. |
| WebSocket | `interface.websocket.{normalized_path, host}` | As HTTP. |
| Event | `interface.event.{transport, topic}` | Topic is written as it appears on the transport, without environment prefixes when they can be identified. |
| RPC | `interface.rpc.{protocol, service, method}` | For gRPC, `service` is the fully qualified proto service name. |
| Service | `service.service_key`, `interface.service_key` | Lowercase kebab-case logical name. |
| Datastore | `datastore.{engine, instance_key, schema, table}` | Lowercase identifiers unless the engine is case-sensitive. |
| External | `external_service.domain` | Lowercase host, no scheme or port. |
| Internal module | `component.module_id` | Repo-relative POSIX path. |

`interface.role` (`provides` or `consumes`) is what lets a consumer match a caller to a provider.

### 4. Provider side: resolving "repo A depends on X" to "repo B builds X"
v0.1 described only what a repo consumes. v0.2 also describes what it **provides**, so a consumer can close the loop across repos without any repo naming another:

| Repo A says (consumer side) | Repo B says (provider side) | Consumer joins on |
|---|---|---|
| `dependency.purl = pkg:npm/%40example/orders-client` | `artifact.purl = pkg:npm/%40example/orders-client` (and `component -builds-> artifact`) | equal `purl` (both versionless) |
| `interface` `consumes` `http{host: "orders-service", method, normalized_path}` | `service.service_key = "orders-service"` with `service -exposes-> interface` `provides` (`service_key: "orders-service"`) | `host == service_key`, then `method` + `normalized_path` |
| `interface` `consumes` `event{transport, topic}` | `interface` `provides` `event{transport, topic}` | `transport` + `topic` |
| `interface` `consumes` `rpc{protocol, service, method}` | `interface` `provides` `rpc{...}` | `protocol` + `service` + `method` |

So "repo A depends on `pkg:npm/%40example/orders-client`" becomes "repo A depends on repo B" because repo B's artifact has the same purl. The purl is versionless on both sides, so the join never breaks on a version bump. Version skew is visible by comparing `resolved_version` with `artifact.version`. Cross-repo references are **never** written as IDs inside an artifact.

### 5. Provenance
Every entity and relation carries `provenance: [{path, line, end_line?}]`. Paths are repo-relative, with no leading `/` and no `..` segments. Provenance may be empty **only** when `confidence` is `unknown`.

### 6. Confidence
- `confirmed`: directly stated in code or config at the cited line.
- `inferred`: derived from structure or naming. It is plausible but not stated.
- `unknown`: the producer looked but could not determine the answer. It is recorded so consumers can see the gap.

`confidence_summary` counts every claim (entities plus relations) at each level. `overall` is the producer's roll-up judgement.

### 7. Stable entity IDs
IDs MUST be deterministic: regenerating at the same commit yields the same IDs, so consumers can diff instead of re-keying. In v0.2 the derivation is **executable**: [`schema/v0.2/derive.jq`](schema/v0.2/derive.jq) defines `ckb_derive_id($collection)`, and rule R8 checks every ID against it. Producers SHOULD include the same file rather than re-implement it.

| Collection | ID |
|---|---|
| `components` | `component:<module_id>` |
| `interfaces` (http) | `interface:http:<role>:<P>:<METHOD>:<normalized_path>` |
| `interfaces` (websocket) | `interface:websocket:<role>:<P>:<normalized_path>` |
| `interfaces` (event) | `interface:event:<role>:<transport>:<topic>` |
| `interfaces` (rpc) | `interface:rpc:<role>:<protocol>:<service>/<method>` |
| `interfaces` (cli, library) | `interface:<kind>:<role>:<symbol>` |
| `dependencies` | `dependency:<purl>@<manifest_path>` |
| `artifacts` | `artifact:<purl>` |
| `services` | `service:<service_key>` |
| `config_keys` | `config:<source>:<name>` |
| `external_services` | `external:<domain>` |
| `api_specs` | `api_spec:<path>` |
| `datastores` | `datastore:<engine>:<instance_key or _>:<schema.table, table, schema, or slug(name)>` |
| `business_rules`, `workflows` | `<type>:<kebab-slug>` from the name. Collisions get `-2`, `-3`, … in **(slug, name, first provenance)** order, independent of draft order. Only the prefix is checked. |

`P`, the **consumes target**, is part of the interface ID: `service_key` for `provides`, `http.host` / `websocket.host` for `consumes`, and `_` when unknown. Two clients in the same repo calling `POST /payments` on different services are therefore two distinct interfaces. A dependency ID includes its `manifest_path`, so one package declared in two manifests of a monorepo is two entities.

Never derive IDs from array position, timestamps, or randomness.

### 8. Relations

A relation is `{from*, to*, kind*}` plus `confidence` and `provenance`. Only these `(from type, kind, to type)` triples are allowed (R10):

| `kind` | from | to | Extra condition |
|---|---|---|---|
| `contains` | component | component | |
| `imports` | component | component | |
| `depends_on` | component | dependency, component | |
| `provides` | component | interface | interface `role` is `provides` |
| `consumes` | component | interface | interface `role` is `consumes` |
| `calls` | component | interface | legacy alias of `consumes` (same role check) |
| `reads`, `writes` | component, interface | datastore | |
| `publishes`, `subscribes` | component | interface | interface `kind` is `event` or `websocket` |
| `enforces` | component, interface | business_rule | |
| `builds` | component | artifact | |
| `deploys_as` | component | service | |
| `exposes` | service | interface | |
| `configured_by` | component, service, interface, datastore | config_key | |
| `uses_external` | component, interface | external_service | |
| `specified_by` | interface | api_spec | |

The table is also machine-readable as `ckb_relation_rules` in `derive.jq`.

### 9. Repository profile and coverage

`repo_profile` (optional) records repository-level facts: `languages` (`[{name, files}]`), `frameworks`, `build_tools`, `license` (SPDX identifier or expression), and `owners` (`[{name, source}]`, where `source` is `codeowners`, `catalog-info`, `manifest` or `other`).

`coverage` (optional) records what the producer looked at, so a consumer can tell **"none exist"** from **"not examined"**:

```json
"coverage": { "files_total": 142, "sampled": false,
  "buckets": { "routes": { "found": 3, "cited": 2, "uncited": ["src/orders/admin-routes.ts"] } } }
```

Bucket names are fixed: `manifests`, `lockfiles`, `routes`, `events`, `datastores`, `migrations`, `iac`, `ci`, `config`, `api_specs`. A producer includes the buckets it measured. Per bucket, `found` is the number of files of that kind, `cited` is how many of them at least one claim cites, and `uncited` lists the rest (at most 200 paths). `sampled: true` means the producer did not read every file.

## Conformance

An artifact conforms to CKB v0.2 when it:
1. validates against `schema/v0.2/ckb.schema.json`, **and**
2. passes the semantic rules in [`schema/v0.2/semantic.jq`](schema/v0.2/semantic.jq):
   - **R1**: entity IDs are unique.
   - **R2**: each ID prefix matches its collection.
   - **R3**: every reference (`relations`, `applies_to`, `steps[].entity_id`) resolves to an entity in the same artifact.
   - **R4**: `confidence_summary` counts equal the actual claim counts (entities plus relations).
   - **R5**: workflow step `order` values run 1..n with no gaps.
   - **R6**: `end_line` is not less than `line`.
   - **R7**: nothing points into `ckb/`: no provenance path, component `module_id`, dependency or artifact `manifest_path`, or `api_spec` path. The KB never describes itself.
   - **R8**: every ID equals `ckb_derive_id(<collection>)` from `derive.jq`, for all collections except `business_rules` and `workflows`.
   - **R9**: reserved (not assigned in v0.2).
   - **R10**: every relation is an allowed `(from type, kind, to type)` triple, with the role and kind conditions in the relation table.
   - **R11**: relations are unique by `(from, kind, to)`.
   - **R12**: for each `coverage` bucket, `cited <= found` and `len(uncited) <= found`.

Each violation is reported as a string that starts with its rule code.

### Validate

Requires `jq` (1.6 or later) and [`uv`](https://docs.astral.sh/uv/).

```bash
tests/validate.sh                    # run the spec's own suite (v0.1 and v0.2)
tests/validate.sh path/to/ckb.json   # validate one artifact; the schema is chosen by its ckb_version
```

To run only the v0.2 semantic rules: `jq -L schema/v0.2 -f schema/v0.2/semantic.jq ckb.json` (prints `[]` when it passes).

## Consuming at scale: `ckb.lock.json`

A consumer that builds a view across many repositories MUST pin exactly what it ingested so the result is reproducible. For each repo it records one lock entry ([schema](schema/v0.2/ckb-lock.schema.json), [example](schema/v0.2/lock-examples/two-repos.json)):

| Field | Meaning |
|---|---|
| `repo_url`, `ref` | Where the artifact was read (canonical, credentials stripped) |
| `kb_commit` | The commit the consumer read `ckb/ckb.json` from |
| `analysed_commit_sha` | The artifact's `repo.commit_sha` |
| `ckb_version` | The artifact's `ckb_version` |
| `artifact_sha256` | Hash of the exact bytes ingested |
| `freshness` | The freshness rule evaluated at `kb_commit` |

Lock rules ([`tests/lock-semantic.jq`](tests/lock-semantic.jq), shared by v0.1 and v0.2): **L1**, one entry per `(repo_url, ref)`; **L2**, entries sorted by `(repo_url, ref)` so lock diffs stay minimal. To upgrade, a consumer re-reads each repo's `ckb/ckb.json` and rewrites only the entries that changed. The same lock file therefore reproduces the same cross-repo result, the way a package lockfile does. A v0.2 lock may pin artifacts of different `ckb_version`s.

Producers never read or write lock files.

## Extensions
Keys starting with `x-` are vendor extensions and are ignored for conformance. In v0.2 they are allowed at the top level, on every entity and on every relation (for example `"x-owner-team": "orders"` on a component). Any other unknown field is a schema error. Propose new fields by opening an issue.

## Previous version: v0.1 (superseded)
[`schema/v0.1/`](schema/v0.1/ckb.schema.json) stays published unchanged, with its semantic rules in [`tests/semantic.jq`](tests/semantic.jq) (R1–R7). v0.1 had six entity types, keyed dependencies by `package_key` (`npm:@scope/name`), used interface IDs without the consumes target, and had no provider side. `tests/validate.sh` still checks v0.1 artifacts.

## Contributing
Expressiveness gaps (things a real repo has that CKB cannot express) are the most valuable input during the draft phase. File them as issues with a minimal example. See the promotion criteria in [VERSIONING.md](VERSIONING.md).

## License and trademarks

- **Specification:** [CC BY-ND 4.0](LICENSE) © 2026 Riddhi Mohan Sharma. You may implement CKB in any software, including commercial software, and redistribute the spec **unmodified** with attribution. **Modified or extended versions may not be distributed without permission.** Vendor data belongs in `x-` fields.
- **Names:** "CKB", "Codebase Knowledge Base" and "CKB-compatible" are governed by [TRADEMARKS.md](TRADEMARKS.md). "CKB-compatible" requires passing the conformance suite.
- **Changes:** the spec has a single editor and accepts no contributions. Open an issue to report a gap (see [CONTRIBUTING.md](CONTRIBUTING.md)).
- Revisions up to and including commit `39c5392` were published under MIT.
