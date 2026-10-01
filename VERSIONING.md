# Versioning Policy

## Version field
Every artifact declares `"ckb_version"`. A consumer MUST reject, or explicitly downgrade its handling of, any version it does not recognize.

## Draft: `0.x` (current)
> **Unstable. Breaking changes may land in any `0.x` release without notice or deprecation window.**

Producers and consumers that target `0.x` must pin the exact version (for example `"0.2"`) and expect to update on each release.

## Stable: `1.0` and later (Semantic Versioning)
| Change | Bump |
|---|---|
| Remove or rename a field; tighten a constraint; change ID derivation; change an enum's meaning | **major** |
| Add an optional field, enum value, entity type, or relation kind | **minor** |
| Clarify wording, fix examples, add tests | **patch** |

Major versions get a **deprecation window of ≥ 6 months**: the previous major stays documented and its schema stays published under `schema/v<N>/`. Consumers SHOULD accept the current and previous major during that window.

Adding an enum value is minor, so consumers MUST treat unknown enum values as `other`/opaque rather than failing.

## Promotion from `0.x` to `1.0`
All of these must hold, with evidence linked in the release notes:
1. Validated against **≥ 3 diverse real repositories** (different languages or shapes: a small single-language repo, an HTTP service, a multi-module codebase).
2. **≥ 1 working consumer** answers cross-repo queries over those artifacts using only join keys defined here.
3. **No open expressiveness gaps**: every gap filed as an issue is either resolved or explicitly deferred with written rationale.
4. Regenerating an artifact at the same commit yields identical entity IDs.

## Extensions
Keys beginning with `x-` are reserved for vendor extensions (top level only in v0.1; also on every entity and relation from v0.2). They never affect conformance, and consumers MUST ignore any they do not understand.
