# Contributing to the CKB specification

The specification has a single editor, the author. That keeps CKB one standard instead of many incompatible forks.

- **Expressiveness gaps:** open an issue with a minimal real-world example of what CKB can't express today and why it matters for consumers. These issues drive new versions.
- **Pull requests** are welcome for typos, examples and tests. Every PR requires the [Contributor License Agreement](https://github.com/riddhimohansharma/codebase-kb-engine/blob/main/CLA.md), signed through the CLA check on the PR.
- **New fields, entity types or rules** are added only by the editor in a new version. Use `x-` fields for vendor data in the meantime.
- Before submitting, run `tests/validate.sh` (it needs `jq` and `uv`).

License: CC BY-ND 4.0 (see LICENSE). Names: see TRADEMARKS.md.
