# Astromapper (Go)

A Go implementation of the Astromapper Traveller star-map generator. World
generation is **data-driven**: the rules live in `rules/<name>.yml`, mirroring the
Ruby implementation so both share the same rule definitions (each is internally
reproducible from a seed; maps are **not** identical across languages because the
RNGs differ).

## Build & run

```bash
go build -o astromapper .
./astromapper --type sector --density scattered --seed MYSEED --name "My Sector"
```

Output (ASCII `.txt`, `.svg`, `.json`) is written to `output/`.

### Flags

| Flag | Default | Meaning |
|---|---|---|
| `--type` | `sector` | `sector` or `volume` |
| `--density` | `standard` | `--list-densities` for the full set |
| `--seed` | random | Crawford code `XXXXX-XXXXX`, or any string (folded to one) |
| `--name` | `Unnamed` | Sector name |
| `--ruleset` | `t5` | `t5`, `cepheus`, or a custom `rules/<name>.yml` |
| `--sophonts` | `human` | `human` (Settled/Colony) or `varied` (alien sophonts) |
| `--islands` | `true` | Outline clusters of nearby systems on the SVG |
| `--island-jump` | `2` | Systems within this many jumps form one island |
| `--island-min` | `2` | Minimum systems per island to draw a border |
| `--island-opacity` | `0.85` | Island border opacity, 0.0–1.0 |

> The Go build is configured entirely by these flags — there is no `_astromapper.yml`
> config file (that's the Ruby version). The only on-disk inputs are optional custom
> rulesets in `rules/<name>.yml`.

## Rulesets

The generation engine lives in `pkg/rules`:

- **`expr.go`** — a sandboxed expression evaluator (dice, arithmetic, comparisons,
  `and`/`or`/`not`, variables). It never reflects or executes code, so a
  `rules/*.yml` file is data, not a program.
- **`ruleset.go`** — loads a ruleset from the embedded built-ins (`pkg/rules/builtin`)
  or a project-local `rules/<name>.yml` override, resolves `extends:` inheritance
  (with `key!:` to replace a section wholesale), and exposes the trade-code table,
  UWP step formulas, and the starport/tech/base tables.

The **tabular** rules (trade codes, UWP formulas, starport/tech/base tables) are in
the YAML; the **algorithmic** parts (Ix/Ex/Cx + Resource Units, Habitable-Zone
climate, native status) are named code modules in `pkg/builder/rules.go`, selected
by the ruleset's `modules:` block (`none` disables a slot — e.g. Cepheus has no
extensions).

### Built-in rulesets

- **`t5`** — Traveller 5 WorldGen: full UWP, Ix/Ex/Cx extensions, HZ climate.
- **`cepheus`** — Cepheus Engine: classic UWP (no reroll), high-roll starport, `>=`
  bases, the classic 15-code trade table, no extensions. (`extends: t5`.)

### Custom rulesets

Drop a `rules/<name>.yml` in your working directory and pass `--ruleset <name>`. It
may `extends:` a built-in and override only what differs. Cepheus rule *values* are
transcribed from the SRD and should be spot-checked against your edition.

## Tests

```bash
go test ./...
```

Covers the expression evaluator, the ruleset loader (including Cepheus inheritance),
and a world-generation golden master (`pkg/builder/testdata/world_t5.txt`).
Regenerate the golden after an intentional change with `UPDATE_GOLDEN=1 go test ./pkg/builder/`.
