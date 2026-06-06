# Astromapper (Rust)

A Rust implementation of the Astromapper Traveller star-map generator. World
generation is **data-driven**: the rules live in `rules/<name>.yml`, mirroring the
Ruby and Go implementations so all three share the same rule definitions. Each is
internally reproducible from a seed; maps are **not** identical across languages
because the RNGs differ (Rust uses ChaCha8).

## Build & run

```bash
cargo build --release

# Scaffold a project (creates the dir, _astromapper.yml, and output/):
cargo run -- new "My Sector"
cd My-Sector
cargo run --manifest-path ../Cargo.toml --   # reads _astromapper.yml here

# …or generate in one shot with flags:
cargo run -- --density scattered --seed MYSEED --name "My Sector" --ruleset t5
```

Output (ASCII `.txt`, `.svg`, `.json`, and a T5 Second Survey `.tab`) is written to
`output/`. The active ruleset is named in the `.txt` and `.tab` legends.

### Flags (all optional: flag > config file > default)

| Flag | Default | Meaning |
|---|---|---|
| `--type` | `sector` | `sector` or `volume` |
| `--density` | `scattered` | `--list-densities` for the full set |
| `--seed` | random | Crawford code `XXXXX-XXXXX`, or any string |
| `--name` | `Unnamed` | Sector name |
| `--genre` | `normal` | `firm` (M-dwarf-heavy), `normal`, `opera` (Sun-like) |
| `--ruleset` | `t5` | `t5`, `cepheus`, or a custom `rules/<name>.yml` |
| `--sophonts` | `human` | `human` (Settled/Colony) or `varied` (alien sophonts) |
| `--prune` | `true` | Drop systems with no neighbour within jump-4 |
| `--islands` | `true` | Outline clusters of nearby systems on the SVG |
| `--island-jump` / `--island-min` / `--island-opacity` | `2` / `2` / `0.85` | Island tuning |
| `--config` | `_astromapper.yml` | Config file path |

## Rulesets

The engine lives in `src/rules`:

- **`expr.rs`** — a sandboxed AST evaluator (dice, arithmetic, comparisons,
  `and`/`or`/`not`, variables). No code execution; a `rules/*.yml` is data.
- **`ruleset.rs`** — loads a ruleset from the embedded built-ins
  (`src/rules/builtin`, via `include_str!`) or a project-local `rules/<name>.yml`
  override, resolves `extends:` inheritance (with `key!:` to replace a section
  wholesale), and exposes the trade-code table, UWP step formulas, and the
  starport/tech/base tables.

Tabular rules (trade codes, UWP formulas, starport/tech/base tables) are in the YAML;
the algorithmic parts (Ix/Ex/Cx + RU, Habitable-Zone climate, native status) are code
in `builders/world_builder.rs`, selected by the ruleset's `modules:` block (`none`
disables a slot — e.g. Cepheus has no extensions).

Built-in: **`t5`** (Traveller 5 WorldGen) and **`cepheus`** (Cepheus Engine, extends
t5, no extensions). Drop a `rules/<name>.yml` in your project for a custom ruleset.

## Config file

Drop an `_astromapper.yml` (see [`_astromapper.example.yml`](_astromapper.example.yml))
in the working directory and run `astromapper` with no flags. Precedence is
**explicit flag > config file > built-in defaults**.

## Tests

```bash
cargo test
```

Covers the expression evaluator, the ruleset loader (incl. Cepheus inheritance), the
config loader, prune, and a genre stellar-model integration test.
