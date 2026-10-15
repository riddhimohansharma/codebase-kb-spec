#!/usr/bin/env bash
# Validate CKB artifacts: JSON Schema (structural) + semantic rules (cross-reference rules, jq).
# Usage: tests/validate.sh                 -> run the spec's own test suite for every published version (v0.1, v0.2, v0.3)
#        tests/validate.sh <artifact.json>  -> validate one artifact against the schema named by its ckb_version
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v jq >/dev/null || { echo "jq required" >&2; exit 2; }
command -v uvx >/dev/null || { echo "uvx required (https://docs.astral.sh/uv/)" >&2; exit 2; }
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT

use_version() {  # sets SCHEMA, LOCK, FIXTURES and the semantic command for one spec version (v0.1 | v0.2 | v0.3)
  VER="$1"; SCHEMA="$ROOT/schema/$VER/ckb.schema.json"; LOCK="$ROOT/schema/$VER/ckb-lock.schema.json"
  case "$VER" in
    v0.1) FIXTURES="$ROOT/tests"; SEM=(jq -r -f "$ROOT/tests/semantic.jq") ;;
    *)    FIXTURES="$ROOT/tests/$VER"; SEM=(jq -r -L "$ROOT/schema/$VER" -f "$ROOT/schema/$VER/semantic.jq") ;;
  esac
}
structural() { uvx --quiet check-jsonschema --schemafile "$SCHEMA" "$1" >/dev/null 2>&1; }
structural_verbose() { uvx --quiet check-jsonschema --schemafile "$SCHEMA" "$1"; }
semantic() { "${SEM[@]}" "$1"; }
lockcheck() { uvx --quiet check-jsonschema --schemafile "$LOCK" "$1" >/dev/null 2>&1; }
locksem() { jq -f "$ROOT/tests/lock-semantic.jq" "$1"; }

check_one() {  # prints violations; returns 0 iff valid
  local f="$1" rc=0 v
  structural_verbose "$f" || rc=1
  v="$(semantic "$f" | jq -r '.[]')" || rc=1
  [ -n "$v" ] && { echo "$v"; rc=1; }
  return $rc
}

if [ $# -ge 1 ]; then
  v="$(jq -r '.ckb_version // empty' "$1" 2>/dev/null)" || { echo "FAIL $1 is not JSON" >&2; exit 1; }
  [ -n "$v" ] && [ -f "$ROOT/schema/v$v/ckb.schema.json" ] || { echo "FAIL $1: unsupported ckb_version '${v}'" >&2; exit 1; }
  use_version "v$v"
  check_one "$1" && echo "PASS $1"; exit $?
fi

fail=0
for VER in v0.1 v0.2 v0.3; do
  use_version "$VER"
  echo "--- $VER"
  uvx --quiet check-jsonschema --check-metaschema "$SCHEMA" >/dev/null || { echo "FAIL schema is not valid 2020-12"; fail=1; }
  for f in "$ROOT"/schema/"$VER"/examples/*.json; do
    if check_one "$f" >"$TMP" 2>&1; then echo "PASS valid   $(basename "$f")"; else echo "FAIL valid   $(basename "$f")"; cat "$TMP"; fail=1; fi
  done
  for f in "$FIXTURES"/invalid/*.json; do
    if structural "$f"; then echo "FAIL reject  $(basename "$f") (schema accepted it)"; fail=1; else echo "PASS reject  $(basename "$f")"; fi
  done
  for f in "$FIXTURES"/invalid-semantic/*.json; do
    b="$(basename "$f")"
    structural "$f" || { echo "FAIL fixture $b must be schema-valid"; fail=1; continue; }
    out="$(semantic "$f")" || { echo "FAIL fixture $b semantic rules errored"; fail=1; continue; }
    if [ "$(jq length <<<"$out")" -eq 0 ]; then echo "FAIL reject  $b [semantic accepted it]"; fail=1; continue; fi
    # Fixtures named rN-*.json must be rejected by rule RN and by nothing else.
    if [[ "$b" =~ ^r([0-9]+)- ]]; then
      rule="R${BASH_REMATCH[1]}"
      other="$(jq -r --arg r "$rule " '.[] | select(startswith($r) | not)' <<<"$out")"
      if [ -n "$other" ]; then echo "FAIL reject  $b [expected only $rule]"; echo "$other"; fail=1; continue; fi
      echo "PASS reject  $b [semantic $rule]"
    else
      echo "PASS reject  $b [semantic]"
    fi
  done
  uvx --quiet check-jsonschema --check-metaschema "$LOCK" >/dev/null || { echo "FAIL lock schema is not valid 2020-12"; fail=1; }
  for f in "$ROOT"/schema/"$VER"/lock-examples/*.json; do
    if lockcheck "$f" && [ "$(locksem "$f" | jq length)" = 0 ]; then echo "PASS valid   $(basename "$f") [lock]"; else echo "FAIL valid   $(basename "$f") [lock]"; fail=1; fi
  done
  for f in "$FIXTURES"/invalid-lock/*.json; do
    [ -e "$f" ] || continue
    if lockcheck "$f"; then echo "FAIL reject  $(basename "$f") [lock] (schema accepted it)"; fail=1; else echo "PASS reject  $(basename "$f") [lock]"; fi
  done
  for f in "$FIXTURES"/invalid-lock-semantic/*.json; do
    [ -e "$f" ] || continue
    lockcheck "$f" || { echo "FAIL fixture $(basename "$f") must be lock-schema-valid"; fail=1; continue; }
    if [ "$(locksem "$f" | jq length)" -gt 0 ]; then echo "PASS reject  $(basename "$f") [lock semantic]"; else echo "FAIL reject  $(basename "$f") [lock semantic accepted it]"; fail=1; fi
  done
done
# ---- v0.3 normative companions: migration, views, link resolution, SBOM projection ----
V3="$ROOT/schema/v0.3"; T3="$ROOT/tests/v0.3"
expect_eq() { if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1"; fail=1; fi; }
for f in "$ROOT"/schema/v0.2/examples/*.json; do
  jq -L "$V3" -f "$V3/migrate-from-0.2.jq" "$f" > "$TMP" 2>/dev/null
  if uvx --quiet check-jsonschema --schemafile "$V3/ckb.schema.json" "$TMP" >/dev/null 2>&1 && [ "$(jq -r -L "$V3" -f "$V3/semantic.jq" "$TMP" | jq length)" = 0 ]; then echo "PASS migrate $(basename "$f") v0.2 -> v0.3 is valid"; else echo "FAIL migrate $(basename "$f")"; fail=1; fi
done
jq -L "$V3" -f "$V3/migrate-from-0.2.jq" "$V3/examples/full.json" >/dev/null 2>&1 && { echo "FAIL migrate accepted a v0.3 input"; fail=1; } || echo "PASS migrate rejects a non-v0.2 input"
expect_eq "view summary is deterministic" "$(jq -L "$V3" -c 'include "views"; ckb_view_summary' "$V3/examples/full.json" | shasum | cut -c1-12)" "$(jq -L "$V3" -c 'include "views"; ckb_view_summary' "$V3/examples/full.json" | shasum | cut -c1-12)"
expect_eq "view impact: a generated path is governed by the constraint" "$(jq -L "$V3" -r 'include "views"; ckb_view_impact("src/generated/a/b.ts") | .invariants[0].kind' "$V3/examples/full.json")" "constraint"
expect_eq "view impact: an obligated path is reported" "$(jq -L "$V3" -r 'include "views"; ckb_view_impact("docs/openapi.yaml") | .invariants[0].id' "$V3/examples/full.json")" "invariant:obligation:route-change-updates-openapi"
expect_eq "view commands filters by kind" "$(jq -L "$V3" -r 'include "views"; ckb_view_commands("test") | map(.command) | join(",")' "$V3/examples/full.json")" "npm test"
expect_eq "view entity returns in/out relations" "$(jq -L "$V3" -r 'include "views"; ckb_view_entity("command:test:npm-test") | .in[0].kind' "$V3/examples/full.json")" "declares"
expect_eq "view entity on an unknown id is null" "$(jq -L "$V3" -c 'include "views"; ckb_view_entity("component:nope")' "$V3/examples/full.json")" "null"
res() { jq -s -L "$V3" -S -f "$V3/resolve.jq" "$@"; }
expect_eq "resolve: orders + payments => expected links" "$(res "$T3/resolve/orders.json" "$T3/resolve/payments.json")" "$(cat "$T3/resolve/expected.json")"
expect_eq "resolve: input order does not matter" "$(res "$T3/resolve/payments.json" "$T3/resolve/orders.json")" "$(cat "$T3/resolve/expected.json")"
expect_eq "resolve: two providers => ambiguous" "$(res "$T3/resolve/orders.json" "$T3/resolve/payments.json" "$T3/resolve/payments-b.json")" "$(cat "$T3/resolve/expected-ambiguous.json")"
expect_eq "resolve: no provider => unresolved, never a guessed link" "$(res "$T3/resolve/orders.json")" "$(cat "$T3/resolve/expected-unresolved.json")"
expect_eq "resolve: never links a repo to itself" "$(res "$T3/resolve/orders.json" "$T3/resolve/orders.json" | jq '[.links[]|select(.src|startswith("ckb://github.com/example/orders-service")) | select(.dst|startswith("ckb://github.com/example/orders-service"))] | length')" "0"
expect_eq "cyclonedx: is CycloneDX 1.6 with a bom-ref per component" "$(jq -f "$V3/cyclonedx.jq" "$V3/examples/full.json" | jq -r '.bomFormat + .specVersion + (all(.components[]; has("bom-ref") and has("purl")) | tostring)')" "CycloneDX1.6true"
expect_eq "cyclonedx: deterministic and free of timestamps" "$(jq -f "$V3/cyclonedx.jq" "$V3/examples/full.json" | grep -c -i 'timestamp\|serialNumber')" "0"
# ---- Agent Context Contract (ACC) v0.1 ----
AC="$ROOT/agent-context/v0.1"; TA="$ROOT/tests/agent-context/v0.1"
core() { jq -R -s -L "$AC" -f "$AC/rules.jq" "$1"; }
std()  { jq -R -s -L "$AC" --rawfile human "$AC/examples/human.md" --slurpfile ckb "$AC/examples/ckb.json" -f "$AC/rules.jq" "$1"; }
expect_eq "acc: examples/full.md is byte-identical to project.jq over examples/ckb.json + human.md" \
  "$(jq -r -L "$AC" --rawfile human "$AC/examples/human.md" -f "$AC/project.jq" "$AC/examples/ckb.json")" "$(cat "$AC/examples/full.md")"
expect_eq "acc: projection is deterministic and independent of the human file being absent" \
  "$(jq -r -L "$AC" --arg human "" -f "$AC/project.jq" "$AC/examples/ckb.json" | shasum)" "$(jq -r -L "$AC" --arg human "" -f "$AC/project.jq" "$AC/examples/ckb.json" | shasum)"
expect_eq "acc: examples/full.md conforms at Core"     "$(core "$AC/examples/full.md" | jq length)" "0"
expect_eq "acc: examples/full.md conforms at Standard" "$(std "$AC/examples/full.md" | jq length)" "0"
expect_eq "acc: the v0.3 artifact used by ACC is itself valid" "$(jq -r -L "$V3" -f "$V3/semantic.jq" "$AC/examples/ckb.json" | jq length)" "0"
jq '.entities.invariants += [range(0; 60) | {id: "invariant:constraint:rule-\(.)", name: "r\(.)", kind: "constraint", statement: "Rule number \(.) is a long constraint statement that keeps going with many words to fill the budget quickly.", confidence: "inferred", provenance: [{path: "package.json", line: 1}]}]
    | ([.entities[][], .relations[]]) as $c | .confidence_summary.inferred = ([$c[] | select(.confidence == "inferred")] | length)' "$AC/examples/ckb.json" > "$TMP"
jq -r -L "$AC" --arg human "" -f "$AC/project.jq" "$TMP" > "$TMP.md"
expect_eq "acc: projection of an oversized artifact stays within 400 words and conforms at Core" "$(core "$TMP.md" | jq length)" "0"
expect_eq "acc: budget keeps confirmed lines before inferred ones" "$(grep -c "Never edit src/generated" "$TMP.md")" "1"
rm -f "$TMP.md"
for f in "$TA"/invalid/*.md "$TA"/invalid-standard/*.md; do
  b="$(basename "$f")"; rule="A$(printf '%s' "$b" | sed -E 's/^a([0-9]+)-.*/\1/')"
  case "$f" in */invalid-standard/*) out="$(std "$f")"; [ "$(core "$f" | jq length)" = 0 ] || { echo "FAIL $b must pass Core"; fail=1; } ;; *) out="$(core "$f")" ;; esac
  n="$(jq length <<<"$out")"; other="$(jq -r --arg r "$rule " '.[] | select(startswith($r) | not)' <<<"$out")"
  if [ "$n" -gt 0 ] && [ -z "$other" ]; then echo "PASS reject  $b [acc $rule]"; else echo "FAIL reject  $b [expected only $rule]: $out"; fail=1; fi
done
[ $fail -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit $fail
