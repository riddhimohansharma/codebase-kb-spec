#!/usr/bin/env bash
# Validate CKB artifacts: JSON Schema (structural) + semantic rules (cross-reference rules, jq).
# Usage: tests/validate.sh                 -> run the spec's own test suite for every published version (v0.1, v0.2)
#        tests/validate.sh <artifact.json>  -> validate one artifact against the schema named by its ckb_version
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v jq >/dev/null || { echo "jq required" >&2; exit 2; }
command -v uvx >/dev/null || { echo "uvx required (https://docs.astral.sh/uv/)" >&2; exit 2; }
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT

use_version() {  # sets SCHEMA, LOCK, FIXTURES and the semantic command for one spec version (v0.1 | v0.2)
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
for VER in v0.1 v0.2; do
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
[ $fail -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit $fail
