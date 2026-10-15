# Agent Context Contract (ACC) v0.1

**Status: draft.** A vendor-neutral format for the file a coding agent reads before it touches a repository (`CLAUDE.md`, `AGENTS.md` or any equivalent). The same bytes serve every agent; only the filename differs. ACC is a companion to CKB: a conforming file can be written by hand (Core) or projected from a CKB v0.3 artifact (Standard).

The key words MUST, MUST NOT, SHOULD and MAY are used as in RFC 2119.

## 1. Why a contract

The file is loaded on every agent turn, so every line costs context in every session. Generated files die of being obvious, and hand-written ones drift from the code. ACC fixes the shape, caps the size, admits only lines that change an agent's behaviour, and makes the generated part a pure function of verified facts, so it can be checked in CI.

## 2. The admission rule (normative)

A line MAY appear only if a competent agent, given the repository and no other context, would otherwise do the wrong thing. Admissible lines are of three kinds:

1. a constraint the agent cannot discover from the code (Non-negotiables);
2. a counter-intuitive fact (Traps);
3. an obligation edge with paths: changing X requires changing Y (Changing X obligates Y).

Plus the commands that prove work is done. Lines that restate the primary language, a framework's name, a test directory's name or the directory tree SHOULD NOT appear.

## 3. Structure (rules A1–A3)

```
# Agent context — <repo>
<one-line description>
## Non-negotiables
## Shape
## Commands
## Changing X obligates Y
## Traps
## Before you say you're done
```

- **A1.** The first line (HTML comments ignored) is `# Agent context — <repo>`. The six sections appear exactly once, in this order, and no other `##` sections exist.
- **A2.** At most **400 words**, excluding HTML comments and fenced code. There is no waiver: a repository that needs more splits the scope (a package gets its own file).
- **A3.** One fact per bullet: no nested bullets, at most 50 words per bullet. An empty section holds `- None recorded.`

## 4. Content rules (A4–A7, A10)

- **A4.** Non-negotiables are firm. They MUST NOT hedge (`maybe`, `might`, `probably`, `perhaps`, `try to`, `consider`, `ideally`).
- **A5.** No secret values: keys, tokens, passwords, private keys. Name a secret, never its value.
- **A6.** No instruction to fetch and run code (`curl … | sh`) or to skip a safety check (`--no-verify`, `--dangerously…`, "skip the review").
- **A7.** Deterministic text: no dates, LF line endings, no tabs, no trailing whitespace. A file that goes stale by the calendar is wrong on the day it is read.
- **A10.** No template residue: no `[P]`/`[H]` skeleton tags and no `TODO(human)` lines.

## 5. Projection from CKB (Standard level)

A producer generates the body with the normative projection [`agent-context/v0.1/project.jq`](agent-context/v0.1/project.jq) over a CKB **v0.3** artifact and an optional human file `.ckb/agent-context.human.md`:

| Section | Source |
|---|---|
| Non-negotiables | `invariants` of kind `constraint`; `repo_profile.generated_globs` and `vendored_globs` ("do not edit") |
| Shape | top-level `components` (`module_id`, `kind`, `layer`), at most 8 |
| Commands | `commands`, ordered build, test, lint, format, run, migrate, deploy, other |
| Changing X obligates Y | `invariants` of kind `obligation` (`applies_to` → `obligates`) |
| Traps | `invariants` of kind `trap` |
| Before you say you're done | the `test` and `lint` commands |

Within a section, lines are ordered by confidence (confirmed first) and then by id. Human lines (`- text` under a matching `## Section` heading in the human file) follow the projected lines of that section. If the result exceeds 400 words, lines are admitted section by section in priority order (Commands, Before you say you're done, Non-negotiables, Changing X obligates Y, Traps, Shape), each section in the order above, until the budget is reached; the rest are dropped. The output keeps the canonical section order. Two conforming projectors produce byte-identical output.

The generated region is fenced by markers:

```
<!-- ckb-ac:begin acc=0.1 ckb=0.3 commit=<40-hex source commit> -->
…
<!-- ckb-ac:end -->
```

The markers are HTML comments and are never backticked, so a `ckb:` citation check cannot mistake them for entity references.

- **A8.** When markers are present there is exactly one `begin` and one `end`, in that order, and the `begin` marker matches `acc=0.1 ckb=0.<n> commit=<40 hex>`.
- **A9.** The region equals `project.jq` applied to the artifact of that commit and the human file. A human edits `.ckb/agent-context.human.md`, never the region. A projector MUST NOT overwrite a region that fails A9 (it was edited by hand); it writes `<file>.acc-proposed` next to it instead.

## 6. Conformance

| Level | Rules | Who |
|---|---|---|
| **Core** | A1–A7, A10 | Any hand-written file. Adopt with a text editor. |
| **Standard** | Core + A8, A9 | Files projected from a CKB v0.3 artifact. |
| **Enterprise** | Standard, enforced as a required CI check, with an owner (for example CODEOWNERS) on the file | Organisations that let agents act on the file. |

The reference checker is [`agent-context/v0.1/rules.jq`](agent-context/v0.1/rules.jq):

```bash
jq -R -s -L agent-context/v0.1 -f agent-context/v0.1/rules.jq CLAUDE.md                     # Core
jq -R -s -L agent-context/v0.1 --slurpfile ckb .ckb/ckb.json \
   --rawfile human .ckb/agent-context.human.md -f agent-context/v0.1/rules.jq CLAUDE.md     # Standard
```

It prints an array of violations, each prefixed with its rule; an empty array means conformant. Every rule has a fixture in `tests/agent-context/v0.1/` that is rejected by exactly that rule.

## 7. Security notes

Every agent in an organisation obeys this file, and anyone who can commit can edit it. Review it like code. A projector writes only what the artifact proves, and a create-only writer never overwrites an existing file. The file is instructions for agents, not a security boundary.

## 8. Versioning

`acc=0.1` is independent of `ckb_version`. ACC v0.1 projects from CKB v0.3. Rules are only added in minor versions; the six section names and the 400-word budget change only in a major version.
