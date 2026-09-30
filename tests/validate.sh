#!/usr/bin/env bash
# Validate CKB artifacts: JSON Schema (structural) + semantic.jq (cross-reference rules).
# Usage: tests/validate.sh                 -> run the spec's own test suite
#        tests/validate.sh <artifact.json>  -> validate one artifact
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VER="${CKB_VERSION:-v0.1}"
SCHEMA="$ROOT/schema/$VER/ckb.schema.json"
command -v jq >/dev/null || { echo "jq required" >&2; exit 2; }
command -v uvx >/dev/null || { echo "uvx required (https://docs.astral.sh/uv/)" >&2; exit 2; }

structural() { uvx --quiet check-jsonschema --schemafile "$SCHEMA" "$1" >/dev/null 2>&1; }
structural_verbose() { uvx --quiet check-jsonschema --schemafile "$SCHEMA" "$1"; }
semantic() { jq -r -f "$ROOT/tests/semantic.jq" "$1"; }

check_one() {  # prints violations; returns 0 iff valid
  local f="$1" rc=0 v
  structural_verbose "$f" || rc=1
  v="$(semantic "$f" | jq -r '.[]')"
  [ -n "$v" ] && { echo "$v"; rc=1; }
  return $rc
}

if [ $# -ge 1 ]; then check_one "$1" && echo "PASS $1"; exit $?; fi

fail=0
uvx --quiet check-jsonschema --check-metaschema "$SCHEMA" >/dev/null || { echo "FAIL schema is not valid 2020-12"; fail=1; }
for f in "$ROOT"/schema/"$VER"/examples/*.json; do
  if check_one "$f" >/tmp/ckb.$$ 2>&1; then echo "PASS valid   $(basename "$f")"; else echo "FAIL valid   $(basename "$f")"; cat /tmp/ckb.$$; fail=1; fi
done
for f in "$ROOT"/tests/invalid/*.json; do
  if structural "$f"; then echo "FAIL reject  $(basename "$f") (schema accepted it)"; fail=1; else echo "PASS reject  $(basename "$f")"; fi
done
for f in "$ROOT"/tests/invalid-semantic/*.json; do
  structural "$f" || { echo "FAIL fixture $(basename "$f") must be schema-valid"; fail=1; continue; }
  if [ "$(semantic "$f" | jq length)" -gt 0 ]; then echo "PASS reject  $(basename "$f") [semantic]"; else echo "FAIL reject  $(basename "$f") [semantic accepted it]"; fail=1; fi
done
LOCK="$ROOT/schema/$VER/ckb-lock.schema.json"
lockcheck(){ uvx --quiet check-jsonschema --schemafile "$LOCK" "$1" >/dev/null 2>&1; }
uvx --quiet check-jsonschema --check-metaschema "$LOCK" >/dev/null || { echo "FAIL lock schema is not valid 2020-12"; fail=1; }
for f in "$ROOT"/schema/"$VER"/lock-examples/*.json; do
  if lockcheck "$f" && [ "$(jq -f "$ROOT/tests/lock-semantic.jq" "$f" | jq length)" = 0 ]; then echo "PASS valid   $(basename "$f") [lock]"; else echo "FAIL valid   $(basename "$f") [lock]"; fail=1; fi
done
for f in "$ROOT"/tests/invalid-lock/*.json; do
  if lockcheck "$f"; then echo "FAIL reject  $(basename "$f") [lock] (schema accepted it)"; fail=1; else echo "PASS reject  $(basename "$f") [lock]"; fi
done
for f in "$ROOT"/tests/invalid-lock-semantic/*.json; do
  lockcheck "$f" || { echo "FAIL fixture $(basename "$f") must be lock-schema-valid"; fail=1; continue; }
  if [ "$(jq -f "$ROOT/tests/lock-semantic.jq" "$f" | jq length)" -gt 0 ]; then echo "PASS reject  $(basename "$f") [lock semantic]"; else echo "FAIL reject  $(basename "$f") [lock semantic accepted it]"; fail=1; fi
done
rm -f /tmp/ckb.$$
[ $fail -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit $fail
