# Astromapper (Go)

A Go implementation of the Astromapper Traveller star-map generator. World
generation is **data-driven**: the rules live in `rules/<name>.yml`, mirroring the
Ruby implementation so both share the same rule definitions (each is internally
reproducible from a seed; maps are **not** identical across languages because the
RNGs differ).

## Build & run

```bash
go build -o astromapper .

# Scaffold a project (creates the dir, _astromapper.yml, and output/):
./astromapper new "My Sector"
cd My-Sector
../astromapper          # reads _astromapper.yml in this directory

# …or generate in one shot with flags:
./astromapper --type sector --density scattered --seed MYSEED --name "My Sector"
```

`astromapper new <name>` mirrors the Ruby workflow: spaces in the name become
dashes in the directory, and the sector name is written into the scaffolded
`_astromapper.yml`. Output (ASCII `.txt`, `.svg`, `.json`, and a T5 Second Survey
`.tab`) is written to `output/`. The active ruleset is named in the `.txt` and `.tab`
legends.

### Flags

| Flag | Default | Meaning |
|---|---|---|
| `--type` | `sector` | `sector` or `volume` |
| `--density` | `scattered` | `--list-densities` for the full set |
| `--seed` | random | Crawford code `XXXXX-XXXXX`, or any string (folded to one) |
| `--name` | `Unnamed` | Sector name |
| `--genre` | `normal` | Stellar realism: `firm` (M-dwarf-heavy), `normal`, `opera` (Sun-like) |
| `--ruleset` | `t5` | `t5`, `cepheus`, or a custom `rules/<name>.yml` |
| `--sophonts` | `human` | `human` (Settled/Colony) or `varied` (alien sophonts) |
| `--prune` | `true` | Drop systems with no neighbour within jump-4 (lone, unreachable stars) |
| `--islands` | `true` | Outline clusters of nearby systems on the SVG |
| `--island-jump` | `2` | Systems within this many jumps form one island |
| `--island-min` | `2` | Minimum systems per island to draw a border |
| `--island-opacity` | `0.85` | Island border opacity, 0.0–1.0 |

## Config file

Instead of repeating flags, drop an `_astromapper.yml` in your working directory and
run `astromapper` with no flags. Precedence is **explicit flag > config file >
built-in defaults**, so a flag always wins over the file. Point at a different file
with `--config <path>`. See [`_astromapper.example.yml`](_astromapper.example.yml) for
the full key list (`name`, `density`, `seed`, `genre`, `ruleset`, `sophonts`,
`prune_isolated`, `islands`, `island_jump`, `island_min`, `island_opacity`).

```yaml
# _astromapper.yml
name: "My Sector"
density: scattered
ruleset: cepheus
island_jump: 3
```

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
